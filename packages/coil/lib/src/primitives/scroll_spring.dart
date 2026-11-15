import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Springs a scroll position to a target, for keyboard scrolling.
///
/// The spring runs as the position's own ballistic activity, so a user
/// drag takes over, notifications go out and the velocity carries, as with
/// a fling. A repeated key adds to where the scroll is headed instead of
/// starting over: read [targetOf] to step from there.
abstract final class CoilScrollSpring {
  /// Springs [controller] to [target] (clamped to its extent) on [motion].
  static void scrollTo(
    ScrollController controller,
    double target,
    Motion motion,
  ) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position is! ScrollPositionWithSingleContext) {
      position.jumpTo(target);
      return;
    }
    final to = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    final spring = _SpringActivity(
      position,
      motion.createSimulation(
        start: position.pixels,
        end: to,
        velocity: _running[position]?.velocity ?? 0,
      ),
      target: to,
      vsync: position.context.vsync,
    );
    position.beginActivity(spring);
    _running[position] = spring;
  }

  /// The spring running on a position, until a drag or another activity
  /// replaces it.
  static final _running = Expando<_SpringActivity>('CoilScrollSpring');

  /// Where [controller] is headed: the spring's target while one runs,
  /// else where it is.
  static double targetOf(ScrollController controller) {
    final position = controller.position;
    return _running[position]?.target ?? position.pixels;
  }
}

class _SpringActivity extends BallisticScrollActivity {
  _SpringActivity(
    ScrollActivityDelegate delegate,
    Simulation simulation, {
    required this.target,
    required TickerProvider vsync,
  }) : super(delegate, simulation, vsync, false);

  final double target;

  @override
  void dispose() {
    final position = delegate;
    if (position is ScrollPosition &&
        CoilScrollSpring._running[position] == this) {
      CoilScrollSpring._running[position] = null;
    }
    super.dispose();
  }
}
