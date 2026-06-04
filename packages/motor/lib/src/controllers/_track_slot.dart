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
    List<Step<T>> steps, {
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
