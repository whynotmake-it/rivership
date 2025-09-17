import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Configuration for sheet snapping behavior.
///
/// Provides a type-safe way to define snapping points for sheets, preventing
/// mixing of relative and absolute positioning values. The 0 point (closed)
/// is always implicit.
@immutable
sealed class SheetSnappingConfig {
  const SheetSnappingConfig._();

  /// Creates a relative snapping configuration.
  ///
  /// Values are normalized between 0.0 and 1.0, where 0.0 is closed and 1.0
  /// is fully open. The 0.0 point is always implicit and doesn't need to be
  /// specified.
  ///
  /// Example:
  /// ```dart
  /// SheetSnappingConfig.relative({0.5, 1.0}) // Half and full height
  /// ```
  const factory SheetSnappingConfig.relative(
    List<double> points, {
    double? initialSnap,
  }) = RelativeSnappingConfig;

  /// Creates an absolute (pixel-based) snapping configuration.
  ///
  /// Values are in logical pixels from the bottom of the screen. The 0 point
  /// (closed) is always implicit and doesn't need to be specified.
  ///
  /// Example:
  /// ```dart
  /// SheetSnappingConfig.pixels({400.0, 800.0}) // 400px and 800px heights
  /// ```
  const factory SheetSnappingConfig.pixels(
    List<double> points, {
    double? initialSnap,
  }) = _AbsoluteSnappingConfig;

  /// The raw snapping points as provided to the constructor.
  List<double> get points;

  /// Resolves the snapping configuration to a [RelativeSnappingConfig]
  RelativeSnappingConfig resolve(double sheetHeight) {
    return switch (this) {
      final RelativeSnappingConfig r => r,
      final _AbsoluteSnappingConfig abs => abs._resolve(sheetHeight),
    };
  }

  /// Resolves the snapping configuration to a [RelativeSnappingConfig]
  RelativeSnappingConfig resolveWith(BuildContext context) {
    return resolve(MediaQuery.sizeOf(context).height);
  }

  double _findClosestPoint(List<double> points, double target) {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetSnappingConfig &&
          runtimeType == other.runtimeType &&
          listEquals(points, other.points);

  @override
  int get hashCode => Object.hashAll([runtimeType, ...points.toList()..sort()]);
}

/// A snapping configuration using relative values between 0.0 and 1.0.
class RelativeSnappingConfig extends SheetSnappingConfig {
  /// Creates a relative snapping configuration.
  const RelativeSnappingConfig(this.points, {double? initialSnap})
      : _initialSnap = initialSnap,
        super._();

  @override
  final List<double> points;

  final double? _initialSnap;

  /// Gets all snapping points including the implicit 0, resolved as relative
  /// values (0.0-1.0) for the given sheet height.
  List<double> getAllPoints() {
    final resolved = <double>{
      0.0, // Always include the implicit 0 point
      ...points,
    };

    return resolved.toList()..sort();
  }

  /// Gets the closest snapping point to the given relative position and
  /// velocity.
  double findTargetSnapPoint(
    double currentRelativePosition,
    double velocity,
    double sheetHeight,
  ) {
    final allPoints = getAllPoints();

    // For high velocity, predict where the sheet would naturally settle
    const velocityThreshold = 0.5;

    if (velocity.abs() > velocityThreshold) {
      // High velocity - predict the natural settling position
      final projectedPosition = currentRelativePosition - (velocity * 0.3);

      return _findClosestPoint(allPoints, projectedPosition);
    } else {
      // Low velocity - snap to the closest point based on current position
      return _findClosestPoint(allPoints, currentRelativePosition);
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

  /// Gets the minimum extent as a relative value.
  double get minExtent {
    final allPoints = getAllPoints();
    return allPoints.isNotEmpty ? allPoints.first : 0.0;
  }

  /// Whether this configuration has any in-between snap points
  /// (not just 0 and 1).
  bool get hasInbetweenSnaps {
    return points.any((p) => p < 1.0 && p > 0.0);
  }

  @override
  String toString() => 'SheetSnappingConfig.relative($points)';
}

class _AbsoluteSnappingConfig extends SheetSnappingConfig {
  const _AbsoluteSnappingConfig(this.points, {this.initialSnap}) : super._();

  @override
  final List<double> points;

  final double? initialSnap;

  RelativeSnappingConfig _resolve(double sheetHeight) {
    assert(sheetHeight > 0, 'Sheet height must be greater than zero.');
    final resolved = [
      for (final p in points) (p / sheetHeight).clamp(0.0, 1.0),
    ];
    return RelativeSnappingConfig(
      resolved,
      initialSnap: switch (initialSnap) {
        final p? => (p / sheetHeight).clamp(0.0, 1.0),
        null => null,
      },
    );
  }

  @override
  String toString() => 'SheetSnappingConfig.pixels($points)';
}
