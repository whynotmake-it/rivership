// The render objects keep fields behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A box that springs to its child's new size when the child's own content
/// changes, and follows its constraints at once.
///
/// This is coil's rule for a component that resizes itself: a label that
/// gets longer, a message that wraps to another line, a count that gains a
/// digit. The box springs from the size it shows to the child's new natural
/// size, and keeps its velocity if the child changes again on the way. But
/// when the *constraints* change (the window resizes, a parent's width
/// moves, the text scale changes), the box snaps to the new natural size and
/// drops any spring in flight: a window being dragged must never lag behind
/// the cursor.
///
/// While the box is smaller than its child, the child sits by [alignment]
/// and is clipped. Under reduced motion (a [Motion.instant] [motion]) the
/// size just changes.
///
/// For content that also changes what it shows, use [CoilSizeSwitcher],
/// which cross-fades the old and the new content.
class CoilSizeSpring extends StatefulWidget {
  /// Creates a size spring.
  const CoilSizeSpring({
    required this.motion,
    required this.child,
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.clipBehavior = Clip.hardEdge,
    this.resetKey,
    this.debugLabel,
  });

  /// The spring the size follows.
  final Motion motion;

  /// The content.
  final Widget child;

  /// Where the child sits while the box is a different size.
  final AlignmentGeometry alignment;

  /// How the child is clipped while it overflows the box. Only a box that
  /// is smaller than its child clips.
  final Clip clipBehavior;

  /// Anything else that resizes the content without being a content
  /// change: when this value changes (compared with `==`), the size snaps
  /// instead of springing. The text scale is always one.
  final Object? resetKey;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  State<CoilSizeSpring> createState() => _CoilSizeSpringState();
}

class _CoilSizeSpringState extends State<CoilSizeSpring>
    with SingleTickerProviderStateMixin {
  late final MotionController<Size> _controller;

  @override
  void initState() {
    super.initState();
    _controller = MotionController<Size>(
      motion: widget.motion,
      vsync: this,
      converter: MotionConverter.size,
      initialValue: Size.zero,
      // The size only ever animates toward the child's; it never follows
      // values set from outside.
      velocityTracking: const VelocityTracking.off(),
      debugLabel: widget.debugLabel ?? 'CoilSizeSpring',
    );
  }

  @override
  void didUpdateWidget(CoilSizeSpring oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.motion != oldWidget.motion) _controller.motion = widget.motion;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SizeSpringLayout(
    controller: _controller,
    alignment: widget.alignment,
    clipBehavior: widget.clipBehavior,
    textDirection: Directionality.maybeOf(context),
    animates: widget.motion != const Motion.instant(),
    resetKey: (MediaQuery.maybeTextScalerOf(context), widget.resetKey),
    child: widget.child,
  );
}

class _SizeSpringLayout extends SingleChildRenderObjectWidget {
  const _SizeSpringLayout({
    required this.controller,
    required this.alignment,
    required this.clipBehavior,
    required this.textDirection,
    required this.animates,
    required this.resetKey,
    required super.child,
  });

  final MotionController<Size> controller;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;
  final TextDirection? textDirection;
  final bool animates;
  final Object? resetKey;

  @override
  _RenderSizeSpring createRenderObject(BuildContext context) =>
      _RenderSizeSpring(
        controller: controller,
        alignment: alignment,
        clipBehavior: clipBehavior,
        textDirection: textDirection,
        animates: animates,
        resetKey: resetKey,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeSpring renderObject,
  ) {
    renderObject
      ..controller = controller
      ..alignment = alignment
      ..clipBehavior = clipBehavior
      ..textDirection = textDirection
      ..animates = animates
      ..resetKey = resetKey;
  }
}

/// Springs its size toward its child's, unless the constraints (or the
/// reset key) changed since the last layout, in which case it snaps.
class _RenderSizeSpring extends RenderAligningShiftedBox {
  _RenderSizeSpring({
    required MotionController<Size> controller,
    required bool animates,
    required Object? resetKey,
    super.alignment,
    super.textDirection,
    Clip clipBehavior = Clip.hardEdge,
  }) : _controller = controller,
       _animates = animates,
       _resetKey = resetKey,
       _clipBehavior = clipBehavior;

  MotionController<Size> _controller;
  // ignore: avoid_setters_without_getters
  set controller(MotionController<Size> value) {
    if (value == _controller) return;
    if (attached) _detachController();
    _controller = value;
    _snap();
    if (attached) _attachController();
    markNeedsLayout();
  }

  bool _animates;
  // ignore: avoid_setters_without_getters
  set animates(bool value) {
    if (value == _animates) return;
    _animates = value;
    markNeedsLayout();
  }

  Object? _resetKey;
  // ignore: avoid_setters_without_getters
  set resetKey(Object? value) {
    if (value == _resetKey) return;
    _resetKey = value;
    // Not a content change: the next layout snaps.
    _snapNext = true;
    markNeedsLayout();
  }

  Clip _clipBehavior;
  // ignore: avoid_setters_without_getters
  set clipBehavior(Clip value) {
    if (value == _clipBehavior) return;
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// The child's size the controller is heading for, or null before the
  /// first layout.
  Size? _target;

  /// The constraints of the last layout. A different set means the
  /// parent, not the content, changed the size.
  BoxConstraints? _lastConstraints;

  bool _snapNext = false;

  /// Whether the size follows [_controller].
  bool _following = false;

  void _snap() {
    _controller.stop(canceled: true);
    _target = null;
    _following = false;
  }

  void _onControllerChanged() => markNeedsLayout();

  /// Whether [performLayout] is running: starting a spring there reports
  /// its status at once, and the layout in progress already reads it.
  bool _laying = false;

  void _onStatus(AnimationStatus _) {
    if (!_laying) markNeedsLayout();
  }

  void _attachController() => _controller
    ..addListener(_onControllerChanged)
    ..addStatusListener(_onStatus);

  void _detachController() => _controller
    ..removeListener(_onControllerChanged)
    ..removeStatusListener(_onStatus);

  bool _hasVisualOverflow = false;
  final _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _attachController();
  }

  @override
  void detach() {
    _detachController();
    super.detach();
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    _laying = true;
    try {
      _layoutChild();
    } finally {
      _laying = false;
    }
  }

  void _layoutChild() {
    _hasVisualOverflow = false;
    final constraints = this.constraints;
    final child = this.child;
    final changed = _lastConstraints != constraints || _snapNext;
    _lastConstraints = constraints;
    _snapNext = false;
    if (child == null || constraints.isTight) {
      // Nothing to animate toward.
      if (_following) _snap();
      _target = null;
      size = constraints.smallest;
      if (child != null) {
        child.layout(constraints);
        (child.parentData! as BoxParentData).offset = Offset.zero;
      }
      return;
    }

    child.layout(constraints, parentUsesSize: true);
    final childSize = child.size;
    final target = _target;
    if (target == null || changed || !_animates) {
      // The parent changed the room, or the first size: take the child's
      // natural size at once and drop any spring in flight. A stop changes
      // no value, so it doesn't notify mid-layout.
      if (_following || _controller.isAnimating) {
        _controller.stop(canceled: true);
      }
      _following = false;
      _target = childSize;
      size = constraints.constrain(childSize);
    } else {
      if (childSize != target) {
        _target = childSize;
        // A controller that hasn't animated yet starts from the size shown,
        // the previous target.
        _controller.animateTo(childSize, from: _following ? null : target);
        _following = true;
      }
      final shown = _following && _controller.isAnimating
          ? _controller.value
          : _target!;
      size = constraints.constrain(
        Size(math.max(0, shown.width), math.max(0, shown.height)),
      );
    }
    alignChild();
    if (size.width < childSize.width || size.height < childSize.height) {
      _hasVisualOverflow = true;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null || constraints.isTight) return constraints.smallest;
    final childSize = child.getDryLayout(constraints);
    if (!_following ||
        _lastConstraints != constraints ||
        (!_controller.isAnimating && childSize == _target)) {
      return constraints.constrain(childSize);
    }
    return constraints.constrain(_controller.value);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final result = child.getDryBaseline(constraints, baseline);
    if (result == null) return null;
    if (constraints.isTight) return result;
    final childSize = child.getDryLayout(constraints);
    final offset = resolvedAlignment.alongOffset(
      (getDryLayout(constraints) - childSize) as Offset,
    );
    return result + offset.dy;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && _hasVisualOverflow && _clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
        clipBehavior: _clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      super.paint(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _clipBehavior != Clip.none && _hasVisualOverflow
      ? Offset.zero & size
      : null;
}

/// [CoilSizeSpring] around a cross-fade: [child] is swapped when its key
/// (or type) changes, the old content blur-fades out where it is while the
/// new one fades in, and the box springs from the old content's size to the
/// new one's.
///
/// The size follows the *new* content at once, so a shorter label starts to
/// shrink as it arrives instead of waiting for the old one to leave. The
/// leaving content keeps the constraints it had, is unreachable for focus,
/// taps and screen readers while it leaves, and is clipped by the box.
///
/// A [child] that changes without a new key (a `Text` whose string changed)
/// is the same content: the box springs to its size, with no cross-fade.
/// Key it by what it shows to cross-fade.
class CoilSizeSwitcher extends StatelessWidget {
  /// Creates a size switcher.
  const CoilSizeSwitcher({
    required this.child,
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.clipBehavior = Clip.hardEdge,
    this.sizeMotion,
    this.fadeMotion,
    this.fadeExitMotion,
    this.motion,
    this.blur = CoilBlurFade.defaultBlur / 2,
    this.contentKey,
    this.debugLabel,
  });

  /// What [child] shows, when it can't carry a key of its own: a `Text`
  /// (see [contentKeyOf]) or a widget whose key you don't control, such as
  /// one a caller passed in.
  static Object? contentKeyOf(Widget? child) => switch (child) {
    Text(key: null, :final data?) => data,
    Text(key: null, :final textSpan?) => textSpan.toPlainText(),
    _ => null,
  };

  /// The content. Give it a key that names what it shows.
  final Widget? child;

  /// Names what [child] shows: content with another name cross-fades. Null
  /// uses [contentKeyOf] of the child, so a `Text` cross-fades when its
  /// string changes and any other widget by its own key.
  final Object? contentKey;

  /// Where the content sits while the box is another size.
  final AlignmentGeometry alignment;

  /// How the content is clipped while it overflows the box.
  final Clip clipBehavior;

  /// The size's motion. Defaults to `standard`; the same motion shrinking
  /// and growing, since the box keeps its velocity either way.
  final Motion? sizeMotion;

  /// The entering content's motion. Defaults to `fade`.
  final Motion? fadeMotion;

  /// The leaving content's motion. Defaults to `fadeExit`.
  final Motion? fadeExitMotion;

  /// Overrides the theme's motion tokens for the defaults.
  final CoilMotion? motion;

  /// The blur at presence 0.
  final double blur;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context, override: motion);
    return CoilSizeSpring(
      motion: sizeMotion ?? tokens.standard,
      alignment: alignment,
      clipBehavior: clipBehavior,
      debugLabel: debugLabel,
      child: MotionSwitcher(
        motion: fadeMotion ?? tokens.fade,
        exitMotion: fadeExitMotion ?? tokens.fadeExit,
        transitionBuilder: CoilBlurFade.transition(blur: blur, scale: 1),
        debugLabel: debugLabel ?? 'CoilSizeSwitcher',
        layoutBuilder: (current, previous) => _SwapLayout(
          alignment: alignment,
          clipBehavior: clipBehavior,
          textDirection: Directionality.maybeOf(context),
          children: [
            for (final leaving in previous)
              ExcludeFocus(
                child: ExcludeSemantics(child: IgnorePointer(child: leaving)),
              ),
            current ?? const SizedBox.shrink(),
          ],
        ),
        child: switch ((child, contentKey ?? contentKeyOf(child))) {
          (final child?, final name?) => KeyedSubtree(
            key: ValueKey<Object>(name),
            child: child,
          ),
          (final child, _) => child,
        },
      ),
    );
  }
}

/// Lays out the last child (the current content) and takes its size. The
/// children before it (leaving content) get the same constraints, so a
/// wrapping one doesn't reflow, and sit by [alignment], overflowing.
class _SwapLayout extends MultiChildRenderObjectWidget {
  const _SwapLayout({
    required this.alignment,
    required this.clipBehavior,
    required this.textDirection,
    required super.children,
  });

  final AlignmentGeometry alignment;
  final Clip clipBehavior;
  final TextDirection? textDirection;

  @override
  _RenderSwapLayout createRenderObject(BuildContext context) =>
      _RenderSwapLayout(
        alignment: alignment,
        clipBehavior: clipBehavior,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSwapLayout renderObject,
  ) {
    renderObject
      ..alignment = alignment
      ..clipBehavior = clipBehavior
      ..textDirection = textDirection;
  }
}

class _SwapParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSwapLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SwapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SwapParentData> {
  _RenderSwapLayout({
    required AlignmentGeometry alignment,
    required Clip clipBehavior,
    TextDirection? textDirection,
  }) : _alignment = alignment,
       _clipBehavior = clipBehavior,
       _textDirection = textDirection;

  AlignmentGeometry _alignment;
  // ignore: avoid_setters_without_getters
  set alignment(AlignmentGeometry value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  TextDirection? _textDirection;
  // ignore: avoid_setters_without_getters
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  Clip _clipBehavior;
  // ignore: avoid_setters_without_getters
  set clipBehavior(Clip value) {
    if (value == _clipBehavior) return;
    _clipBehavior = value;
    markNeedsPaint();
  }

  bool _hasVisualOverflow = false;
  final _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SwapParentData) {
      child.parentData = _SwapParentData();
    }
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  RenderBox get _sizing => lastChild!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _sizing.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizing.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sizing.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sizing.getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _sizing.getDistanceToActualBaseline(baseline);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => _sizing.getDryBaseline(constraints, baseline);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizing.getDryLayout(constraints);

  @override
  void performLayout() {
    final constraints = this.constraints;
    final sizing = _sizing..layout(constraints, parentUsesSize: true);
    size = sizing.size;
    final alignment = _alignment.resolve(_textDirection);
    _hasVisualOverflow = false;
    var child = firstChild;
    while (child != null && child != sizing) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      final parentData = child.parentData! as _SwapParentData
        ..offset = alignment.inscribe(child.size, Offset.zero & size).topLeft;
      if (child.size.width > size.width || child.size.height > size.height) {
        _hasVisualOverflow = true;
      }
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_hasVisualOverflow && _clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        defaultPaint,
        clipBehavior: _clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _hasVisualOverflow && _clipBehavior != Clip.none
      ? Offset.zero & size
      : null;
}
