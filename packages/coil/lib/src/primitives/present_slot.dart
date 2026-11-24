// The render objects keep fields behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Which side of a [CoilPresentSlot]'s content its gap sits on.
enum CoilPresentSlotGap {
  /// The gap comes first along the axis: an error under a control, a
  /// trailing icon after a label.
  ///
  /// The content stays against the start edge and the room opens away from
  /// the neighbor.
  before,

  /// The gap comes last: a leading icon before a label.
  ///
  /// The content stays against the end edge, so it travels with the
  /// neighbor as the room opens.
  after,
}

/// An optional part of a component that opens and closes its own room.
///
/// The slot's layout size along [axis] is the content's extent *plus the
/// [gap] that separates it from its neighbor*, scaled by a 0 to 1
/// presence. That is why the gap lives here: a [Column]'s `spacing` is
/// there whether or not the part is, and can't animate, so a part that
/// comes and goes owns the space beside it. An error slot under a field
/// contributes `(messageGap + errorHeight) × presence`.
///
/// The content blur-fades in on the same presence ([CoilBlurFade]). It
/// is laid out at its natural size and never stretched: while the room is
/// smaller than the content, the content stays against the edge next to the
/// neighbor and is clipped by the room.
///
/// A null [child] means the part is absent. When it goes null the slot
/// keeps the last non-null child mounted, unreachable by focus, taps and
/// screen readers, until the room has closed.
///
/// Motion: the presence is `standard` entering and `standardExit` leaving;
/// the content fades on `fade` and `fadeExit`. Under reduced motion the
/// room jumps and the content only fades.
class CoilPresentSlot extends StatefulWidget {
  /// Creates a slot.
  const CoilPresentSlot({
    required this.child,
    super.key,
    this.axis = Axis.vertical,
    this.gap = 0,
    this.gapSide = CoilPresentSlotGap.before,
    this.appear = false,
    this.onEnd,
    this.presenceMotion,
    this.presenceExitMotion,
    this.fadeMotion,
    this.fadeExitMotion,
    this.motion,
    this.debugLabel,
  }) : assert(gap >= 0, 'A gap is a space, not an overlap.');

  /// The content, or null while the part is absent.
  final Widget? child;

  /// The direction the room opens in: vertical for a message under a
  /// control, horizontal for an icon beside a label.
  final Axis axis;

  /// The space between the content and the neighbor it is attached to.
  final double gap;

  /// Whether the [gap] comes before or after the content along [axis].
  final CoilPresentSlotGap gapSide;

  /// Whether a [child] that is there on the first build opens from
  /// closed instead of showing at once.
  final bool appear;

  /// Called when the room and the fade have settled open or closed after
  /// [child] came or went.
  final VoidCallback? onEnd;

  /// The room's motion entering, and leaving too unless
  /// [presenceExitMotion] is set.
  ///
  /// Defaults to `standard`.
  final Motion? presenceMotion;

  /// The room's motion leaving.
  ///
  /// Defaults to [presenceMotion], else `standardExit`.
  final Motion? presenceExitMotion;

  /// The content's fade entering, and leaving too unless [fadeExitMotion]
  /// is set.
  ///
  /// Defaults to `fade`.
  final Motion? fadeMotion;

  /// The content's fade leaving.
  ///
  /// Defaults to [fadeMotion], else `fadeExit`.
  final Motion? fadeExitMotion;

  /// Overrides the theme's motion tokens for the defaults.
  final CoilMotion? motion;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  State<CoilPresentSlot> createState() => _CoilPresentSlotState();
}

class _CoilPresentSlotState extends State<CoilPresentSlot>
    with FixedTickerProviderStateMixin {
  late final SingleMotionController _room;
  late final SingleMotionController _fade;

  /// The content that stays mounted while the room closes.
  Widget? _shown;

  bool get _present => widget.child != null;

  @override
  void initState() {
    super.initState();
    _shown = widget.child;
    final start = _present && !widget.appear ? 1.0 : 0.0;
    SingleMotionController controller(String name) => SingleMotionController(
      motion: const Motion.instant(),
      vsync: this,
      initialValue: start,
      // Presence only springs between 0 and 1; nothing sets it.
      velocityTracking: const VelocityTracking.off(),
      debugLabel: '${widget.debugLabel ?? 'CoilPresentSlot'} $name',
    )..addStatusListener(_onStatus);
    _room = controller('room');
    _fade = controller('fade');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A first build that appears starts its spring here, where the tokens
    // can be read.
    if (_present && widget.appear && !_started) _retarget();
  }

  bool _started = false;

  @override
  void didUpdateWidget(CoilPresentSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) _shown = widget.child;
    if ((oldWidget.child != null) != _present) _retarget();
  }

  /// Heads for the current presence with the motions of its direction.
  void _retarget() {
    _started = true;
    _changing = true;
    final target = _present ? 1.0 : 0.0;
    _room
      ..motion = _roomMotion(entering: _present)
      ..animateTo(target);
    _fade
      ..motion = _fadeMotion(entering: _present)
      ..animateTo(target);
  }

  Motion _roomMotion({required bool entering}) {
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    return entering
        ? widget.presenceMotion ?? tokens.standard
        : widget.presenceExitMotion ??
              widget.presenceMotion ??
              tokens.standardExit;
  }

  Motion _fadeMotion({required bool entering}) {
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    return entering
        ? widget.fadeMotion ?? tokens.fade
        : widget.fadeExitMotion ?? widget.fadeMotion ?? tokens.fadeExit;
  }

  /// Whether [CoilPresentSlot.child] came or went and the room hasn't
  /// settled since.
  bool _changing = false;

  void _onStatus(AnimationStatus status) {
    if (!mounted || _room.isAnimating || _fade.isAnimating) return;
    final settledOpen = _present && _room.value >= 1 && _fade.value >= 1;
    final settledClosed = !_present && _room.value <= 0 && _fade.value <= 0;
    if (settledClosed && _shown != null) {
      // Gone once both the room and the fade have settled closed.
      setState(() => _shown = null);
    }
    if (_changing && (settledOpen || settledClosed)) {
      _changing = false;
      // Not now: a jump settles inside the parent's build.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEnd?.call();
      });
    }
  }

  @override
  void dispose() {
    _room.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final present = _present;
    final animatesRoom =
        _roomMotion(entering: true) != const Motion.instant() ||
        _roomMotion(entering: false) != const Motion.instant();
    return ListenableBuilder(
      listenable: _room,
      builder: (context, content) => _PresentSlotLayout(
        presence: math.max(0, _room.value),
        axis: widget.axis,
        gap: widget.gap,
        gapSide: widget.gapSide,
        // Only a room that is partly open needs the clip: open, the
        // content may paint past its box, such as a focus ring.
        clip: animatesRoom && _room.value < 1,
        textDirection: Directionality.maybeOf(context),
        child: content,
      ),
      child: IgnorePointer(
        ignoring: !present,
        child: ExcludeFocus(
          excluding: !present,
          child: ExcludeSemantics(
            excluding: !present,
            child: CoilBlurFade(
              presence: _fade,
              scale: 1,
              blur: CoilBlurFade.defaultBlur / 2,
              child: shown,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresentSlotLayout extends SingleChildRenderObjectWidget {
  const _PresentSlotLayout({
    required this.presence,
    required this.axis,
    required this.gap,
    required this.gapSide,
    required this.clip,
    required this.textDirection,
    super.child,
  });

  final double presence;
  final Axis axis;
  final double gap;
  final CoilPresentSlotGap gapSide;
  final bool clip;
  final TextDirection? textDirection;

  @override
  _RenderPresentSlot createRenderObject(BuildContext context) =>
      _RenderPresentSlot(
        presence: presence,
        axis: axis,
        gap: gap,
        gapSide: gapSide,
        clip: clip,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPresentSlot renderObject,
  ) {
    renderObject
      ..presence = presence
      ..axis = axis
      ..gap = gap
      ..gapSide = gapSide
      ..clip = clip
      ..textDirection = textDirection;
  }
}

class _RenderPresentSlot extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderPresentSlot({
    required double presence,
    required Axis axis,
    required double gap,
    required CoilPresentSlotGap gapSide,
    required bool clip,
    required TextDirection? textDirection,
  }) : _presence = presence,
       _axis = axis,
       _gap = gap,
       _gapSide = gapSide,
       _clip = clip,
       _textDirection = textDirection;

  double _presence;
  // ignore: avoid_setters_without_getters
  set presence(double value) {
    if (value == _presence) return;
    _presence = value;
    markNeedsLayout();
  }

  Axis _axis;
  // ignore: avoid_setters_without_getters
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  double _gap;
  // ignore: avoid_setters_without_getters
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  CoilPresentSlotGap _gapSide;
  // ignore: avoid_setters_without_getters
  set gapSide(CoilPresentSlotGap value) {
    if (value == _gapSide) return;
    _gapSide = value;
    markNeedsLayout();
  }

  bool _clip;
  // ignore: avoid_setters_without_getters
  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  TextDirection? _textDirection;
  // ignore: avoid_setters_without_getters
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  bool get _rtl => _textDirection == TextDirection.rtl;

  final _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  /// The content is laid out at its natural main extent, and at the room's
  /// cross extent.
  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      _axis == Axis.vertical
      ? BoxConstraints(
          minWidth: constraints.minWidth,
          maxWidth: constraints.maxWidth,
        )
      : BoxConstraints(maxHeight: constraints.maxHeight);

  double _main(Size size) => _axis == Axis.vertical ? size.height : size.width;

  double _cross(Size size) => _axis == Axis.vertical ? size.width : size.height;

  Size _sizeFor(BoxConstraints constraints, Size childSize) {
    final extent = (_main(childSize) + _gap) * _presence;
    // A closed slot takes no cross extent either, so an absent part never
    // changes its row's height.
    final cross = _presence > 0 ? _cross(childSize) : 0.0;
    return constraints.constrain(
      _axis == Axis.vertical ? Size(cross, extent) : Size(extent, cross),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size.zero);
    return _sizeFor(
      constraints,
      child.getDryLayout(_childConstraints(constraints)),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(
    Axis.horizontal,
    (child) => child.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(
    Axis.horizontal,
    (child) => child.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic(
    Axis.vertical,
    (child) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic(
    Axis.vertical,
    (child) => child.getMaxIntrinsicHeight(width),
  );

  double _intrinsic(Axis along, double Function(RenderBox child) measure) {
    final child = this.child;
    if (child == null) return 0;
    final natural = measure(child);
    return along == _axis ? (natural + _gap) * _presence : natural;
  }

  /// Where the content starts along the axis, measured from the start
  /// edge of a room of [extent].
  double _startOffset(double extent, double childMain) =>
      _gapSide == CoilPresentSlotGap.before ? _gap : extent - _gap - childMain;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    final childSize = child.size;
    size = _sizeFor(constraints, childSize);
    final start = _startOffset(_main(size), _main(childSize));
    final main = _axis == Axis.horizontal && _rtl
        ? _main(size) - start - _main(childSize)
        : start;
    final cross = _axis == Axis.vertical && _rtl
        ? size.width - childSize.width
        : 0.0;
    (child.parentData! as BoxParentData).offset = _axis == Axis.vertical
        ? Offset(cross, main)
        : Offset(main, cross);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    final distance = child?.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    return distance + (child!.parentData! as BoxParentData).offset.dy;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    void paintChild(PaintingContext context, Offset offset) =>
        context.paintChild(
          child,
          offset + (child.parentData! as BoxParentData).offset,
        );
    if (_clip && size.isEmpty) {
      _clipLayer.layer = null;
      return;
    }
    if (_clip) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        paintChild,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      paintChild(context, offset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }
}
