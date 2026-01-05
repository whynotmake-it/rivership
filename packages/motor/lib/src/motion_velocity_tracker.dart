import 'package:flutter/gestures.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion_converter.dart';

typedef _PointAtTime = (List<double> point, Duration time);

/// Controls velocity tracking behavior in a [MotionController].
///
/// Velocity tracking is enabled by default. Use [VelocityTracking.off] to
/// disable it, or [VelocityTracking.on] with a custom builder for advanced use.
sealed class VelocityTracking {
  const VelocityTracking();

  /// Enables velocity tracking with an optional custom builder.
  ///
  /// If [velocityTrackerBuilder] is not provided, a default
  /// [MotionVelocityTracker] is created, which is based on the Flutter
  /// [IOSScrollViewFlingVelocityTracker].
  const factory VelocityTracking.on({
    MotionVelocityTracker<T> Function<T>(MotionConverter<T> converter)?
        velocityTrackerBuilder,
  }) = _VelocityTrackingOn;

  /// Disables velocity tracking.
  const factory VelocityTracking.off() = _VelocityTrackingOff;

  /// Creates a [MotionVelocityTracker] for the given [converter], or `null`
  MotionVelocityTracker<T>? call<T>(MotionConverter<T> converter);
}

class _VelocityTrackingOn extends VelocityTracking {
  const _VelocityTrackingOn({
    this.velocityTrackerBuilder,
  });

  final MotionVelocityTracker<T> Function<T>(MotionConverter<T> converter)?
      velocityTrackerBuilder;

  @override
  MotionVelocityTracker<T>? call<T>(MotionConverter<T> converter) {
    if (velocityTrackerBuilder != null) {
      return velocityTrackerBuilder!(converter);
    }

    return MotionVelocityTracker<T>(converter);
  }
}

class _VelocityTrackingOff extends VelocityTracking {
  const _VelocityTrackingOff();

  @override
  MotionVelocityTracker<T>? call<T>(MotionConverter<T> converter) {
    return null;
  }
}

/// Tracks velocity for values of type [T] during user interactions.
///
/// Use this with [MotionController] to automatically estimate velocity from
/// manual value changes. When the user interacts with UI elements (like
/// dragging), setting controller values tracks position over time. When the
/// interaction ends, the tracked velocity provides smooth motion continuity.
///
/// Based on [IOSScrollViewFlingVelocityTracker] from Flutter, adapted for
/// generic types via [MotionConverter].
///
/// Example:
/// ```dart
/// final controller = MotionController(
///   motion: CupertinoMotion.bouncy(),
///   vsync: this,
///   converter: MotionConverter.offset,
///   initialValue: Offset.zero,
///   // Enabled by default, or use VelocityTracking.off() to disable
/// );
/// ```
class MotionVelocityTracker<T> {
  /// Creates a motion velocity tracker with the given [converter].
  MotionVelocityTracker(this.converter);

  /// The converter used to normalize and denormalize values.
  final MotionConverter<T> converter;

  static const int _assumePointerMoveStoppedMilliseconds = 40;
  static const int _sampleSize = 20;

  final List<_PointAtTime?> _touchSamples =
      List<_PointAtTime?>.filled(_sampleSize, null);
  int _index = 0;

  Stopwatch? _stopwatch;

  Stopwatch get _sinceLastSample {
    _stopwatch ??= Stopwatch()..start();
    return _stopwatch!;
  }

  /// Adds a position sample at the given [time].
  ///
  /// Call this each time the value changes during user interaction.
  /// The tracker stores up to 20 samples in a circular buffer.
  void addPosition(Duration time, T value) {
    _sinceLastSample
      ..start()
      ..reset();

    _index = (_index + 1) % _sampleSize;
    _touchSamples[_index] = (converter.normalize(value), time);
  }

  // Computes the velocity using 2 adjacent points in history.
  List<double>? _previousVelocityAt(int index) {
    final endIndex = (_index + index) % _sampleSize;
    final startIndex = (_index + index - 1) % _sampleSize;
    final end = _touchSamples[endIndex];
    final start = _touchSamples[startIndex];

    if (end == null || start == null) {
      return null;
    }

    final dt = (end.$2 - start.$2).inMicroseconds;
    if (dt <= 0) {
      return List.filled(end.$1.length, 0.0);
    }

    final dtMs = dt.toDouble() / 1000.0;

    // (end - start) * 1000 / dtMs
    return List.generate(end.$1.length, (i) {
      return (end.$1[i] - start.$1[i]) * 1000 / dtMs;
    });
  }

  /// Returns a velocity estimate based on recent position samples.
  ///
  /// Returns `null` if no samples have been recorded. Returns zero velocity
  /// with confidence 1.0 if movement stopped more than 40ms ago. Uses weighted
  /// average of recent samples (0.6, 0.35, 0.05) for stability.
  MotionVelocityEstimate<T>? getVelocityEstimate() {
    final newestSample = _touchSamples[_index];
    if (newestSample == null) return null;

    final dims = newestSample.$1.length;

    if (_sinceLastSample.elapsedMilliseconds >
        _assumePointerMoveStoppedMilliseconds) {
      final zeroT = converter.denormalize(List.filled(dims, 0.0));
      return MotionVelocityEstimate<T>(
        perSecond: zeroT,
        confidence: 1.0,
        duration: Duration.zero,
        offset: zeroT,
      );
    }

    final v2 = _previousVelocityAt(-2);
    final v1 = _previousVelocityAt(-1);
    final v0 = _previousVelocityAt(0);

    final estimatedVelocityValues = List<double>.filled(dims, 0.0);

    void addWeighted(List<double>? v, double weight) {
      if (v != null && v.length == dims) {
        for (var i = 0; i < dims; i++) {
          estimatedVelocityValues[i] += v[i] * weight;
        }
      }
    }

    addWeighted(v2, 0.6);
    addWeighted(v1, 0.35);
    addWeighted(v0, 0.05);

    _PointAtTime? oldestNonNullSample;
    for (var i = 1; i <= _sampleSize; i += 1) {
      oldestNonNullSample = _touchSamples[(_index + i) % _sampleSize];
      if (oldestNonNullSample != null) {
        break;
      }
    }

    if (oldestNonNullSample == null) {
      final zeroT = converter.denormalize(List.filled(dims, 0.0));
      return MotionVelocityEstimate<T>(
        perSecond: zeroT,
        confidence: 0.0,
        duration: Duration.zero,
        offset: zeroT,
      );
    }

    // Offset
    final offsetValues = List.generate(dims, (i) {
      return newestSample.$1[i] - oldestNonNullSample!.$1[i];
    });

    return MotionVelocityEstimate<T>(
      perSecond: converter.denormalize(estimatedVelocityValues),
      confidence: 1.0,
      duration: newestSample.$2 - oldestNonNullSample.$2,
      offset: converter.denormalize(offsetValues),
    );
  }
}

/// A velocity estimate with confidence metrics.
class MotionVelocityEstimate<T> {
  /// Creates a velocity estimate.
  const MotionVelocityEstimate({
    required this.perSecond,
    required this.confidence,
    required this.duration,
    required this.offset,
  });

  /// The estimated rate of change per second.
  final T perSecond;

  /// Confidence in the estimate (0.0 to 1.0).
  ///
  /// Returns 0.0 if insufficient data, 1.0 otherwise.
  final double confidence;

  /// The time that elapsed between the first and last position sample.
  final Duration duration;

  /// The difference between the first and last position sample.
  final T offset;

  @override
  String toString() => 'MotionVelocityEstimate($perSecond; offset: $offset, '
      'duration: $duration, confidence: ${confidence.toStringAsFixed(1)})';
}
