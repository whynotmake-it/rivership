import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion_converter.dart';

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
  /// when tracking is off.
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

    return MotionVelocityTracker<T>._builtIn(converter);
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
///   motion: .bouncySpring(),
///   vsync: this,
///   converter: .offset,
///   initialValue: Offset.zero,
///   // Enabled by default, or use VelocityTracking.off() to disable
/// );
/// ```
class MotionVelocityTracker<T> {
  /// Creates a motion velocity tracker with the given [converter].
  MotionVelocityTracker(this.converter) : _builtIn = false;

  MotionVelocityTracker._builtIn(this.converter) : _builtIn = true;

  // Whether this is the tracker motor creates by default, which is not a
  // subclass, so samples can skip the overridable addPosition.
  final bool _builtIn;

  /// The converter used to normalize and denormalize values.
  final MotionConverter<T> converter;

  static const int _assumePointerMoveStoppedMilliseconds = 40;
  static const int _sampleSize = 20;

  // The most recent samples in a ring: slot `i` holds its position's
  // dimensions at `_positions[i * _dimensions ...]` and its time in
  // microseconds at `_times[i]`. [_index] is the newest slot, and the
  // [_count] slots up to it are filled.
  Float64List? _positions;
  // A plain list: JavaScript builds don't support Int64List.
  final List<int> _times = List<int>.filled(_sampleSize, 0);
  int _dimensions = 0;
  int _index = 0;
  int _count = 0;

  /// Wall-clock instant of the most recent sample, in microseconds since the
  /// epoch, sourced from [clock] so the "pointer stopped" detection is driven
  /// by the fake clock under test and by real time in production.
  int? _lastSampleAtMicros;

  /// Adds a position sample at the given [time].
  ///
  /// Call this each time the value changes during user interaction.
  /// The tracker stores up to 20 samples in a circular buffer.
  void addPosition(Duration time, T value) =>
      _add(time.inMicroseconds, value, clock.now());

  /// Adds a position sample taken at the wall-clock instant [now], which
  /// also serves as its time. Subclasses get it through [addPosition].
  @internal
  void addPositionAt(DateTime now, T value) {
    if (_builtIn) {
      _add(now.microsecondsSinceEpoch, value, now);
    } else {
      addPosition(Duration(microseconds: now.microsecondsSinceEpoch), value);
    }
  }

  void _add(int timeMicros, T value, DateTime now) {
    _lastSampleAtMicros = now.microsecondsSinceEpoch;
    final point = converter.normalize(value);
    var positions = _positions;
    if (positions == null || point.length != _dimensions) {
      _dimensions = point.length;
      positions = _positions = Float64List(_sampleSize * _dimensions);
      _count = 0;
    }
    _index = (_index + 1) % _sampleSize;
    final base = _index * _dimensions;
    for (var i = 0; i < _dimensions; i++) {
      positions[base + i] = point[i];
    }
    _times[_index] = timeMicros;
    if (_count < _sampleSize) _count++;
  }

  /// The slot [offset] samples before the newest (0 is the newest), or null
  /// if that sample has not been recorded.
  int? _slotAt(int offset) =>
      offset < _count ? (_index - offset) % _sampleSize : null;

  // Adds `weight` times the velocity between the sample `offset` before the
  // newest and the one before it, if both exist, to `into`.
  void _addVelocity(List<double> into, int offset, double weight) {
    final end = _slotAt(offset);
    final start = _slotAt(offset + 1);
    if (end == null || start == null) return;
    final dt = _times[end] - _times[start];
    if (dt <= 0) return;
    final dtMs = dt.toDouble() / 1000.0;
    final positions = _positions!;
    for (var i = 0; i < _dimensions; i++) {
      final delta =
          positions[end * _dimensions + i] - positions[start * _dimensions + i];
      into[i] += delta * 1000 / dtMs * weight;
    }
  }

  /// Returns a velocity estimate based on recent position samples.
  ///
  /// Returns `null` if no samples have been recorded. Returns zero velocity
  /// if movement stopped more than 40ms ago. Uses weighted
  /// average of recent samples (0.6, 0.35, 0.05) for stability.
  MotionVelocityEstimate<T>? getVelocityEstimate() {
    if (_count == 0) return null;
    final dims = _dimensions;

    final lastSampleAt = _lastSampleAtMicros;
    if (lastSampleAt != null &&
        (clock.now().microsecondsSinceEpoch - lastSampleAt) ~/ 1000 >
            _assumePointerMoveStoppedMilliseconds) {
      final zeroT = converter.denormalize(List.filled(dims, 0.0));
      return MotionVelocityEstimate<T>(
        perSecond: zeroT,
        duration: Duration.zero,
        offset: zeroT,
      );
    }

    final estimatedVelocityValues = List<double>.filled(dims, 0.0);
    _addVelocity(estimatedVelocityValues, 2, 0.6);
    _addVelocity(estimatedVelocityValues, 1, 0.35);
    _addVelocity(estimatedVelocityValues, 0, 0.05);

    final newest = _index;
    final oldest = _slotAt(_count - 1)!;
    final positions = _positions!;
    final offsetValues = List.generate(dims, (i) {
      return positions[newest * dims + i] - positions[oldest * dims + i];
    });

    return MotionVelocityEstimate<T>(
      perSecond: converter.denormalize(estimatedVelocityValues),
      duration: Duration(microseconds: _times[newest] - _times[oldest]),
      offset: converter.denormalize(offsetValues),
    );
  }
}

/// A velocity estimate from recent position samples.
class MotionVelocityEstimate<T> {
  /// Creates a velocity estimate.
  const MotionVelocityEstimate({
    required this.perSecond,
    required this.duration,
    required this.offset,
  });

  /// The estimated rate of change per second.
  final T perSecond;

  /// The time that elapsed between the first and last position sample.
  final Duration duration;

  /// The difference between the first and last position sample.
  final T offset;

  @override
  String toString() =>
      'MotionVelocityEstimate($perSecond; offset: $offset, '
      'duration: $duration)';
}
