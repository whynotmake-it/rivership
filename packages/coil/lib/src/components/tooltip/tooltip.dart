import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A short label that appears next to [child]: an inverted bubble that
/// names an icon-only control.
///
/// * Pointer: it opens after [hoverDelay] of hovering, or at once on
///   keyboard focus, and closes on leave, blur, Esc or pointer-down. Within
///   [skipDelay] of another tooltip closing it opens without the delay, so
///   scanning a toolbar doesn't wait at every button.
/// * Touch: on Android a long-press shows it while the finger stays down,
///   without firing [child]. iOS shows none, like the platform.
///
/// [message] is also the tooltip screen readers announce. Don't put
/// required information in a tooltip, and don't tooltip a labelled button.
class CoilTooltip extends StatefulWidget {
  /// Creates a tooltip for [child].
  const CoilTooltip({
    required this.message,
    required this.child,
    super.key,
    this.motion,
  });

  /// The label.
  final String message;

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
  State<CoilTooltip> createState() => _CoilTooltipState();
}

class _CoilTooltipState extends State<CoilTooltip>
    with SingleTickerProviderStateMixin {
  /// When any tooltip last closed, for [CoilTooltip.skipDelay].
  static Duration? _lastClosed;
  static final _clock = Stopwatch()..start();

  final _portal = OverlayPortalController(debugLabel: 'CoilTooltip');
  late final _presence = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'CoilTooltip.presence',
  )..addStatusListener(_onStatus);
  Timer? _delay;
  bool _shown = false;

  @override
  void dispose() {
    _delay?.cancel();
    if (_shown) _lastClosed = _clock.elapsed;
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
    _presence
      ..motion = _tokens.quickExit
      ..animateTo(0);
  }

  void _showAfterDelay() {
    final last = _lastClosed;
    final skip = last != null && _clock.elapsed - last < CoilTooltip.skipDelay;
    if (skip) return _show();
    _delay?.cancel();
    _delay = Timer(CoilTooltip.hoverDelay, _show);
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
            overlayChildBuilder: (context, info) => _Bubble(
              info: info,
              presence: _presence,
              message: widget.message,
            ),
            child: trigger,
          ),
        ),
      ),
    );
  }
}

/// The inverted bubble, placed above the trigger, or below when there's no
/// room above.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.info,
    required this.presence,
    required this.message,
  });

  final OverlayChildLayoutInfo info;
  final Animation<double> presence;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, tier: CoilTier.pointer);
    final anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: CustomSingleChildLayout(
        delegate: _BubbleLayout(
          anchor: anchor,
          safeTop: top,
          presence: presence,
        ),
        child: CoilBlurFade(
          presence: presence,
          scale: 1,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.colors.foreground,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(
                  CoilTheme.radiiOf(context).item,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Text(
                message,
                style: theme.typography.style(
                  metrics.caption,
                  color: theme.colors.background,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final roomAbove = anchor.top - CoilTooltip.gap - safeTop - _edge;
    final above = roomAbove >= child.height;
    final slide = 4 * (1 - presence.value.clamp(0.0, 1.0));
    final y = above
        ? anchor.top - CoilTooltip.gap - child.height - slide
        : anchor.bottom + CoilTooltip.gap + slide;
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
