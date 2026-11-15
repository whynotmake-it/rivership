import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Delays each dot's transition by where it is, so a change sweeps across
/// the dots instead of happening everywhere at once.
///
/// Every stagger maps a dot to a number from `0` to `1`, which is scaled by
/// [duration]: the first dot starts right away, the last one [duration]
/// later. All dots share one motion, so a staggered transition costs no
/// more than a simultaneous one.
@immutable
sealed class DotStagger {
  const DotStagger({required this.duration});

  /// No stagger, every dot moves at once.
  const factory DotStagger.none() = NoDotStagger;

  /// A sweep in a straight line along [angle], in radians.
  ///
  /// An angle of `0` sweeps from left to right, `pi / 2` from top to bottom.
  const factory DotStagger.directional({
    required Duration duration,
    double angle,
  }) = DirectionalDotStagger;

  /// A ripple outwards from [center], or inwards when [inward] is true.
  const factory DotStagger.radial({
    required Duration duration,
    Alignment center,
    bool inward,
  }) = RadialDotStagger;

  /// Dots start in the order they are listed: row by row on a grid, by
  /// index in a cloud. Use it to chase dots around a spinner.
  const factory DotStagger.ordered({
    required Duration duration,
    bool reverse,
  }) = OrderedDotStagger;

  /// A random but repeatable delay per dot.
  const factory DotStagger.random({
    required Duration duration,
    int seed,
  }) = RandomDotStagger;

  /// Reads a stagger written by [toJson].
  factory DotStagger.fromJson(Map<String, Object?> json) {
    final duration = Duration(milliseconds: (json['ms'] as num? ?? 0).round());
    return switch (json['type']) {
      'directional' => DotStagger.directional(
        duration: duration,
        angle: (json['angle'] as num? ?? 0).toDouble(),
      ),
      'radial' => DotStagger.radial(
        duration: duration,
        center: Alignment(
          (json['x'] as num? ?? 0).toDouble(),
          (json['y'] as num? ?? 0).toDouble(),
        ),
        inward: json['inward'] as bool? ?? false,
      ),
      'ordered' => DotStagger.ordered(
        duration: duration,
        reverse: json['reverse'] as bool? ?? false,
      ),
      'random' => DotStagger.random(
        duration: duration,
        seed: json['seed'] as int? ?? 0,
      ),
      _ => const DotStagger.none(),
    };
  }

  /// How much later the last dot starts than the first.
  final Duration duration;

  /// Computes each dot's delay, from `0` to `1`, into [out].
  ///
  /// [position] returns a dot's position normalized to `0..1`.
  void computeDelays(
    List<double> out,
    int count,
    Offset Function(int index) position,
  );

  /// A JSON representation, read by [DotStagger.fromJson].
  Map<String, Object?> toJson();
}

/// See [DotStagger.none].
final class NoDotStagger extends DotStagger {
  /// See [DotStagger.none].
  const NoDotStagger() : super(duration: Duration.zero);

  @override
  void computeDelays(
    List<double> out,
    int count,
    Offset Function(int) position,
  ) {
    out.fillRange(0, count, 0);
  }

  @override
  Map<String, Object?> toJson() => {'type': 'none'};

  @override
  bool operator ==(Object other) => other is NoDotStagger;

  @override
  int get hashCode => (NoDotStagger).hashCode;
}

/// See [DotStagger.directional].
final class DirectionalDotStagger extends DotStagger {
  /// See [DotStagger.directional].
  const DirectionalDotStagger({required super.duration, this.angle = 0});

  /// The direction of the sweep, in radians.
  final double angle;

  @override
  void computeDelays(
    List<double> out,
    int count,
    Offset Function(int) position,
  ) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var i = 0; i < count; i++) {
      final p = position(i);
      final v = p.dx * dx + p.dy * dy;
      out[i] = v;
      min = math.min(min, v);
      max = math.max(max, v);
    }
    _normalize(out, count, min, max);
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'directional',
    'ms': duration.inMilliseconds,
    'angle': angle,
  };

  @override
  bool operator ==(Object other) =>
      other is DirectionalDotStagger &&
      other.duration == duration &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(duration, angle);
}

/// See [DotStagger.radial].
final class RadialDotStagger extends DotStagger {
  /// See [DotStagger.radial].
  const RadialDotStagger({
    required super.duration,
    this.center = Alignment.center,
    this.inward = false,
  });

  /// Where the ripple starts, or ends when [inward].
  final Alignment center;

  /// Whether the ripple runs towards [center].
  final bool inward;

  @override
  void computeDelays(
    List<double> out,
    int count,
    Offset Function(int) position,
  ) {
    final c = Offset((center.x + 1) / 2, (center.y + 1) / 2);
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var i = 0; i < count; i++) {
      final v = (position(i) - c).distance * (inward ? -1 : 1);
      out[i] = v;
      min = math.min(min, v);
      max = math.max(max, v);
    }
    _normalize(out, count, min, max);
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'radial',
    'ms': duration.inMilliseconds,
    'x': center.x,
    'y': center.y,
    if (inward) 'inward': true,
  };

  @override
  bool operator ==(Object other) =>
      other is RadialDotStagger &&
      other.duration == duration &&
      other.center == center &&
      other.inward == inward;

  @override
  int get hashCode => Object.hash(duration, center, inward);
}

/// See [DotStagger.ordered].
final class OrderedDotStagger extends DotStagger {
  /// See [DotStagger.ordered].
  const OrderedDotStagger({required super.duration, this.reverse = false});

  /// Whether the last dot starts first.
  final bool reverse;

  @override
  void computeDelays(
    List<double> out,
    int count,
    Offset Function(int) position,
  ) {
    for (var i = 0; i < count; i++) {
      final v = count == 1 ? 0.0 : i / (count - 1);
      out[i] = reverse ? 1 - v : v;
    }
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'ordered',
    'ms': duration.inMilliseconds,
    if (reverse) 'reverse': true,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderedDotStagger &&
      other.duration == duration &&
      other.reverse == reverse;

  @override
  int get hashCode => Object.hash(duration, reverse);
}

/// See [DotStagger.random].
final class RandomDotStagger extends DotStagger {
  /// See [DotStagger.random].
  const RandomDotStagger({required super.duration, this.seed = 0});

  /// The seed of the random delays. The same seed gives the same delays.
  final int seed;

  @override
  void computeDelays(
    List<double> out,
    int count,
    Offset Function(int) position,
  ) {
    final random = math.Random(seed);
    for (var i = 0; i < count; i++) {
      out[i] = random.nextDouble();
    }
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'random',
    'ms': duration.inMilliseconds,
    'seed': seed,
  };

  @override
  bool operator ==(Object other) =>
      other is RandomDotStagger &&
      other.duration == duration &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(duration, seed);
}

void _normalize(List<double> out, int count, double min, double max) {
  final range = max - min;
  for (var i = 0; i < count; i++) {
    out[i] = range < 1e-9 ? 0 : (out[i] - min) / range;
  }
}
