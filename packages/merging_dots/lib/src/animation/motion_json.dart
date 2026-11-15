import 'package:flutter/animation.dart';
import 'package:motor/motor.dart';

/// Converts the motions an exported dot animation can use to and from JSON.
///
/// Springs are stored as a [CupertinoMotion] duration and bounce, curves as
/// a duration and one of the names in [curves]. Other motions can't be
/// stored and [toJson] returns null for them.
abstract final class MotionJson {
  /// The curves that can be stored, by name.
  static const Map<String, Curve> curves = {
    'linear': Curves.linear,
    'ease': Curves.ease,
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'easeInCubic': Curves.easeInCubic,
    'easeOutCubic': Curves.easeOutCubic,
    'easeInOutCubic': Curves.easeInOutCubic,
    'easeInBack': Curves.easeInBack,
    'easeOutBack': Curves.easeOutBack,
    'easeInOutBack': Curves.easeInOutBack,
    'fastOutSlowIn': Curves.fastOutSlowIn,
    'elasticOut': Curves.elasticOut,
    'bounceOut': Curves.bounceOut,
  };

  /// The name of [curve] in [curves], or null.
  static String? curveName(Curve curve) {
    for (final entry in curves.entries) {
      if (entry.value == curve) return entry.key;
    }
    return null;
  }

  /// [motion] as JSON, or null if it can't be stored.
  static Map<String, Object?>? toJson(Motion motion) {
    switch (motion) {
      case CupertinoMotion(:final duration, :final bounce):
        return {
          'type': 'spring',
          'ms': duration.inMilliseconds,
          'bounce': bounce,
        };
      case CurvedMotion(:final duration, :final curve):
        final name = curveName(curve);
        if (name == null) return null;
        return {'type': 'curve', 'ms': duration.inMilliseconds, 'curve': name};
      default:
        return null;
    }
  }

  /// Reads a motion written by [toJson].
  static Motion fromJson(Map<String, Object?> json) {
    final duration = Duration(
      milliseconds: (json['ms'] as num? ?? 500).round(),
    );
    return switch (json['type']) {
      'curve' => CurvedMotion(duration, curves[json['curve']] ?? Curves.linear),
      _ => CupertinoMotion(
        duration: duration,
        bounce: (json['bounce'] as num? ?? 0).toDouble(),
      ),
    };
  }
}
