part of 'track_controller.dart';

class _TrackSlot<T extends Object> {
  _TrackSlot({
    required this.converter,
    required T initialValue,
    this.fallbackMotion,
    this.fallbackMotionPerDimension,
  })  : _currentValues = _ownedCopy(converter.normalize(initialValue)),
        _velocityValues = List<double>.filled(
          converter.normalize(initialValue).length,
          0,
        ),
        _value = initialValue,
        _copyBeforeDenormalize = !_builtInConverters.contains(
          converter.runtimeType,
        );

  // Motor's own converters never keep the list passed to `denormalize`, so
  // the slot's buffers can be handed to them without a copy.
  static const _builtInConverters = {
    SingleMotionConverter,
    OffsetMotionConverter,
    SizeMotionConverter,
    RectMotionConverter,
    AlignmentMotionConverter,
    ColorRgbMotionConverter,
    EdgeInsetsMotionConverter,
    EdgeInsetsDirectionalMotionConverter,
  };

  final MotionConverter<T> converter;
  final Motion? fallbackMotion;
  final List<Motion>? fallbackMotionPerDimension;

  // Owned by this slot and updated in place while playing. Only handed to
  // built-in converters directly: others may keep the list they are given.
  List<double> _currentValues;
  List<double> _velocityValues;
  T? _value;
  T? _velocity;
  final bool _copyBeforeDenormalize;
  StepPlayback<T>? _stepPlayback;
  _TrackSlotPlayback _playback = _TrackSlotPlayback.idle;
  Duration _startOffset = Duration.zero;
  Duration _inspectionStartOffset = Duration.zero;

  T get value => _value ??= _denormalize(_currentValues);

  T get velocity => _velocity ??= _denormalize(_velocityValues);

  T _denormalize(List<double> values) => converter
      .denormalize(_copyBeforeDenormalize ? _ownedCopy(values) : values);

  static List<double> _ownedCopy(List<double> values) =>
      List<double>.of(values, growable: false);

  void _invalidateCache() {
    _value = null;
    _velocity = null;
  }

  bool get isAnimating => _playback != _TrackSlotPlayback.idle;

  bool get hasPlayback => _stepPlayback != null;

  Duration get inspectionStartOffset => _inspectionStartOffset;

  bool get isWaitingForSync => _stepPlayback?.isWaitingForSync ?? false;

  Object? get syncToken => _stepPlayback?.syncToken;

  void releaseSync() => _stepPlayback?.releaseSync();

  bool hasPassedSync(Object token) =>
      _stepPlayback?.hasPassedSync(token) ?? false;

  void setValue(T value) {
    _currentValues = _ownedCopy(converter.normalize(value));
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _value = value;
    _velocity = null;
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  void setValueWithVelocity(T value, T velocity) {
    _currentValues = _ownedCopy(converter.normalize(value));
    _velocityValues = _ownedCopy(converter.normalize(velocity));
    _value = value;
    _velocity = velocity;
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  /// Replaces the velocity without touching the value or playback.
  void setVelocity(T velocity) {
    _velocityValues = _ownedCopy(converter.normalize(velocity));
    _velocity = velocity;
  }

  void play(
    List<TrackStep<T>> steps, {
    required Duration startOffset,
    LoopMode loop = LoopMode.none,
    T? velocity,
    bool estimateDurations = false,
  }) {
    _startOffset = startOffset;
    _inspectionStartOffset = startOffset;
    final velocityValue = velocity ?? this.velocity;
    _stepPlayback = StepPlayback<T>(
      steps: steps,
      converter: converter,
      start: value,
      velocity: velocityValue,
      loop: loop,
      fallbackMotion: fallbackMotion,
      fallbackMotionPerDimension: fallbackMotionPerDimension,
      estimateDurations: estimateDurations,
    );
    _pullPlaybackState();
    _playback = _TrackSlotPlayback.chained;
  }

  double _localSeconds(Duration elapsed) {
    final local = elapsed - _startOffset;
    final seconds = local.inMicroseconds / Duration.microsecondsPerSecond;
    return seconds < 0 ? 0 : seconds;
  }

  double _inspectionSeconds(Duration elapsed) {
    final local = elapsed - _inspectionStartOffset;
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
    if (_stepPlayback == null) return true;
    if (_playback == _TrackSlotPlayback.idle) {
      _playback = _TrackSlotPlayback.chained;
    }

    final seconds = _inspectionSeconds(elapsed);
    return switch (_playback) {
      _TrackSlotPlayback.idle => true,
      _TrackSlotPlayback.chained => _seekStepPlayback(seconds),
    };
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
    final done = _stepPlayback!.advanceTo(seconds);
    _pullPlaybackState();
    return done;
  }

  bool _seekStepPlayback(double seconds) {
    final done = _stepPlayback!.seekTo(seconds);
    _pullPlaybackState();
    return done;
  }

  void _pullPlaybackState() {
    _stepPlayback!.copyStateInto(_currentValues, _velocityValues);
    _invalidateCache();
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
    _velocity = null;
    _playback = _TrackSlotPlayback.idle;
  }

  int get currentStepIndex => _stepPlayback?.currentStepIndex ?? -1;
}

enum _TrackSlotPlayback {
  idle,
  chained,
}
