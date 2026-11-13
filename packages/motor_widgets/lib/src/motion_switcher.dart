import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// A widget that springs between children, the Motor version of
/// [AnimatedSwitcher], with the same [transitionBuilder] and
/// [layoutBuilder].
///
/// Like [AnimatedSwitcher], a new [child] is one that can't update the old
/// one (see [Widget.canUpdate]): give children of the same type different
/// keys to switch between them.
///
/// Every child has a presence spring, handed to [transitionBuilder] as an
/// [Animation<double>]: 0 when the child is gone, 1 when it is fully
/// present. An entering child springs to 1 with [motion], a leaving one to 0
/// with [exitMotion], and is removed once it has settled there. There are no
/// curves: an interrupted switch keeps every child's velocity. A child whose
/// key comes back while it is still leaving turns around from its current
/// presence and velocity instead of starting over, and keeps its state.
///
/// ## Presence overshoots
///
/// The animation is the spring's raw value, so a bouncy spring takes it past
/// 1 on the way in, or below 0 on the way out. Flutter's transitions handle
/// that: [FadeTransition] clamps the opacity it paints, and [ScaleTransition]
/// or [SlideTransition] simply overshoot, which is what makes a spring
/// bounce. Only code that hands `animation.value` to a widget that asserts
/// its range, such as [Opacity], needs to clamp it.
///
/// The animation's status is [AnimationStatus.forward] while a child enters
/// and [AnimationStatus.reverse] while it leaves.
///
/// The first child is shown without a transition.
///
/// ```dart
/// MotionSwitcher(
///   motion: const .smoothSpring(),
///   exitMotion: const .snappySpring(duration: Duration(milliseconds: 300)),
///   transitionBuilder: (child, animation) =>
///       ScaleTransition(scale: animation, child: child),
///   child: Text('$count', key: ValueKey(count)),
/// )
/// ```
class MotionSwitcher extends StatefulWidget {
  /// Creates a [MotionSwitcher].
  const MotionSwitcher({
    required this.motion,
    this.child,
    this.exitMotion,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The current child. Null shows nothing once the previous child has left.
  final Widget? child;

  /// The spring an entering child follows to presence 1.
  ///
  /// Replaces [AnimatedSwitcher.duration] and
  /// [AnimatedSwitcher.switchInCurve].
  final Motion motion;

  /// The spring a leaving child follows to presence 0.
  ///
  /// Usually a tighter spring than [motion], so things leave faster than
  /// they arrive. Defaults to [motion]. Replaces
  /// [AnimatedSwitcher.reverseDuration] and [AnimatedSwitcher.switchOutCurve].
  final Motion? exitMotion;

  /// Wraps a child in a transition driven by its presence. Defaults to
  /// [AnimatedSwitcher.defaultTransitionBuilder], a [FadeTransition].
  ///
  /// See [AnimatedSwitcher.transitionBuilder]. The animation may leave
  /// `[0, 1]`; see "Presence overshoots" above.
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  /// Lays out the current and the leaving children, oldest first. Defaults
  /// to [AnimatedSwitcher.defaultLayoutBuilder].
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  State<MotionSwitcher> createState() => _MotionSwitcherState();
}

class _Entry {
  _Entry({required this.widget, required this.controller});

  Widget widget;

  /// The child's presence: what [MotionSwitcher.transitionBuilder] gets.
  final SingleMotionController controller;

  bool leaving = false;

  /// The transition built for [widget], rebuilt only when the child or the
  /// builder changes, as in [AnimatedSwitcher].
  Widget? transition;

  /// Keeps the child's state while it moves between the current slot and
  /// the leaving list, which a layout builder may put in different parents.
  late final GlobalKey key = GlobalObjectKey(this);
}

class _MotionSwitcherState extends State<MotionSwitcher>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin {
  _Entry? _current;

  /// Children that are leaving, oldest first.
  final _leaving = <_Entry>[];

  @override
  TickerRate? get widgetTickerRate => widget.tickerRate;

  Motion get _exitMotion => widget.exitMotion ?? widget.motion;

  @override
  void initState() {
    super.initState();
    if (widget.child case final child?) {
      _current = _createEntry(child, presence: 1);
    }
  }

  _Entry _createEntry(Widget child, {required double presence}) {
    late final _Entry entry;
    return entry =
        _Entry(
            widget: child,
            controller: SingleMotionController(
              motion: widget.motion,
              vsync: this,
              initialValue: presence,
              // Presence only ever springs between 0 and 1; nothing sets it.
              velocityTracking: const VelocityTracking.off(),
              debugLabel:
                  '${widget.debugLabel ?? 'MotionSwitcher'} '
                  '${child.key ?? child.runtimeType}',
            ),
          )
          ..controller.addStatusListener((status) {
            // A leaving child is gone once its presence settles at 0, however
            // often its motion changed on the way.
            if (status.isDismissed && entry.leaving) _remove(entry);
          });
  }

  @override
  void didUpdateWidget(MotionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tickerRate != oldWidget.tickerRate) updateTickerRate();

    if (widget.motion != oldWidget.motion ||
        widget.exitMotion != oldWidget.exitMotion) {
      _current?.controller.motion = widget.motion;
      for (final entry in _leaving) {
        entry.controller.motion = _exitMotion;
      }
    }
    if (widget.transitionBuilder != oldWidget.transitionBuilder) {
      _current?.transition = null;
      for (final entry in _leaving) {
        entry.transition = null;
      }
    }

    final child = widget.child;
    final current = _current;
    if (current != null &&
        child != null &&
        Widget.canUpdate(current.widget, child)) {
      current
        ..widget = child
        ..transition = null;
      return;
    }

    if (current != null) _leave(current);
    _current = child == null ? null : _enter(child);
  }

  /// Brings [child] in: turns around the latest leaving entry it can update,
  /// or creates a new one at presence 0.
  _Entry _enter(Widget child) {
    _Entry? entry;
    for (var i = _leaving.length - 1; i >= 0 && entry == null; i--) {
      if (Widget.canUpdate(_leaving[i].widget, child)) {
        entry = _leaving.removeAt(i);
      }
    }
    entry ??= _createEntry(child, presence: 0);
    entry
      ..widget = child
      ..transition = null
      ..leaving = false;
    // Setting the motion first redirects a moving spring with its velocity,
    // and animateTo keeps that velocity.
    entry.controller
      ..motion = widget.motion
      ..animateTo(1);
    return entry;
  }

  void _leave(_Entry entry) {
    entry.leaving = true;
    _leaving.add(entry);
    entry.controller
      ..motion = _exitMotion
      ..animateTo(0);
  }

  /// Removes [entry] once it has settled at presence 0. The future of an
  /// entry that came back in the meantime is canceled and never gets here.
  void _remove(_Entry entry) {
    setState(() => _leaving.remove(entry));
    entry.controller.dispose();
  }

  @override
  void dispose() {
    _current?.controller.dispose();
    for (final entry in _leaving) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  Widget _build(_Entry entry) {
    return KeyedSubtree(
      key: entry.key,
      child: entry.transition ??= widget.transitionBuilder(
        entry.widget,
        entry.controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.layoutBuilder(
      switch (_current) {
        final current? => _build(current),
        null => null,
      },
      [for (final entry in _leaving) _build(entry)],
    );
  }
}
