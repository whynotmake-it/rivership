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

  // Plans replaced while inspection tooling was attached, oldest first, so
  // scrubbing can show them. The current plan started at [_planStart].
  static const _maxArchivedPlans = 8;
  final List<_ArchivedPlan<T>> _archive = [];
  Duration _planStart = Duration.zero;
  _ArchivedPlan<T>? _shownArchive;
  var _restoredArchive = false;

  // Whether this track ever started a plan, and whether its latest move with
  // a target headed down, for per-track status.
  var _started = false;
  var _reverse = false;

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
    _started = true;
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

  /// Records the current plan before it is replaced at [now].
  void archive(Duration now) {
    _archive.add(
      _ArchivedPlan<T>(
        start: _planStart,
        startOffset: _startOffset,
        playback: _stepPlayback,
        values: List.of(_currentValues),
        velocities: List.of(_velocityValues),
      ),
    );
    if (_archive.length > _maxArchivedPlans) _archive.removeAt(0);
    _planStart = now;
  }

  bool get hasArchive => _archive.isNotEmpty;

  /// The playback shown right now, which is an archived one while scrubbed
  /// back before the current plan.
  StepPlayback<T>? get shownPlayback =>
      _shownArchive == null ? _stepPlayback : _shownArchive!.playback;

  Duration get shownStartOffset => _shownArchive?.startOffset ?? _startOffset;

  /// Whether the last [tick] continued an archived plan, which then replaced
  /// the current one.
  bool takeRestoredArchive() {
    final restored = _restoredArchive;
    _restoredArchive = false;
    return restored;
  }

  /// Advances to [elapsed]. Times before the current plan show the archived
  /// plan that was active then; unless [scrubbing], that plan also becomes
  /// the current one again, discarding the plans after it.
  bool tick(Duration elapsed, {bool scrubbing = false}) {
    _shownArchive = null;
    if (elapsed < _planStart) {
      final index = _archive.lastIndexWhere((plan) => plan.start <= elapsed);
      if (index >= 0) {
        if (scrubbing) return _showArchive(_archive[index], elapsed);
        _restoreArchive(index);
      }
    }
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

  bool _showArchive(_ArchivedPlan<T> plan, Duration elapsed) {
    _shownArchive = plan;
    final playback = plan.playback;
    if (playback == null) {
      _currentValues = List.of(plan.values);
      _velocityValues = List.of(plan.velocities);
      return true;
    }
    final local = elapsed - plan.startOffset;
    final done = playback.advanceTo(
      local.isNegative
          ? 0
          : local.inMicroseconds / Duration.microsecondsPerSecond,
    );
    _currentValues = List<double>.filled(_currentValues.length, 0);
    _velocityValues = List<double>.filled(_velocityValues.length, 0);
    playback.copyStateInto(_currentValues, _velocityValues);
    return done;
  }

  void _restoreArchive(int index) {
    final plan = _archive[index];
    _archive.removeRange(index, _archive.length);
    _planStart = plan.start;
    _startOffset = plan.startOffset;
    _stepPlayback = plan.playback;
    _currentValues = List.of(plan.values);
    _velocityValues = List.of(plan.velocities);
    _playback = plan.playback == null
        ? _TrackSlotPlayback.idle
        : _TrackSlotPlayback.chained;
    _restoredArchive = true;
  }

  /// This track's status: dismissed until it first plays, forward or reverse
  /// while playing, and completed once its plan finished or was stopped.
  ///
  /// Reverse is reported for directional converters while the current step
  /// heads for a smaller value than it started from.
  AnimationStatus get status {
    if (!_started) return AnimationStatus.dismissed;
    if (_playback == _TrackSlotPlayback.idle) return AnimationStatus.completed;
    if (converter case final DirectionalMotionConverter<T> directional) {
      if (_stepPlayback?.shownMove case (:final from, :final to)) {
        final order = directional.compare(
          converter.denormalize(from),
          converter.denormalize(to),
        );
        if (order != 0) _reverse = order > 0;
      }
    }
    return _reverse ? AnimationStatus.reverse : AnimationStatus.forward;
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

/// A plan that a slot replaced, kept for scrubbing back.
class _ArchivedPlan<T extends Object> {
  _ArchivedPlan({
    required this.start,
    required this.startOffset,
    required this.playback,
    required this.values,
    required this.velocities,
  });

  /// When this plan became current, on the controller clock.
  final Duration start;

  /// The playback's start offset, when it has one.
  final Duration startOffset;

  /// The replaced playback, or null if the track was holding a set value.
  final StepPlayback<T>? playback;

  /// The track's state when the plan was replaced, used when there is no
  /// playback.
  final List<double> values;
  final List<double> velocities;
}
