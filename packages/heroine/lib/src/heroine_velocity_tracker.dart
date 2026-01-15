part of 'heroines.dart';

/// Tracks a short history of heroine locations to derive a release velocity.
///
/// This is used for gesture-driven flights where we only need velocity at the
/// moment the gesture ends.
class _HeroineVelocityTracker {
  /// Creates a new velocity tracker.
  _HeroineVelocityTracker({
    this.historySize = 5,
  })  : assert(
          historySize >= 2,
          'historySize must be at least 2 to compute a velocity',
        ),
        _samples = List<_HeroineVelocitySample?>.filled(historySize, null);

  /// The maximum number of samples to keep.
  final int historySize;

  /// The maximum age of samples to consider.
  static const Duration horizon  = Duration(milliseconds: 80);

  final List<_HeroineVelocitySample?> _samples;
  int _index = 0;
  Stopwatch? _stopwatch;

  /// Adds a new location sample to the tracker.
  void addSample(HeroineLocation location) {
    final stopwatch = _stopwatch ??= Stopwatch()..start();
    final time = stopwatch.elapsed;
    _samples[_index] = _HeroineVelocitySample(
      location: location,
      time: time,
    );
    _index = (_index + 1) % historySize;
  }

  /// Returns the velocity derived from recent samples, if available.
  HeroineLocation? get velocity {
    final samples = _recentSamples();
    if (samples.length < 2) {
      return null;
    }

    var totalWeight = 0.0;
    var vx = 0.0;
    var vy = 0.0;
    var vw = 0.0;
    var vh = 0.0;
    var vrot = 0.0;

    for (var i = 1; i < samples.length; i++) {
      final previous = samples[i - 1];
      final current = samples[i];
      final dtMicros =
          (current.time - previous.time).inMicroseconds.toDouble();
      if (dtMicros <= 0) {
        continue;
      }
      final seconds = dtMicros / 1000000.0;
      final weight = i.toDouble();

      final prevRect = previous.location.boundingBox;
      final currRect = current.location.boundingBox;

      vx += ((currRect.left - prevRect.left) / seconds) * weight;
      vy += ((currRect.top - prevRect.top) / seconds) * weight;
      vw += ((currRect.width - prevRect.width) / seconds) * weight;
      vh += ((currRect.height - prevRect.height) / seconds) * weight;
      vrot += ((current.location.rotation - previous.location.rotation) /
              seconds) *
          weight;
      totalWeight += weight;
    }

    if (totalWeight <= 0) {
      return null;
    }

    return HeroineLocation(
      boundingBox: Rect.fromLTWH(
        vx / totalWeight,
        vy / totalWeight,
        vw / totalWeight,
        vh / totalWeight,
      ),
      rotation: vrot / totalWeight,
    );
  }

  List<_HeroineVelocitySample> _recentSamples() {
    final stopwatch = _stopwatch;
    if (stopwatch == null) {
      return const <_HeroineVelocitySample>[];
    }

    final now = stopwatch.elapsed;
    final samples = <_HeroineVelocitySample>[];

    for (var i = 0; i < historySize; i++) {
      final index = (_index - 1 - i) % historySize;
      final normalizedIndex = index < 0 ? index + historySize : index;
      final sample = _samples[normalizedIndex];
      if (sample == null) {
        break;
      }
      if (now - sample.time > horizon) {
        break;
      }
      samples.add(sample);
    }

    return samples.reversed.toList(growable: false);
  }
}

class _HeroineVelocitySample {
  const _HeroineVelocitySample({
    required this.location,
    required this.time,
  });

  final HeroineLocation location;
  final Duration time;
}
