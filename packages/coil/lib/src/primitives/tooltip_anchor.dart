import 'dart:async';

import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The behavior of a tooltip: when it shows, where, and how it springs in
/// and out. The look comes from [bubble].
///
/// * Pointer: it opens after [hoverDelay] of hovering, or at once on
///   keyboard focus, and closes on leave, blur, Esc or pointer-down. Within
///   [skipDelay] of another tooltip closing it opens without the delay.
/// * Touch: on Android a long-press shows it while the finger stays down,
///   without firing [child]. iOS shows none.
///
/// The bubble sits [gap] above [child], or below when there's no room
/// above, and slides the last 4 px toward it as it appears. [message]
/// merges into [child]'s semantics as its tooltip.
///
/// Inside a [CoilTooltipAnchorGroup], the group shows one bubble for all
/// its anchors.
class CoilTooltipAnchor extends StatefulWidget {
  /// Creates a tooltip anchor around [child].
  const CoilTooltipAnchor({
    required this.message,
    required this.bubble,
    required this.child,
    super.key,
    this.motion,
  });

  /// The tooltip text for screen readers.
  final String message;

  /// Builds the bubble, given the 0→1 presence to animate it with.
  final Widget Function(BuildContext context, Animation<double> presence)
  bubble;

  /// What the tooltip is for.
  final Widget child;

  /// Overrides the theme's motion tokens.
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

  /// The group showing this anchor's tooltip, if any.
  _CoilTooltipAnchorGroupState? _group;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group = context.dependOnInheritedWidgetOfExactType<_GroupScope>()?.group;
  }

  @override
  void dispose() {
    _delay?.cancel();
    if (_shown) _lastClosed = _clock.elapsed;
    _group?._forget(this);
    _presence.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && !_shown && _portal.isShowing) _portal.hide();
  }

  CoilMotion get _tokens =>
      CoilTheme.motionOf(context, override: widget.motion);

  void _show() {
    _delay?.cancel();
    if (_shown || !mounted) return;
    _shown = true;
    if (_group case final group?) return group._show(this);
    if (!_portal.isShowing) _portal.show();
    _presence
      ..motion = _tokens.quick
      ..animateTo(1);
  }

  void _hide() {
    _delay?.cancel();
    if (!_shown) return;
    _shown = false;
    _lastClosed = _clock.elapsed;
    if (_group case final group?) return group._hide(this);
    _presence
      ..motion = _tokens.quickExit
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
    // One node: the trigger's label with the tooltip as its hint.
    return MergeSemantics(
      child: Semantics(
        tooltip: widget.message,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: _onFocusChange,
          onKeyEvent: _onKey,
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portal,
            overlayChildBuilder: (context, info) => IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _BubbleLayout(
                  anchor: MatrixUtils.transformRect(
                    info.childPaintTransform,
                    Offset.zero & info.childSize,
                  ),
                  safeTop: MediaQuery.paddingOf(context).top,
                  presence: _presence,
                ),
                child: widget.bubble(context, _presence),
              ),
            ),
            child: trigger,
          ),
        ),
      ),
    );
  }
}

/// Gives the [CoilTooltipAnchor]s below one shared bubble: moving from one
/// to the next, it glides there on the theme's `quick` spring instead of
/// closing and opening again, as in a toolbar.
///
/// [bubble] builds it for the current [CoilTooltipAnchor.message]; let its
/// width and label follow the message's changes.
class CoilTooltipAnchorGroup extends StatefulWidget {
  /// Creates a tooltip group around [child].
  const CoilTooltipAnchorGroup({
    required this.bubble,
    required this.child,
    super.key,
    this.motion,
  });

  /// Builds the bubble for a message, given the 0→1 presence.
  final Widget Function(
    BuildContext context,
    Animation<double> presence,
    String message,
  )
  bubble;

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
      ..motion = _tokens.quick
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
      ..motion = _tokens.quickExit
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
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _portal,
    overlayChildBuilder: (context, info) {
      final rect = _anchorRect(info);
      final anchor = _anchor;
      if (rect == null || anchor == null) return const SizedBox.shrink();
      return IgnorePointer(
        child: MotionBuilder<Rect>(
          key: ValueKey(_session),
          value: rect,
          converter: MotionConverter.rect,
          motion: _tokens.quick,
          builder: (context, rect, child) => CustomSingleChildLayout(
            delegate: _BubbleLayout(
              anchor: rect,
              safeTop: MediaQuery.paddingOf(context).top,
              presence: _presence,
            ),
            child: child,
          ),
          child: widget.bubble(context, _presence, anchor.widget.message),
        ),
      );
    },
    child: _GroupScope(
      group: this,
      child: KeyedSubtree(key: _area, child: widget.child),
    ),
  );
}

class _GroupScope extends InheritedWidget {
  const _GroupScope({required this.group, required super.child});

  final _CoilTooltipAnchorGroupState group;

  @override
  bool updateShouldNotify(_GroupScope oldWidget) => oldWidget.group != group;
}

/// Places the bubble above the trigger, or below when there's no room
/// above, and slides it the last 4 px toward the trigger as it appears.
class _BubbleLayout extends SingleChildLayoutDelegate {
  _BubbleLayout({
    required this.anchor,
    required this.safeTop,
    required this.presence,
  }) : super(relayout: presence);

  final Rect anchor;
  final double safeTop;
  final Animation<double> presence;

  static const _edge = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(
        const EdgeInsets.all(_edge),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final roomAbove = anchor.top - CoilTooltipAnchor.gap - safeTop - _edge;
    final above = roomAbove >= child.height;
    final slide = 4 * (1 - presence.value.clamp(0.0, 1.0));
    final y = above
        ? anchor.top - CoilTooltipAnchor.gap - child.height - slide
        : anchor.bottom + CoilTooltipAnchor.gap + slide;
    final x = (anchor.center.dx - child.width / 2).clamp(
      _edge,
      size.width - _edge - child.width,
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BubbleLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.safeTop != safeTop ||
      oldDelegate.presence != presence;
}
