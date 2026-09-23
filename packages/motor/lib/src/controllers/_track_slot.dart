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
  final bool _copyBeforeDenormalize;
  StepPlayback<T>? _stepPlayback;
  _TrackSlotPlayback _playback = _TrackSlotPlayback.idle;
  Duration _startOffset = Duration.zero;

  T get value => _denormalize(_currentValues);

  T get velocity => _denormalize(_velocityValues);

  T _denormalize(List<double> values) => converter
      .denormalize(_copyBeforeDenormalize ? _ownedCopy(values) : values);

  static List<double> _ownedCopy(List<double> values) =>
      List<double>.of(values, growable: false);

  bool get isAnimating => _playback != _TrackSlotPlayback.idle;

  bool get hasPlayback => _stepPlayback != null;

  /// When the current plan started, on the controller's playback clock.
  Duration get startOffset => _startOffset;

  bool get isWaitingForSync => _stepPlayback?.isWaitingForSync ?? false;

  Object? get syncToken => _stepPlayback?.syncToken;

  Object? get pendingSyncToken => _stepPlayback?.pendingSyncToken;

  /// When this slot arrived at its pending barrier, on the controller clock.
  Duration get pendingSyncArrival =>
      _startOffset + _fromSeconds(_stepPlayback!.pendingSyncArrivalSeconds);

  /// Releases the pending barrier at [at], on the controller clock.
  void releaseSync(Duration at) {
    final playback = _stepPlayback;
    if (playback == null) return;
    final local = at - _startOffset;
    playback.releaseSync(
      atSeconds: local.inMicroseconds / Duration.microsecondsPerSecond,
    );
    _pullPlaybackState();
  }

  static Duration _fromSeconds(double seconds) => Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      );

  void setValue(T value) {
    _currentValues = _ownedCopy(converter.normalize(value));
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  void setValueWithVelocity(T value, T velocity) {
    _currentValues = _ownedCopy(converter.normalize(value));
    _velocityValues = _ownedCopy(converter.normalize(velocity));
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  /// Replaces the velocity without touching the value or playback.
  void setVelocity(T velocity) {
    _velocityValues = _ownedCopy(converter.normalize(velocity));
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
    _pullPlaybackState();
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

  /// Makes a retained plan playable again, e.g. after it completed.
  void reactivate() {
    if (_stepPlayback != null) _playback = _TrackSlotPlayback.chained;
  }

  bool _tickStepPlayback(double seconds) {
    final done = _stepPlayback!.advanceTo(seconds);
    _pullPlaybackState();
    return done;
  }

  /// A copy of this slot playing a fork of its plan, for resolving ahead.
  _TrackSlot<T>? fork() {
    final playback = _stepPlayback;
    if (playback == null) return null;
    return _TrackSlot<T>(
      converter: converter,
      initialValue: value,
      fallbackMotion: fallbackMotion,
      fallbackMotionPerDimension: fallbackMotionPerDimension,
    )
      .._stepPlayback = playback.fork()
      .._startOffset = _startOffset
      .._playback = _TrackSlotPlayback.chained;
  }

  void _pullPlaybackState() {
    _stepPlayback!.copyStateInto(_currentValues, _velocityValues);
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

  List<int> takeEnteredSteps() => _stepPlayback?.takeEnteredSteps() ?? const [];
}

enum _TrackSlotPlayback {
  idle,
  chained,
}
