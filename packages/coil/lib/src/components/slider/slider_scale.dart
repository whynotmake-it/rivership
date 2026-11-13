import 'package:flutter/widgets.dart';

/// The value range of a slider and how values snap onto it.
@immutable
class SliderScale {
  /// Creates a scale from [min] to [max] with [divisions] equal steps.
  const SliderScale({required this.min, required this.max, this.divisions});

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// The number of equal steps, or null for a continuous range.
  final int? divisions;

  /// `max - min`.
  double get range => max - min;

  /// What one arrow key moves: one division, or 1 % when continuous.
  double get step => range / (divisions ?? 100);

  /// What a page key moves: 10 %, never less than a step.
  double get page => range / 10 < step ? step : range / 10;

  /// [value] as a fraction of the range, 0 at [min].
  double norm(double value) => ((value - min) / range).clamp(0.0, 1.0);

  /// [value] limited to the range and put on the nearest division.
  double snap(double value) {
    final clamped = value.clamp(min, max);
    final n = divisions;
    if (n == null) return clamped;
    final size = range / n;
    return (min + ((clamped - min) / size).round() * size).clamp(min, max);
  }

  /// The snapped value at [fraction] of the range.
  double valueAt(double fraction) => snap(min + fraction * range);

  /// The value at [fraction] of the range, not snapped.
  double rawAt(double fraction) => min + fraction * range;
}

/// How far the thumb's travel is inset from the ends of a track box, and the
/// maps between a fraction of the range and an x in the box.
@immutable
class SliderReach {
  /// Creates a reach with the same [inset] at both ends.
  const SliderReach(this.inset);

  /// The distance from either end of the box to the 0 and 1 positions.
  final double inset;

  @override
  bool operator ==(Object other) =>
      other is SliderReach && other.inset == inset;

  @override
  int get hashCode => inset.hashCode;

  /// The x of [fraction] in a box [width] wide.
  double xAt(double fraction, double width, {required bool rtl}) {
    final end = width - inset;
    final x = inset + (end - inset).clamp(0, double.infinity) * fraction;
    return rtl ? width - x : x;
  }

  /// The fraction of the range at [dx] in a box [width] wide.
  double fractionAt(double dx, double width, {required bool rtl}) {
    final x = rtl ? width - dx : dx;
    final span = width - inset * 2;
    return span <= 0 ? 0 : ((x - inset) / span).clamp(0.0, 1.0);
  }
}
