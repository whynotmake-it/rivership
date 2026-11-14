import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Builds a tooltip's bubble around [content], given the 0→1 presence to
/// animate it with.
typedef CoilTooltipBubbleBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> presence,
      Widget content,
    );

/// The side of its trigger a tooltip bubble prefers. It flips to the
/// opposite side when there's no room.
enum CoilTooltipSide {
  /// Above the trigger.
  top,

  /// Below the trigger.
  bottom,

  /// Before the trigger's start: left of it in left-to-right text.
  start,

  /// Past the trigger's end: right of it in left-to-right text.
  end,
}

/// What a tooltip bubble lines up with along its trigger's edge.
enum CoilTooltipFollow {
  /// The trigger's center.
  trigger,

  /// The hovering pointer, following it as it moves, for a long trigger
  /// such as a resize strip. Without a hovering pointer, the trigger's
  /// center.
  pointer,
}

/// The motion of a bubble's presence: in on `quick`, out on `quickExit`.
/// Under reduced motion an overlay only fades, so it's `fade` and
/// `fadeExit` there.
Motion _presenceMotion(
  BuildContext context,
  CoilMotion? override, {
  required bool show,
}) {
  final tokens = CoilTheme.motionOf(context, override: override);
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    return show ? tokens.fade : tokens.fadeExit;
  }
  return show ? tokens.quick : tokens.quickExit;
}

/// The behavior of a tooltip: when it shows, where, and how it springs in
/// and out. The look comes from [bubble].
///
/// * Pointer: it opens after [hoverDelay] of hovering, or at once on
///   keyboard focus, and closes on leave, blur, Esc or pointer-down. Within
///   [skipDelay] of another tooltip closing it opens without the delay.
/// * Touch: on Android a long-press shows it while the finger stays down,
///   without firing [child]. iOS shows none.
///
/// The bubble sits [gap] from [child] on its [side], or on the opposite
/// side when there's no room, lined up as [follow] says. Its enter and
/// exit are whatever [bubble] builds from the presence; coil's tooltip
/// blur-fades and slides in with [CoilTooltipSlide]. Under
/// reduced motion the presence springs on `fade`. It follows [child] every
/// frame while [child] moves in layout, without rebuilding the bubble.
///
/// [semanticLabel] merges into [child]'s semantics as its tooltip; the
/// bubble itself stays out of the semantics tree, so it's announced once.
///
/// Inside a [CoilTooltipAnchorGroup], the group shows one bubble for all
/// its anchors. To show and hide the bubble yourself, use
/// [CoilTooltipAnchor.controlled].
class CoilTooltipAnchor extends StatefulWidget {
  /// Creates a tooltip anchor around [child] that opens on its own
  /// triggers.
  const CoilTooltipAnchor({
    required this.content,
    required String this.semanticLabel,
    required this.bubble,
    required this.child,
    super.key,
    this.side = CoilTooltipSide.top,
    this.follow = CoilTooltipFollow.trigger,
    this.motion,
  }) : presence = null;

  /// Creates a tooltip anchor whose bubble shows while [presence] is above
  /// 0, for a component that decides itself when its bubble shows, like a
  /// slider's value over a pressed thumb.
  ///
  /// It has no triggers, adds nothing to [child]'s semantics and ignores
  /// any [CoilTooltipAnchorGroup]. [presence] drives the transition the
  /// [bubble] builds and the slide, so drive it with the spring the
  /// component wants, from 0 (hidden) to 1 (shown).
  const CoilTooltipAnchor.controlled({
    required Animation<double> this.presence,
    required this.content,
    required this.bubble,
    required this.child,
    super.key,
    this.side = CoilTooltipSide.top,
    this.follow = CoilTooltipFollow.trigger,
  }) : semanticLabel = null,
       motion = null;

  /// What the bubble shows.
  final Widget content;

  /// The tooltip text for screen readers, or null for a controlled anchor.
  final String? semanticLabel;

  /// The bubble's 0→1 presence for a controlled anchor; null for one that
  /// opens on its own triggers.
  final Animation<double>? presence;

  /// Builds the bubble around [content].
  final CoilTooltipBubbleBuilder bubble;

  /// What the tooltip is for.
  final Widget child;

  /// The side of [child] the bubble prefers. Inside a
  /// [CoilTooltipAnchorGroup], the group's side counts instead.
  final CoilTooltipSide side;

  /// What the bubble lines up with along [child]'s edge. Inside a
  /// [CoilTooltipAnchorGroup], the bubble lines up with the trigger.
  final CoilTooltipFollow follow;

  /// Overrides the theme's motion tokens. Unused by a controlled anchor.
  final CoilMotion? motion;

  /// How long a pointer hovers before the tooltip opens.
  static const hoverDelay = Duration(milliseconds: 200);

  /// Within this long of a tooltip closing, the next opens at once.
  static const skipDelay = Duration(milliseconds: 300);

  /// The gap between the trigger and the bubble.
  static const gap = 8.0;

  @override
  State<CoilTooltipAnchor> createState() => _CoilTooltipAnchorState();
}

class _CoilTooltipAnchorState extends State<CoilTooltipAnchor>
    with SingleTickerProviderStateMixin {
  /// When any tooltip last closed, for [CoilTooltipAnchor.skipDelay].
  static Duration? _lastClosed;
  static final _clock = Stopwatch()..start();

  final _portal = OverlayPortalController(debugLabel: 'CoilTooltip');
  late final _presence = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'CoilTooltipAnchor.presence',
  )..addStatusListener(_onStatus);
  Timer? _delay;
  bool _shown = false;

  /// The hovering pointer in [CoilTooltipAnchor.child]'s coordinates, for
  /// [CoilTooltipFollow.pointer]. Only the bubble's placement listens.
  final _pointer = ValueNotifier<Offset?>(null);

  /// The group showing this anchor's tooltip, if any.
  _CoilTooltipAnchorGroupState? _group;

  @override
  void initState() {
    super.initState();
    widget.presence?.addStatusListener(_onControlledStatus);
    _syncControlled();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A controlled anchor shows its own bubble, never the group's.
    _group = widget.presence == null
        ? context.dependOnInheritedWidgetOfExactType<_GroupScope>()?.group
        : null;
  }

  @override
  void didUpdateWidget(CoilTooltipAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      (oldWidget.presence == null) == (widget.presence == null),
      'A CoilTooltipAnchor cannot switch between controlled and not.',
    );
    if (widget.presence != oldWidget.presence) {
      oldWidget.presence?.removeStatusListener(_onControlledStatus);
      widget.presence?.addStatusListener(_onControlledStatus);
      _syncControlled();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    if (_shown) _lastClosed = _clock.elapsed;
    _group?._forget(this);
    widget.presence?.removeStatusListener(_onControlledStatus);
    _presence.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && !_shown && _portal.isShowing) _portal.hide();
  }

  void _onControlledStatus(AnimationStatus _) => _syncControlled();

  /// A controlled bubble is in the overlay while its presence isn't 0.
  void _syncControlled() {
    final presence = widget.presence;
    if (presence == null) return;
    if (presence.isDismissed) {
      if (_portal.isShowing) _portal.hide();
    } else if (!_portal.isShowing) {
      _portal.show();
    }
  }

  void _show() {
    _delay?.cancel();
    if (_shown || !mounted) return;
    _shown = true;
    if (_group case final group?) return group._show(this);
    if (!_portal.isShowing) _portal.show();
    _presence
      ..motion = _presenceMotion(context, widget.motion, show: true)
      ..animateTo(1);
  }

  void _hide() {
    _delay?.cancel();
    if (!_shown) return;
    _shown = false;
    _lastClosed = _clock.elapsed;
    if (_group case final group?) return group._hide(this);
    _presence
      ..motion = _presenceMotion(context, widget.motion, show: false)
      ..animateTo(0);
  }

  void _showAfterDelay() {
    final last = _lastClosed;
    final skip =
        last != null && _clock.elapsed - last < CoilTooltipAnchor.skipDelay;
    if (skip) return _show();
    _delay?.cancel();
    _delay = Timer(CoilTooltipAnchor.hoverDelay, _show);
  }

  void _onFocusChange(bool focused) {
    if (!focused) return _hide();
    if (CoilInputModality.instance.value == CoilModality.keyboard) _show();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_shown &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final presence = widget.presence ?? _presence;
    // Built here, not in the overlay builder, which runs on every layout
    // while the anchor moves: then only the placement updates.
    final bubble = ExcludeSemantics(
      child: widget.bubble(context, presence, widget.content),
    );
    final portal = OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) => IgnorePointer(
        child: _BubblePlacement(
          anchor: MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          ),
          side: widget.side,
          pointer: switch (widget.follow) {
            CoilTooltipFollow.trigger => null,
            CoilTooltipFollow.pointer => (_pointer, info.childPaintTransform),
          },
          child: bubble,
        ),
      ),
      child: _tracked(widget.presence == null ? _trigger() : widget.child),
    );
    final semanticLabel = widget.semanticLabel;
    if (semanticLabel == null) return portal;
    // One node: the trigger's label with the tooltip as its hint.
    return MergeSemantics(
      child: Semantics(
        tooltip: semanticLabel,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: _onFocusChange,
          onKeyEvent: _onKey,
          child: portal,
        ),
      ),
    );
  }

  /// [child] with the hovering pointer tracked, for
  /// [CoilTooltipFollow.pointer].
  Widget _tracked(Widget child) => switch (widget.follow) {
    CoilTooltipFollow.trigger => child,
    CoilTooltipFollow.pointer => MouseRegion(
      onEnter: (event) => _pointer.value = event.localPosition,
      onHover: (event) => _pointer.value = event.localPosition,
      child: child,
    ),
  };

  /// [CoilTooltipAnchor.child] with the pointer and long-press triggers.
  Widget _trigger() {
    final android = defaultTargetPlatform == TargetPlatform.android;
    Widget trigger = Listener(
      onPointerDown: (_) => _hide(),
      child: MouseRegion(
        onEnter: (event) {
          if (CoilInputModality.canHover(event.kind)) _showAfterDelay();
        },
        onExit: (_) => _hide(),
        child: widget.child,
      ),
    );
    if (android) {
      trigger = GestureDetector(
        onLongPressStart: (_) => _show(),
        onLongPressEnd: (_) => _hide(),
        onLongPressCancel: _hide,
        child: trigger,
      );
    }
    return trigger;
  }
}

/// Gives the [CoilTooltipAnchor]s below one shared bubble: moving from one
/// to the next, it glides there on the theme's `quick` spring instead of
/// closing and opening again, as in a toolbar.
///
/// [bubble] builds it around the current anchor's
/// [CoilTooltipAnchor.content]; let its size and content follow changes of
/// the content. The content it gets is keyed by the anchor and the
/// content's own key, so a `MotionSwitcher` around it switches when the
/// bubble moves to another anchor or the content's key changes.
class CoilTooltipAnchorGroup extends StatefulWidget {
  /// Creates a tooltip group around [child].
  const CoilTooltipAnchorGroup({
    required this.bubble,
    required this.child,
    super.key,
    this.side = CoilTooltipSide.top,
    this.motion,
  });

  /// The side of each trigger the shared bubble prefers.
  final CoilTooltipSide side;

  /// Builds the shared bubble around the current anchor's content.
  final CoilTooltipBubbleBuilder bubble;

  /// The area holding the anchors.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilTooltipAnchorGroup> createState() => _CoilTooltipAnchorGroupState();
}

class _CoilTooltipAnchorGroupState extends State<CoilTooltipAnchorGroup>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController(debugLabel: 'CoilTooltipGroup');
  final _area = GlobalKey(debugLabel: 'CoilTooltipGroup.area');
  late final _presence = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'CoilTooltipGroup.presence',
  )..addStatusListener(_onStatus);

  /// The anchor the bubble is on, also while it springs out.
  _CoilTooltipAnchorState? _anchor;

  /// Whether the bubble is wanted.
  bool _open = false;

  /// Bumps when the bubble appears from nothing, so it starts on its anchor
  /// instead of gliding from where it last was.
  int _session = 0;

  CoilMotion get _tokens =>
      CoilTheme.motionOf(context, override: widget.motion);

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && !_open && _portal.isShowing) _portal.hide();
  }

  void _show(_CoilTooltipAnchorState anchor) {
    setState(() {
      if (_presence.value == 0) _session++;
      _anchor = anchor;
      _open = true;
    });
    if (!_portal.isShowing) _portal.show();
    _presence
      ..motion = _presenceMotion(context, widget.motion, show: true)
      ..animateTo(1);
  }

  /// An anchor left the tree: the bubble has nothing to point at. The tree
  /// is locked while it disposes, so the bubble goes after the frame.
  void _forget(_CoilTooltipAnchorState anchor) {
    if (_anchor != anchor) return;
    _anchor = null;
    _open = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _open) return;
      _presence.value = 0;
      if (_portal.isShowing) _portal.hide();
    });
  }

  void _hide(_CoilTooltipAnchorState anchor) {
    if (_anchor != anchor || !_open) return;
    _open = false;
    _presence
      ..motion = _presenceMotion(context, widget.motion, show: false)
      ..animateTo(0);
  }

  /// The anchor's rect in the overlay, from the area's place in it.
  Rect? _anchorRect(OverlayChildLayoutInfo info) {
    final anchor = _anchor?.context.findRenderObject();
    final area = _area.currentContext?.findRenderObject();
    if (anchor is! RenderBox || area is! RenderBox || !anchor.attached) {
      return null;
    }
    final transform = info.childPaintTransform.clone()
      ..multiply(anchor.getTransformTo(area));
    return MatrixUtils.transformRect(transform, Offset.zero & anchor.size);
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _anchor;
    // Built here, not in the overlay builder, which runs on every layout.
    final bubble = anchor == null
        ? null
        : ExcludeSemantics(
            child: widget.bubble(
              context,
              _presence,
              KeyedSubtree(
                key: ValueKey((anchor, anchor.widget.content.key)),
                child: anchor.widget.content,
              ),
            ),
          );
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final rect = _anchorRect(info);
        if (rect == null || bubble == null) return const SizedBox.shrink();
        return IgnorePointer(
          child: MotionBuilder<Rect>(
            key: ValueKey(_session),
            value: rect,
            converter: MotionConverter.rect,
            motion: _tokens.quick,
            // Laid out on the anchor it heads for; the glide is painted.
            builder: (context, glide, child) => _BubblePlacement(
              anchor: rect,
              side: widget.side,
              glide: glide,
              child: child,
            ),
            child: bubble,
          ),
        );
      },
      child: _GroupScope(
        group: this,
        child: KeyedSubtree(key: _area, child: widget.child),
      ),
    );
  }
}

class _GroupScope extends InheritedWidget {
  const _GroupScope({required this.group, required super.child});

  final _CoilTooltipAnchorGroupState group;

  @override
  bool updateShouldNotify(_GroupScope oldWidget) => oldWidget.group != group;
}

/// Places the bubble on [side] of the trigger, or on the opposite side
/// when there's no room, lined up with [pointer] when given.
///
/// In a group, [glide] is where the bubble is on its way to [anchor]: the
/// bubble is drawn there as if it were placed on that rect.
class _BubblePlacement extends SingleChildRenderObjectWidget {
  const _BubblePlacement({
    required this.anchor,
    required this.side,
    this.pointer,
    this.glide,
    super.child,
  });

  /// The trigger's rect in the overlay.
  final Rect anchor;

  final CoilTooltipSide side;

  /// The hovering pointer in the trigger's coordinates, and the trigger's
  /// transform into the overlay.
  final (ValueListenable<Offset?>, Matrix4)? pointer;

  /// The rect the bubble is drawn on while it glides to [anchor].
  final Rect? glide;

  @override
  _RenderBubblePlacement createRenderObject(BuildContext context) =>
      _RenderBubblePlacement(
        anchor: anchor,
        side: side,
        pointer: pointer,
        glide: glide,
        textDirection: Directionality.of(context),
        safeArea: MediaQuery.paddingOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBubblePlacement renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..side = side
      ..pointer = pointer
      ..glide = glide
      ..textDirection = Directionality.of(context)
      ..safeArea = MediaQuery.paddingOf(context);
  }
}

/// Lays the bubble out at rest on its anchor and paints the glide as a
/// resample of it (a matrix image filter), as the popover's grow does.
/// Moved by layout, the text would snap to the pixel grid on every frame.
/// While the bubble resizes, its centered content stays put.
class _RenderBubblePlacement extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderBubblePlacement({
    required this._anchor,
    required this._side,
    required this._pointer,
    required this._glide,
    required this._textDirection,
    required this._safeArea,
  });

  static const _edge = 8.0;

  /// The placement [descendant] is drawn in, if any.
  static _RenderBubblePlacement? maybeOf(RenderObject descendant) {
    for (var node = descendant.parent; node != null; node = node.parent) {
      if (node is _RenderBubblePlacement) return node;
    }
    return null;
  }

  Rect get anchor => _anchor;
  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    _updateGliding();
    markNeedsLayout();
  }

  CoilTooltipSide get side => _side;
  CoilTooltipSide _side;
  set side(CoilTooltipSide value) {
    if (value == _side) return;
    _side = value;
    markNeedsLayout();
  }

  (ValueListenable<Offset?>, Matrix4)? get pointer => _pointer;
  (ValueListenable<Offset?>, Matrix4)? _pointer;
  set pointer((ValueListenable<Offset?>, Matrix4)? value) {
    if (value == _pointer) return;
    if (attached) _pointer?.$1.removeListener(markNeedsLayout);
    _pointer = value;
    if (attached) _pointer?.$1.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  Rect? get glide => _glide;
  Rect? _glide;
  set glide(Rect? value) {
    if (value == _glide) return;
    _glide = value;
    _updateGliding();
    markNeedsPaint();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  EdgeInsets get safeArea => _safeArea;
  EdgeInsets _safeArea;
  set safeArea(EdgeInsets value) {
    if (value == _safeArea) return;
    _safeArea = value;
    markNeedsLayout();
  }

  Offset _childOffset = Offset.zero;

  /// Which way the bubble is from its trigger, picked in layout.
  AxisDirection get direction => _direction;
  AxisDirection _direction = AxisDirection.up;

  /// Whether the bubble is mid-glide, so painted through a matrix filter.
  bool _gliding = false;

  bool get _shouldGlide => _glide != null && _glide != _anchor;

  void _updateGliding() {
    final gliding = _shouldGlide;
    if (gliding == _gliding) return;
    _gliding = gliding;
    markNeedsCompositingBitsUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => _gliding;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pointer?.$1.addListener(markNeedsLayout);
    _gliding = _shouldGlide;
  }

  @override
  void detach() {
    _pointer?.$1.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// The preferred side as a direction from the trigger.
  AxisDirection get _preferred {
    final ltr = _textDirection == TextDirection.ltr;
    return switch (_side) {
      CoilTooltipSide.top => AxisDirection.up,
      CoilTooltipSide.bottom => AxisDirection.down,
      CoilTooltipSide.start => ltr ? AxisDirection.left : AxisDirection.right,
      CoilTooltipSide.end => ltr ? AxisDirection.right : AxisDirection.left,
    };
  }

  /// Whether a bubble of [bubble]'s size fits on [direction] of the anchor.
  bool _fits(AxisDirection direction, Size bubble) {
    const gap = CoilTooltipAnchor.gap;
    final room = switch (direction) {
      AxisDirection.up => _anchor.top - gap - _safeArea.top - _edge,
      AxisDirection.down =>
        size.height - _safeArea.bottom - _edge - _anchor.bottom - gap,
      AxisDirection.left => _anchor.left - gap - _safeArea.left - _edge,
      AxisDirection.right =>
        size.width - _safeArea.right - _edge - _anchor.right - gap,
    };
    return room >=
        switch (axisDirectionToAxis(direction)) {
          Axis.vertical => bubble.height,
          Axis.horizontal => bubble.width,
        };
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    child.layout(
      BoxConstraints.loose(size).deflate(const EdgeInsets.all(_edge)),
      parentUsesSize: true,
    );
    final preferred = _preferred;
    _direction = _fits(preferred, child.size)
        ? preferred
        : flipAxisDirection(preferred);
    _childOffset = _place(_anchor, pointer: _pointerInOverlay);
  }

  /// The hovering pointer in the overlay, if the bubble follows it.
  Offset? get _pointerInOverlay {
    final (pointer, transform) = _pointer ?? (null, null);
    final local = pointer?.value;
    if (local == null || transform == null) return null;
    return MatrixUtils.transformPoint(transform, local);
  }

  /// Where the bubble goes for [anchor] on the side picked in layout,
  /// lined up with [pointer] if given, else with the anchor's center. It
  /// stays inside the overlay's edges and safe area.
  Offset _place(Rect anchor, {Offset? pointer}) {
    final bubble = child!.size;
    const gap = CoilTooltipAnchor.gap;
    final focus = pointer ?? anchor.center;
    double within(double value, double min, double max) =>
        value.clamp(min, math.max(min, max));
    final x = within(
      focus.dx - bubble.width / 2,
      _edge + _safeArea.left,
      size.width - _edge - _safeArea.right - bubble.width,
    );
    final y = within(
      focus.dy - bubble.height / 2,
      _edge + _safeArea.top,
      size.height - _edge - _safeArea.bottom - bubble.height,
    );
    return switch (_direction) {
      AxisDirection.up => Offset(x, anchor.top - gap - bubble.height),
      AxisDirection.down => Offset(x, anchor.bottom + gap),
      AxisDirection.left => Offset(anchor.left - gap - bubble.width, y),
      AxisDirection.right => Offset(anchor.right + gap, y),
    };
  }

  /// The glide's remaining way: how far the bubble is drawn from where it's
  /// laid out.
  Offset get _glideOffset {
    final glide = _glide;
    return glide == null || child == null
        ? Offset.zero
        : _place(glide) - _childOffset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final origin = offset + _childOffset;
    if (!_gliding) {
      layer = null;
      context.paintChild(child, origin);
      return;
    }
    layer = _pushTranslation(context, layer, _glideOffset, child, origin);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = _childOffset + _glideOffset;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _childOffset + _glideOffset,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}

/// Paints [child] at [origin] moved by [move], as a resample of it drawn at
/// rest (a matrix image filter): text moves as one image instead of
/// snapping to the pixel grid each frame. Returns the layer to keep.
ImageFilterLayer _pushTranslation(
  PaintingContext context,
  ContainerLayer? oldLayer,
  Offset move,
  RenderBox child,
  Offset origin,
) {
  final filter = ImageFilter.matrix(
    Matrix4.translationValues(move.dx, move.dy, 0).storage,
  );
  final layer = switch (oldLayer) {
    final ImageFilterLayer layer => layer..imageFilter = filter,
    _ => ImageFilterLayer(imageFilter: filter),
  };
  context.pushLayer(
    layer,
    (context, offset) => context.paintChild(child, offset),
    origin,
  );
  return layer;
}

/// A tooltip bubble's slide: [child] is drawn [distance] away from the
/// trigger at [presence] 0 and comes to rest at 1, toward the trigger of
/// the [CoilTooltipAnchor] whose bubble it's in, on whichever side the
/// bubble sits. Under reduced motion it doesn't move.
///
/// Like the rest of an enter transition it belongs in the anchor's bubble
/// builder, around the bubble:
///
/// ```dart
/// bubble: (context, presence, content) => CoilBlurFade(
///   presence: presence,
///   scale: 1,
///   child: CoilTooltipSlide(
///     presence: presence,
///     child: CoilTooltipBubble(child: content),
///   ),
/// ),
/// ```
///
/// The slide is painted as a resample of [child] drawn at rest, so text
/// moves as one image. A spring's overshoot is kept.
class CoilTooltipSlide extends SingleChildRenderObjectWidget {
  /// Creates a slide driven by [presence].
  const CoilTooltipSlide({
    required this.presence,
    required super.child,
    super.key,
    this.distance = 4,
  });

  /// 0 (gone) to 1 (at rest).
  final Animation<double> presence;

  /// How far from rest [child] is at presence 0, in logical pixels.
  final double distance;

  double _distance(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? 0 : distance;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTooltipSlide(presence: presence, distance: _distance(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTooltipSlide)
      ..presence = presence
      ..distance = _distance(context);
  }
}

class _RenderTooltipSlide extends RenderProxyBox {
  _RenderTooltipSlide({
    required this._presence,
    required this._distance,
  });

  Animation<double> get presence => _presence;
  Animation<double> _presence;
  set presence(Animation<double> value) {
    if (value == _presence) return;
    if (attached) _presence.removeListener(_onPresence);
    _presence = value;
    if (attached) _presence.addListener(_onPresence);
    _onPresence();
  }

  double get distance => _distance;
  double _distance;
  set distance(double value) {
    if (value == _distance) return;
    _distance = value;
    _onPresence();
  }

  /// Whether it's mid-slide, so painted through a matrix filter.
  bool _sliding = false;

  bool get _shouldSlide => _distance != 0 && _presence.value != 1;

  void _onPresence() {
    final sliding = _shouldSlide;
    if (sliding != _sliding) {
      _sliding = sliding;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _sliding;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _presence.addListener(_onPresence);
    _sliding = _shouldSlide;
  }

  @override
  void detach() {
    _presence.removeListener(_onPresence);
    super.detach();
  }

  /// Away from the trigger, on whichever side the bubble sits.
  Offset get _offset {
    if (!_sliding) return Offset.zero;
    final placement = _RenderBubblePlacement.maybeOf(this);
    assert(
      placement != null,
      'CoilTooltipSlide must be inside a CoilTooltipAnchor bubble.',
    );
    final away = _distance * (1 - _presence.value);
    return switch (placement?.direction ?? AxisDirection.up) {
      AxisDirection.up => Offset(0, -away),
      AxisDirection.down => Offset(0, away),
      AxisDirection.left => Offset(-away, 0),
      AxisDirection.right => Offset(away, 0),
    };
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_sliding) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = _pushTranslation(context, layer, _offset, child, offset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = _offset;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _offset,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
