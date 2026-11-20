import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// A [LinearGradient] from [from] to [to] whose color follows [curve]
/// instead of a straight line, so a fade has no visible edge where it
/// starts or ends. The ramp runs between the stops [start] and [end], and
/// [steps] samples of the curve approximate it.
///
/// Internal to coil; not exported.
LinearGradient easedGradient({
  required Alignment begin,
  required Alignment end,
  required Color from,
  required Color to,
  double start = 0,
  double stop = 1,
  Curve curve = Curves.easeInOut,
  int steps = 12,
}) {
  final (colors, stops) = easedRamp(
    from: from,
    to: to,
    start: start,
    stop: stop,
    curve: curve,
    steps: steps,
  );
  return LinearGradient(begin: begin, end: end, colors: colors, stops: stops);
}

/// The colors and stops of an eased ramp from [from] at [start] to [to] at
/// [stop], for composing several ramps into one gradient.
(List<Color>, List<double>) easedRamp({
  required Color from,
  required Color to,
  required double start,
  required double stop,
  Curve curve = Curves.easeInOut,
  int steps = 12,
}) {
  final colors = <Color>[];
  final stops = <double>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    colors.add(Color.lerp(from, to, curve.transform(t))!);
    stops.add(start + (stop - start) * t);
  }
  return (colors, stops);
}
