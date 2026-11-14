import 'package:flutter/widgets.dart';

/// The value range of a slider and how values snap onto it.
@immutable
class SliderScale {
  /// Creates a scale from [min] to [max] that snaps to [divisions] equal
  /// steps, to the values in [steps], or not at all.
  SliderScale({
    required this.min,
    required this.max,
    this.divisions,
    List<double>? steps,
  }) : steps = steps == null ? null : ({...steps}.toList()..sort());

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// The number of equal steps, or null.
  final int? divisions;

  /// The allowed values, sorted and without duplicates, or null.
  final List<double>? steps;

  /// Whether any value in the range is allowed.
  bool get continuous => divisions == null && steps == null;

  /// `max - min`.
  double get range => max - min;

  /// What one arrow key moves between steps that are evenly spaced: one
  /// division, or 1 % when continuous.
  double get step => range / (divisions ?? 100);

  /// What a page key moves: 10 %, never less than a step.
  double get page => range / 10 < step ? step : range / 10;

  /// [value] as a fraction of the range, 0 at [min].
  double norm(double value) => ((value - min) / range).clamp(0.0, 1.0);

  /// The fractions the allowed values sit at, or null when continuous.
  List<double>? get stops {
    if (steps case final steps?) return [for (final s in steps) norm(s)];
    final n = divisions;
    return n == null ? null : [for (var i = 0; i <= n; i++) i / n];
  }

  /// [value] limited to the range and put on the nearest allowed value. A
  /// value halfway between two steps goes to the lower one.
  double snap(double value) {
    final clamped = value.clamp(min, max);
    if (steps case final steps?) {
      var best = steps.first;
      for (final s in steps) {
        if ((s - clamped).abs() < (best - clamped).abs()) best = s;
      }
      return best;
    }
    final n = divisions;
    if (n == null) return clamped;
    final size = range / n;
    return (min + ((clamped - min) / size).round() * size).clamp(min, max);
  }

  /// The value [by] steps from [value], or [by] pages with [page]. With a
  /// step list an arrow walks the list, and a page moves at least one entry.
  double move(double value, int by, {bool page = false}) {
    final steps = this.steps;
    if (steps == null) {
      return snap(value + by * (page ? this.page : step));
    }
    final from = steps.indexOf(snap(value));
    var to = from + by;
    if (page) {
      to = steps.indexOf(snap(value + by * range / 10));
      if (to == from) to = from + by.sign;
    }
    return steps[to.clamp(0, steps.length - 1)];
  }

  /// The snapped value at [fraction] of the range.
  double valueAt(double fraction) => snap(min + fraction * range);
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
