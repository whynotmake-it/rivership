import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/src/sheet_constants.dart';

/// Context available to a [SheetDetent] while resolving its height.
///
/// [maxHeight] is the largest height the presentation can occupy in logical
/// pixels. [screenSize] and [safeAreaInsets] describe the surrounding
/// environment, so custom detents can adapt without reading [MediaQuery]
/// themselves.
@immutable
class SheetDetentContext {
  /// Creates a detent resolution context.
  const SheetDetentContext({
    required this.maxHeight,
    required this.screenSize,
    this.safeAreaInsets = EdgeInsets.zero,
  });

  /// The maximum height available to the sheet presentation.
  final double maxHeight;

  /// The size of the screen containing the presentation.
  final Size screenSize;

  /// Safe-area padding already applied around the presentation area.
  final EdgeInsets safeAreaInsets;
}

/// Resolves a custom detent to a height in logical pixels.
///
/// Return `null` to omit the detent in the current [SheetDetentContext].
typedef SheetDetentResolver = double? Function(SheetDetentContext context);

/// A height where a sheet naturally rests.
///
/// Mirrors SwiftUI's `PresentationDetent`: use [SheetDetent.medium] or
/// [SheetDetent.large] for the system sizes, or create a fixed, fractional, or
/// contextual height with [SheetDetent.height], [SheetDetent.fraction], and
/// [SheetDetent.custom].
@immutable
final class SheetDetent {
  const SheetDetent._({
    double? fraction,
    double? height,
    SheetDetentResolver? resolver,
  })  : _fraction = fraction,
        _height = height,
        _resolver = resolver;

  /// Creates a detent at [fraction] of the presentation's maximum height.
  const factory SheetDetent.fraction(double fraction) = _FractionSheetDetent;

  /// Creates a detent at a fixed [height] in logical pixels.
  const factory SheetDetent.height(double height) = _HeightSheetDetent;

  /// Creates a detent calculated from the presentation context.
  ///
  /// Return `null` from [resolver] to omit this detent in that context.
  const factory SheetDetent.custom(SheetDetentResolver resolver) =
      _CustomSheetDetent;

  /// The system detent for a sheet at approximately half height.
  static const medium = SheetDetent.fraction(0.5);

  /// The system detent for a sheet at full height.
  static const large = SheetDetent.fraction(1);

  final double? _fraction;
  final double? _height;
  final SheetDetentResolver? _resolver;

  /// Resolves this detent to a relative position in `0.0...1.0`.
  ///
  /// Returns `null` when a custom resolver omits the detent.
  @internal
  double? resolve(SheetDetentContext context) {
    final height = switch ((_fraction, _height, _resolver)) {
      (final fraction?, null, null) => context.maxHeight * fraction,
      (null, final height?, null) => height,
      (null, null, final resolver?) => resolver(context),
      _ => null,
    };
    if (height == null ||
        !height.isFinite ||
        height <= 0 ||
        context.maxHeight <= 0 ||
        !context.maxHeight.isFinite) {
      return null;
    }
    return (height / context.maxHeight).clamp(0.0, 1.0);
  }

  /// Whether this detent can describe a height below the largest detent.
  bool get _isPossiblyInbetween => switch ((_fraction, _height, _resolver)) {
        (final fraction?, null, null) => fraction > 0 && fraction < 1,
        (null, final height?, null) => height > 0,
        (null, null, _?) => true,
        _ => false,
      };

  @override
  bool operator ==(Object other) =>
      other is SheetDetent &&
      other._fraction == _fraction &&
      other._height == _height &&
      other._resolver == _resolver;

  @override
  int get hashCode => Object.hash(_fraction, _height, _resolver);

  @override
  String toString() => switch ((_fraction, _height, _resolver)) {
        (final fraction?, null, null) => 'SheetDetent.fraction($fraction)',
        (null, final height?, null) => 'SheetDetent.height($height)',
        _ => 'SheetDetent.custom()',
      };
}

final class _FractionSheetDetent extends SheetDetent {
  const _FractionSheetDetent(double fraction)
      : assert(
          fraction > 0 && fraction <= 1,
          'Fraction detents must be greater than 0 and at most 1.',
        ),
        super._(fraction: fraction);
}

final class _HeightSheetDetent extends SheetDetent {
  const _HeightSheetDetent(double height)
      : assert(height > 0, 'Height detents must be greater than 0.'),
        super._(height: height);
}

final class _CustomSheetDetent extends SheetDetent {
  const _CustomSheetDetent(SheetDetentResolver resolver)
      : super._(resolver: resolver);
}

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
  })  : detents = null,
        _initialSnap = initialSnap,
        _initialDetent = null;

  /// Creates a snapping configuration from SwiftUI-style [SheetDetent]s.
  ///
  /// Heights are resolved against the presentation's maximum extent, so
  /// `SheetDetent.height(240)` remains 240 logical pixels on devices with
  /// different screen sizes.
  // The parameter stays non-nullable while the backing field remains nullable
  // to distinguish relative points from detents.
  const SheetSnappingConfig.detents(
    List<SheetDetent> detents, {
    SheetDetent? initialSnap,
    this.physics = const FlingSnapPhysics(),
  })  :
        // ignore: prefer_initializing_formals
        detents = detents,
        points = const [],
        _initialSnap = null,
        _initialDetent = initialSnap;

  /// A snapping configuration that only includes the fully open state (1.0).
  static const SheetSnappingConfig full = SheetSnappingConfig([1.0]);

  /// The raw relative snapping points as provided to the constructor.
  ///
  /// Empty when this configuration was created with [SheetDetent]s; call
  /// [resolve] with a [SheetDetentContext] before using the points.
  final List<double> points;

  /// The SwiftUI-style detents backing this configuration, if any.
  final List<SheetDetent>? detents;

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
  final SheetDetent? _initialDetent;

  /// Resolves [SheetDetent]s to relative snapping points in [context].
  ///
  /// Configurations created from relative `points` are returned unchanged.
  /// Custom detents that return `null` are omitted.
  SheetSnappingConfig resolve(SheetDetentContext context) {
    final detents = this.detents;
    if (detents == null) return this;

    final resolvedPoints = [
      for (final detent in detents)
        if (detent.resolve(context) case final point?) point,
    ]..sort();
    if (resolvedPoints.isEmpty) resolvedPoints.add(1);
    final initialSnap = _initialDetent?.resolve(context) ?? _initialSnap;
    return SheetSnappingConfig(
      resolvedPoints,
      initialSnap: initialSnap,
      physics: physics,
    );
  }

  /// Gets all snapping points including the implicit 0, resolved as relative
  /// values (0.0-1.0) for the given sheet height.
  ///
  /// Configurations created with [SheetDetent]s must be [resolve]d first.
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
    final effectivePoints = includeClosed
        ? allPoints
        : allPoints.where((p) => p > sheetPositionTolerance).toList();

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
        .where(
          (value) => value > sheetPositionTolerance,
        ) // Exclude values effectively zero
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
    final detents = this.detents;
    if (detents != null) {
      return detents.any((detent) => detent._isPossiblyInbetween);
    }
    return points.any((p) => p < 1.0 && p > 0.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetSnappingConfig &&
          runtimeType == other.runtimeType &&
          listEquals(points, other.points) &&
          listEquals(detents, other.detents);

  @override
  int get hashCode =>
      Object.hashAll([runtimeType, ...points.toList()..sort(), ...?detents]);

  @override
  String toString() => 'SheetSnappingConfig(${detents ?? points})';
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

/// Restores the snap-point behavior used before `1.0.0-dev.1`.
///
/// This physics treats velocities below `0.5` normalized units as a regular
/// drag. Faster gestures project the current position by `velocity * 0.3` and
/// settle on the closest snap point. The velocity is normalized so positive
/// values move the sheet towards its open state.
///
/// This behavior is retained for migrations where changing the snap response
/// would be undesirable. New sheets should use [FlingSnapPhysics] or
/// [FrictionSnapPhysics] instead.
@Deprecated(
  'Use FlingSnapPhysics or FrictionSnapPhysics instead. '
  'This behavior is retained for migration compatibility.',
)
class LegacySnapPhysics extends RelativeSnapPhysics {
  /// Creates legacy snap physics.
  @Deprecated(
    'Use FlingSnapPhysics or FrictionSnapPhysics instead. '
    'This behavior is retained for migration compatibility.',
  )
  const LegacySnapPhysics();

  @override
  double findTargetSnapPoint({
    required double position,
    required double velocity,
    required List<double> snapPoints,
  }) {
    if (velocity.abs() <= 0.5) {
      return findClosestPoint(snapPoints, position);
    }

    final projectedPosition = position + velocity * 0.3;
    return findClosestPoint(snapPoints, projectedPosition);
  }
}
