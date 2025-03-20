import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

@immutable
abstract class Motion {
  const Motion({
    this.tolerance = Tolerance.defaultTolerance,
  });

  final Tolerance tolerance;

  /// Whether this motion needs to settle.
  ///
  /// If this is true, the motion will continue to animate until the velocity
  /// is less than the [tolerance], whenever it is supposed to be stopped.
  bool get needsSettle;

  /// Creates a simulation for this motion.
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  });
}

@immutable
class DurationAndCurve extends Motion {
  const DurationAndCurve({
    required this.duration,
    this.curve = Curves.linear,
    super.tolerance = Tolerance.defaultTolerance,
  });

  final Duration duration;

  final Curve curve;

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return _CurveSimulation(
      duration: duration,
      curve: curve,
      start: start,
      end: end,
      tolerance: tolerance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is DurationAndCurve) {
      return duration == other.duration && curve == other.curve;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(duration, curve);

  @override
  String toString() => 'DurationAndCurve(duration: $duration, curve: $curve)';
}

// Similar to _InterpolationSimulation from flutter's AnimationController
class _CurveSimulation extends Simulation {
  _CurveSimulation({
    required this.duration,
    required this.curve,
    required this.start,
    required this.end,
    required super.tolerance,
  });

  final Duration duration;

  final Curve curve;

  final double start;

  final double end;

  @override
  double x(double time) {
    final relativeTime = time / duration.toSeconds();

    if (relativeTime == 0) {
      return start;
    }

    if (relativeTime >= 1) {
      return end;
    }

    final t = curve.transform(relativeTime.clamp(0, 1));

    return start + (end - start) * t;
  }

  @override
  double dx(double time) {
    // Calculate the approximate derivative using a small delta
    final delta = tolerance.distance;
    final x1 = x(time - delta);
    final x2 = x(time + delta);

    // Return the rate of change (velocity)
    return (x2 - x1) / delta * 2;
  }

  @override
  bool isDone(double time) => time > duration.toSeconds();
}

@immutable
class Spring extends Motion {
  const Spring(this.spring);

  final SpringDescription spring;

  @override
  bool get needsSettle => true;
  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return SpringSimulation(
      spring,
      start,
      end,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is Spring) {
      return spring.damping == other.spring.damping &&
          spring.mass == other.spring.mass &&
          spring.stiffness == other.spring.stiffness;
    }
    return false;
  }

  @override
  int get hashCode => spring.hashCode;

  @override
  String toString() => 'Spring(spring: $spring)';
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
