import 'package:flutter/foundation.dart';

/// Represents a snapping point for sheet positioning.
@immutable
class SnappingPoint {
  /// Creates a relative snapping point (0.0-1.0).
  const SnappingPoint.relative(this.value) : isRelative = true;

  /// Creates a pixel-based snapping point.
  const SnappingPoint.pixels(this.value) : isRelative = false;

  /// The numerical value of the snapping point.
  final double value;

  /// Whether this point is relative (0-1) or pixel-based.
  final bool isRelative;

  /// Converts this snapping point to a relative value (0-1).
  double toRelative(double sheetHeight) {
    if (isRelative) return value.clamp(0, 1);
    return (value / sheetHeight).clamp(0, 1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnappingPoint &&
          value == other.value &&
          isRelative == other.isRelative;

  @override
  int get hashCode => value.hashCode ^ isRelative.hashCode;

  @override
  String toString() => isRelative ? 'relative($value)' : 'pixels($value)';
}
