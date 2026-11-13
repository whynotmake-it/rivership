import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/motion_transition.dart';

/// Lays out the children of a [MotionSwitcher]: the [currentChild], if any,
/// and the [previousChildren] that are still leaving, oldest first.
///
/// The same signature as [AnimatedSwitcherLayoutBuilder].
typedef MotionSwitcherLayoutBuilder =
    Widget Function(
      Widget? currentChild,
      List<Widget> previousChildren,
    );

/// A widget that springs between children, the Motor version of
/// [AnimatedSwitcher].
///
/// Like [AnimatedSwitcher], a new [child] is one that can't update the old
/// one (see [Widget.canUpdate]): give children of the same type different
/// keys to switch between them.
///
/// Every child has a presence value on its own spring, which [transition]
/// turns into how the child looks: 0 when it's gone, 1 when it's fully
/// present. An entering child springs to 1 with [motion], a leaving one to 0
/// with [exitMotion] and is removed once it has settled there. There are no
/// curves: an interrupted switch keeps every child's velocity. When a child
/// whose key comes back while it is still leaving, it turns around from its
/// current presence and velocity instead of starting over, and its state is
/// kept.
///
/// The first child is shown without a transition.
///
/// ```dart
/// MotionSwitcher(
///   motion: const .smoothSpring(),
///   exitMotion: const .snappySpring(),
///   transition: const .blurFade(),
///   child: Text('$count', key: ValueKey(count)),
/// )
/// ```
class MotionSwitcher extends StatefulWidget {
  /// Creates a [MotionSwitcher].
  const MotionSwitcher({
    required this.motion,
    this.child,
    this.exitMotion,
    this.transition = MotionTransition.fade,
    this.layoutBuilder = MotionSwitcher.defaultLayoutBuilder,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The current child. Null shows nothing once the previous child has left.
  final Widget? child;

  /// The spring an entering child follows to presence 1.
  final Motion motion;

  /// The spring a leaving child follows to presence 0.
  ///
  /// Usually a tighter spring than [motion], so things leave faster than
  /// they arrive. Defaults to [motion].
  final Motion? exitMotion;

  /// How a child looks at a presence value. Defaults to
  /// [MotionTransition.fade].
  final MotionTransition transition;

  /// Lays out the current and the leaving children. Defaults to
  /// [defaultLayoutBuilder].
  final MotionSwitcherLayoutBuilder layoutBuilder;

  /// How often the animations tick, for example `tickerRate: .fps(30)`.
  ///
  /// Overrides the nearest [TickerRateScope]. Without either, they tick every
  /// frame.
  final TickerRate? tickerRate;

  /// A name for the children's controllers, shown by inspection tools such as
  /// `motor_devtools`.
  final String? debugLabel;

  /// Stacks the leaving children under the current one, centered, like
  /// [AnimatedSwitcher.defaultLayoutBuilder].
  static Widget defaultLayoutBuilder(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
    );
  }

  @override
  State<MotionSwitcher> createState() => _MotionSwitcherState();
}

class _Entry {
  _Entry(this.widget, {required this.entering});

  Widget widget;

  /// Whether the entry springs in from presence 0 when it is first built.
  final bool entering;

  bool leaving = false;

  /// Keeps the child's state while it moves between the current slot and
  /// the leaving list, which a layout builder may put in different parents.
  late final GlobalKey key = GlobalObjectKey(this);
}

class _MotionSwitcherState extends State<MotionSwitcher> {
  _Entry? _current;

  /// Children that are leaving, oldest first.
  final _leaving = <_Entry>[];

  @override
  void initState() {
    super.initState();
    if (widget.child case final child?) {
      _current = _Entry(child, entering: false);
    }
  }

  @override
  void didUpdateWidget(MotionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final child = widget.child;
    final current = _current;
    if (current != null &&
        child != null &&
        Widget.canUpdate(current.widget, child)) {
      current.widget = child;
      return;
    }

    if (current != null) _leaving.add(current..leaving = true);
    _current = child == null ? null : _enter(child);
  }

  /// Brings [child] in: turns around the latest leaving entry it can update,
  /// or creates a new one.
  _Entry _enter(Widget child) {
    var returning = -1;
    for (var i = _leaving.length - 1; i >= 0 && returning < 0; i--) {
      if (Widget.canUpdate(_leaving[i].widget, child)) returning = i;
    }
    if (returning < 0) return _Entry(child, entering: true);
    return _leaving.removeAt(returning)
      ..widget = child
      ..leaving = false;
  }

  /// Removes [entry] once it has settled at presence 0. An entry that came
  /// back in the meantime is no longer leaving and stays.
  void _onStatus(_Entry entry, AnimationStatus status) {
    if (status.isAnimating || !entry.leaving) return;
    setState(() => _leaving.remove(entry));
  }

  Widget _build(_Entry entry) {
    return KeyedSubtree(
      key: entry.key,
      child: SingleMotionBuilder(
        value: entry.leaving ? 0 : 1,
        from: entry.entering ? 0 : null,
        motion: entry.leaving
            ? widget.exitMotion ?? widget.motion
            : widget.motion,
        velocityTracking: const VelocityTracking.off(),
        onAnimationStatusChanged: (status) => _onStatus(entry, status),
        tickerRate: widget.tickerRate,
        debugLabel:
            '${widget.debugLabel ?? 'MotionSwitcher'} '
            '${entry.widget.key ?? entry.widget.runtimeType}',
        builder: (context, presence, child) =>
            widget.transition.build(context, presence, child!),
        child: entry.widget,
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
