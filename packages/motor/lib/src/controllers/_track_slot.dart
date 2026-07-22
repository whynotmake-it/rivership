part of 'track_controller.dart';

class _TrackSlot<T extends Object> {
  _TrackSlot({
    required this.converter,
    required T initialValue,
    this.fallbackMotion,
    this.fallbackMotionPerDimension,
  })  : _currentValues = converter.normalize(initialValue),
        _velocityValues = List<double>.filled(
          converter.normalize(initialValue).length,
          0,
        );

  final MotionConverter<T> converter;
  final Motion? fallbackMotion;
  final List<Motion>? fallbackMotionPerDimension;

  List<double> _currentValues;
  List<double> _velocityValues;
  StepPlayback<T>? _stepPlayback;
  _TrackSlotPlayback _playback = _TrackSlotPlayback.idle;
  Duration _startOffset = Duration.zero;

  T get value => converter.denormalize(_currentValues);

  T get velocity => converter.denormalize(_velocityValues);

  bool get isAnimating => _playback != _TrackSlotPlayback.idle;

  bool get isWaitingForSync => _stepPlayback?.isWaitingForSync ?? false;

  Object? get syncToken => _stepPlayback?.syncToken;

  void releaseSync() => _stepPlayback?.releaseSync();

  bool hasPassedSync(Object token) =>
      _stepPlayback?.hasPassedSync(token) ?? false;

  void setValue(T value) {
    _currentValues = converter.normalize(value);
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  void setValueWithVelocity(T value, T velocity) {
    _currentValues = converter.normalize(value);
    _velocityValues = converter.normalize(velocity);
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  void play(
    List<TrackStep<T>> steps, {
    required Duration startOffset,
    LoopMode loop = LoopMode.none,
    T? velocity,
  }) {
    _startOffset = startOffset;
    final velocityValue = velocity ?? this.velocity;
    _stepPlayback = StepPlayback<T>(
      steps: steps,
      converter: converter,
      start: value,
      velocity: velocityValue,
      loop: loop,
      fallbackMotion: fallbackMotion,
      fallbackMotionPerDimension: fallbackMotionPerDimension,
    );
    _currentValues = List.of(_stepPlayback!.values);
    _velocityValues = List.of(_stepPlayback!.velocities);
    _playback = _TrackSlotPlayback.chained;
  }

  double _localSeconds(Duration elapsed) {
    final local = elapsed - _startOffset;
    final seconds = local.inMicroseconds / Duration.microsecondsPerSecond;
    return seconds < 0 ? 0 : seconds;
  }

  bool tick(Duration elapsed) {
    if (_playback == _TrackSlotPlayback.idle) return true;

    final seconds = _localSeconds(elapsed);
    final done = switch (_playback) {
      _TrackSlotPlayback.idle => true,
      _TrackSlotPlayback.chained => _tickStepPlayback(seconds),
    };

    if (done) {
      _playback = _TrackSlotPlayback.idle;
    }
    return done;
  }

  bool scrubTo(Duration elapsed) {
    if (_playback == _TrackSlotPlayback.idle) return true;

    final seconds = _localSeconds(elapsed);
    final done = switch (_playback) {
      _TrackSlotPlayback.idle => true,
      _TrackSlotPlayback.chained => _seekStepPlayback(seconds),
    };

    if (done) {
      _playback = _TrackSlotPlayback.idle;
    }
    return done;
  }

  /// Re-bases the controller axis around this slot's current local playhead.
  ///
  /// A restarted ticker begins at zero. Making the start offset negative by
  /// the already-consumed local time keeps `ticker - startOffset` continuous.
  void rebaseTo(Duration tickerElapsed) {
    final seconds = _stepPlayback?.lastElapsedSeconds ?? 0;
    final localPlayhead = Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
    _startOffset = tickerElapsed - localPlayhead;
  }

  bool _tickStepPlayback(double seconds) {
    final playback = _stepPlayback!;
    final done = playback.advanceTo(seconds);
    _currentValues = List.of(playback.values);
    _velocityValues = List.of(playback.velocities);
    return done;
  }

  bool _seekStepPlayback(double seconds) {
    final playback = _stepPlayback!;
    final done = playback.seekTo(seconds);
    _currentValues = List.of(playback.values);
    _velocityValues = List.of(playback.velocities);
    return done;
  }

  /// Redirects this slot to settle at its current value using the fallback
  /// motion, preserving the current velocity.
  ///
  /// Returns true if a settling animation was started. Returns false when the
  /// slot is idle or has no settle-capable fallback motion, in which case the
  /// caller should hard-[stop] instead.
  bool settle({required Duration startOffset}) {
    if (_playback == _TrackSlotPlayback.idle) return false;
    final motions = _settleMotions;
    if (motions == null || !motions.any((motion) => motion.needsSettle)) {
      return false;
    }
    play([TrackStep.to(value)], startOffset: startOffset);
    return true;
  }

  List<Motion>? get _settleMotions {
    if (fallbackMotionPerDimension case final perDim?) return perDim;
    if (fallbackMotion case final motion?) return [motion];
    return null;
  }

  void stop({bool canceled = false}) {
    _stepPlayback = null;
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _playback = _TrackSlotPlayback.idle;
  }

  int get currentStepIndex => _stepPlayback?.currentStepIndex ?? -1;
}

enum _TrackSlotPlayback {
  idle,
  chained,
}
