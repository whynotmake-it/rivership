import 'package:flutter/widgets.dart';

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
    return SpringDescription.withDurationAndBounce(
      duration: duration ?? this.duration,
      bounce: bounce ?? this.bounce,
    );
  }
}
