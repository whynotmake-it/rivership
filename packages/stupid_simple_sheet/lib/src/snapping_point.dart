import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Configuration for sheet snapping behavior.
///
/// Values are normalized between 0.0 and 1.0, where 0.0 is closed and 1.0
/// is fully open. The 0.0 point is always implicit and doesn't need to be
/// specified.
///
/// Example:
/// ```dart
/// SheetSnappingConfig([0.5, 1.0]) // Half and full height
/// ```
@immutable
class SheetSnappingConfig {
  /// Creates a snapping configuration.
  ///
  /// Values are normalized between 0.0 and 1.0, where 0.0 is closed and 1.0
  /// is fully open. The 0.0 point is always implicit and doesn't need to be
  /// specified.
  const SheetSnappingConfig(
    this.points, {
    double? initialSnap,
    this.physics = const FlingSnapPhysics(),
  }) : _initialSnap = initialSnap;

  /// A snapping configuration that only includes the fully open state (1.0).
  static const SheetSnappingConfig full = SheetSnappingConfig([1.0]);

  /// The raw snapping points as provided to the constructor.
  final List<double> points;

  /// The physics model to use for finding the target snap point based on
  /// velocity and position.
  ///
  /// Defaults to [FlingSnapPhysics], which is a simple model that discerns
  /// between a fling and a drag and projects the fling to the next snap point
  /// in the direction of the fling.
  ///
  /// See also [FrictionSnapPhysics], which uses a [FrictionSimulation]
  /// to predict the natural settling point based on velocity and position,
  /// and can skip intermediate snap points if the fling is strong enough.
  final SnapPhysics physics;

  final double? _initialSnap;

  /// Gets all snapping points including the implicit 0, resolved as relative
  /// values (0.0-1.0) for the given sheet height.
  List<double> getAllPoints() {
    assert(points.isNotEmpty, 'At least one snap point must be provided');
    final resolved = <double>{
      0.0, // Always include the implicit 0 point
      ...points,
    };

    return resolved.toList()..sort();
  }

  /// Finds the closest snapping point to the given target position by distance
  /// alone, ignoring velocity.
  ///
  /// If you want to find the target snap point based on velocity and position,
  /// use [findTargetSnapPoint] instead.
  double findClosestSnapPoint(double target) {
    final allPoints = getAllPoints();
    return physics.findClosestPoint(allPoints, target);
  }

  /// Gets the closest snapping point to the given relative position and
  /// velocity.
  double findTargetSnapPoint({
    required double position,
    required double relativeVelocity,
    required double absoluteVelocity,
    bool includeClosed = true,
  }) {
    final allPoints = getAllPoints();

    // If the closed point (0.0) should be excluded, filter it out.
    final effectivePoints =
        includeClosed ? allPoints : allPoints.where((p) => p > 0.001).toList();

    switch (physics) {
      case final RelativeSnapPhysics p:
        return p.findTargetSnapPoint(
          position: position,
          velocity: relativeVelocity,
          snapPoints: effectivePoints,
        );
      case final AbsoluteSnapPhysics p:
        return p.findTargetSnapPoint(
          position: position,
          absoluteVelocity: absoluteVelocity,
          snapPoints: effectivePoints,
        );
    }
  }

  /// Gets the initial snap point as a relative value.
  ///
  /// If [initialSnap] is set, returns that point resolved to
  /// relative.
  /// Otherwise, returns the lowest non-zero snap point, or 1.0 as fallback.
  double get initialSnap {
    if (_initialSnap case final p?) {
      return p.clamp(0.0, 1.0);
    }

    final relativePoints = getAllPoints()
        .where((value) => value > 0.001) // Exclude values effectively zero
        .toList();

    return relativePoints.isNotEmpty ? relativePoints.first : 1.0;
  }

  /// Gets the top two snap points for transition calculations.
  (double, double) get topTwoPoints {
    final allPoints = getAllPoints();

    final lastPoint = allPoints.isNotEmpty ? allPoints.last : 1.0;
    final secondLastPoint =
        allPoints.length > 1 ? allPoints[allPoints.length - 2] : 0.0;

    return (secondLastPoint, lastPoint);
  }

  /// Gets the bottom two snap points for opacity range calculations.
  (double, double) get bottomTwoPoints {
    final allPoints = getAllPoints();

    final firstPoint = allPoints.isNotEmpty ? allPoints.first : 0.0;
    final secondPoint = allPoints.length > 1 ? allPoints[1] : 1.0;

    return (firstPoint, secondPoint);
  }

  /// Gets the maximum extent as a relative value.
  double get maxExtent {
    final allPoints = getAllPoints();
    return allPoints.isNotEmpty ? allPoints.last : 1.0;
  }

  /// Gets the minimum extent that is not 0.0 as a relative value.
  double get minExtent {
    assert(points.isNotEmpty, 'At least one snap point must be provided');
    return points.isNotEmpty ? points.first : 0.0;
  }

  /// Whether this configuration has any in-between snap points
  /// (not just 0 and 1).
  bool get hasInbetweenSnaps {
    return points.any((p) => p < 1.0 && p > 0.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetSnappingConfig &&
          runtimeType == other.runtimeType &&
          listEquals(points, other.points);

  @override
  int get hashCode => Object.hashAll([runtimeType, ...points.toList()..sort()]);

  @override
  String toString() => 'SheetSnappingConfig($points)';
}

/// Provides heuristics for finding a target snap point based on drag velocity
/// and position.
sealed class SnapPhysics {
  /// Creates a [SnapPhysics] instance.
  const SnapPhysics();

  /// Finds the closest snap point to the [target] position by distance alone.
  @protected
  double findClosestPoint(List<double> points, double target) {
    var minDistance = double.infinity;
    var closest = points.first;

    for (final point in points) {
      final distance = (target - point).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closest = point;
      }
    }

    return closest;
  }
}

/// A [SnapPhysics] implementation that needs the current sheet height to
/// calculate the target snap point based on absolute position and velocity.
abstract class AbsoluteSnapPhysics extends SnapPhysics {
  /// Creates an [AbsoluteSnapPhysics] instance.
  const AbsoluteSnapPhysics();

  /// Finds the target snap point based on the current position and velocity,
  /// using absolute values (e.g. pixels) rather than normalized values.
  double findTargetSnapPoint({
    required double position,
    required double absoluteVelocity,
    required List<double> snapPoints,
  });
}

/// A [SnapPhysics] implementation that calculates the target snap point based
/// on normalized position and velocity, without needing the current sheet
/// height.
abstract class RelativeSnapPhysics extends SnapPhysics {
  /// Creates a [RelativeSnapPhysics] instance.
  const RelativeSnapPhysics();

  /// Finds the target snap point based on the current position and velocity,
  /// using normalized values (0.0-1.0) rather than absolute values.
  double findTargetSnapPoint({
    required double position,
    required double velocity,
    required List<double> snapPoints,
  });
}

/// A simple [SnapPhysics] implementation that discerns between a fling and a
/// drag based on velocity, and if it's a fling, projects the position forward
/// to the next snap point in the direction of the fling.
///
/// Snapping points can never be overshot with a fling.
class FlingSnapPhysics extends AbsoluteSnapPhysics {
  /// Creates a [FlingSnapPhysics] instance a minimum fling velocity threshold.
  const FlingSnapPhysics({this.minFlingVelocity = kMinFlingVelocity});

  /// The minimum velocity that distinguishes a fling from a drag, in pixels per
  /// second.
  ///
  /// Defaults to [kMinFlingVelocity].
  final double minFlingVelocity;

  @override
  double findTargetSnapPoint({
    required double position,
    required double absoluteVelocity,
    required List<double> snapPoints,
  }) {
    final v = absoluteVelocity;

    // If velocity is below the fling threshold, snap to the closest point.
    if (v.abs() < minFlingVelocity) {
      return findClosestPoint(snapPoints, position);
    }

    // Otherwise, find the next snap point in the direction of the fling.
    if (v > 0) {
      // Flinging downwards, find the next snap point below the current
      // position.
      for (final point in snapPoints) {
        if (point > position) {
          return point;
        }
      }
    } else {
      // Flinging upwards, find the next snap point above the current position.
      for (final point in snapPoints.reversed) {
        if (point < position) {
          return point;
        }
      }
    }

    // If no snap point is found in the direction of the fling, snap to the
    // closest point.
    return findClosestPoint(snapPoints, position);
  }
}

/// A [SnapPhysics] implementation that uses a [FrictionSimulation] to predict
/// the natural settling point based on the current velocity and position, and
/// then finds the closest snap point to that projected position.
class FrictionSnapPhysics extends RelativeSnapPhysics {
  /// Creates a [FrictionSnapPhysics] with the given parameters.
  ///
  /// Default parameters are based on [BouncingScrollSimulation].
  const FrictionSnapPhysics({
    this.dragCoefficient = 0.135,
    this.constantDeceleration = 0.0,
  });

  /// The fluid drag coefficient, a unitless value.
  ///
  /// See also [FrictionSimulation] for more details on how this value affects
  /// the simulation.
  final double dragCoefficient;

  /// The constant deceleration to apply, in the same units as the position.
  ///
  /// This can be used to model additional friction or resistance that isn't
  /// captured by the drag coefficient alone. F
  ///
  /// See also [FrictionSimulation] for more details on how this value affects
  /// the simulation.
  final double constantDeceleration;

  @override
  double findTargetSnapPoint({
    required double position,
    required double velocity,
    required List<double> snapPoints,
  }) {
    final currentRelativePosition = position.clamp(0.0, 1.0);
    final sim = FrictionSimulation(
      dragCoefficient,
      currentRelativePosition,
      velocity,
      constantDeceleration: constantDeceleration,
    );

    final projectedPosition = sim.finalX.clamp(0.0, 1.0);

    return findClosestPoint(snapPoints, projectedPosition);
  }
}
