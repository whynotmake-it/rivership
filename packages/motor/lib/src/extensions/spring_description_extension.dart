import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Extension methods for [SpringDescription].
extension SpringDescriptionExtension on SpringDescription {
  /// Creates a copy of this [SpringDescription] but with the given fields
  /// replaced by the non-null parameter values.
  SpringDescription copyWith({
    double? mass,
    double? stiffness,
    double? damping,
  }) {
    return SpringDescription(
      mass: mass ?? this.mass,
      stiffness: stiffness ?? this.stiffness,
      damping: damping ?? this.damping,
    );
  }

  /// Like [copyWith], but using [duration] and [bounce] instead of
  /// [mass], [stiffness], and [damping].
  SpringDescription copyWithDurationAndBounce({
    Duration? duration,
    double? bounce,
  }) {
    return SpringDescriptionExtension.withDurationAndBounce(
      duration: duration ?? this.duration,
      bounce: bounce ?? this.bounce,
    );
  }

  /// Polufill for the missing [SpringDescriptionExtension.withDurationAndBounce]
  /// in Flutter <3.32
  @internal
  static SpringDescription withDurationAndBounce({
    Duration duration = const Duration(milliseconds: 500),
    double bounce = 0.0,
  }) {
    assert(duration.inMilliseconds > 0, 'Duration must be positive');
    final durationInSeconds =
        duration.inMilliseconds / Duration.millisecondsPerSecond;
    const mass = 1.0;
    final stiffness =
        (4 * math.pi * math.pi * mass) / math.pow(durationInSeconds, 2);
    final dampingRatio = bounce > 0 ? (1.0 - bounce) : (1 / (bounce + 1));
    final damping = dampingRatio * 2.0 * math.sqrt(mass * stiffness);

    return SpringDescription(
        mass: mass, stiffness: stiffness, damping: damping);
  }

  /// Polufill for the missing [SpringDescriptionExtension.withDurationAndBounce]
  /// in Flutter <3.32
  @internal
  Duration get duration {
    final double durationInSeconds =
        math.sqrt((4 * math.pi * math.pi * mass) / stiffness);
    final int milliseconds =
        (durationInSeconds * Duration.millisecondsPerSecond).round();
    return Duration(milliseconds: milliseconds);
  }

  /// Polufill for the missing [SpringDescriptionExtension.withDurationAndBounce]
  /// in Flutter <3.32
  @internal
  double get bounce {
    final double dampingRatio = damping / (2.0 * math.sqrt(mass * stiffness));
    return dampingRatio < 1.0 ? (1.0 - dampingRatio) : ((1 / dampingRatio) - 1);
  }
}
