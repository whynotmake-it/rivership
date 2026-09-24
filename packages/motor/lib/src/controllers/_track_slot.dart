part of 'track_controller.dart';

class _TrackSlot<T extends Object> {
  _TrackSlot({
    required this.converter,
    required T initialValue,
    this.fallbackMotion,
    this.fallbackMotionPerDimension,
  })  : _currentValues = _ownedCopy(converter.normalize(initialValue)),
        _initialValues = converter is DirectionalMotionConverter<T>
            ? null
            : _ownedCopy(converter.normalize(initialValue)),
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
  List<_ArchivedPlan<T>>? _archive;
  Duration _planStart = Duration.zero;
  _ArchivedPlan<T>? _shownArchive;
  var _restoredArchive = false;

  // Per-track status: the value the track started out at (only kept for
  // converters without a direction, whose status compares to it), its status
  // while not playing, and the direction of its latest move.
  final List<double>? _initialValues;
  var _restingStatus = AnimationStatus.dismissed;
  var _lastMovesDown = false;

  T get value => _denormalize(_currentValues);

  T get velocity => _denormalize(_velocities);

  /// When the controller last recorded a velocity sample for this track
  /// whose estimate it has not applied yet.
  DateTime? pendingVelocityAt;

  // While playing, velocities are only pulled from the playback when read.
  var _velocitiesStale = false;

  List<double> get _velocities {
    if (_velocitiesStale) {
      _velocitiesStale = false;
      _stepPlayback?.copyVelocitiesInto(_velocityValues);
    }
    return _velocityValues;
  }

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
    _setValues(converter.normalize(value));
    _velocityValues.fillRange(0, _velocityValues.length, 0);
  }

  void setValueWithVelocity(T value, T velocity) {
    _setValues(converter.normalize(value));
    _velocityValues = _ownedCopy(converter.normalize(velocity));
  }

  // The slot's buffers are its own (archives and views copy them), so a
  // jump writes into them instead of replacing them.
  void _setValues(List<double> values) {
    assert(
      values.length == _currentValues.length,
      'New values must have the same number of dimensions as the track',
    );
    if (values.length != _currentValues.length) {
      _currentValues = _ownedCopy(values);
      _velocityValues = List<double>.filled(values.length, 0);
    }
    _jumpTo(values);
    _currentValues.setAll(0, values);
    _velocitiesStale = false;
    _stepPlayback = null;
    _playback = _TrackSlotPlayback.idle;
  }

  /// Replaces the velocity without touching the value or playback.
  void setVelocity(T velocity) {
    _velocityValues = _ownedCopy(converter.normalize(velocity));
    _velocitiesStale = false;
  }

  void play(
    List<TrackStep<T>> steps, {
    required Duration startOffset,
    LoopMode loop = LoopMode.none,
    T? velocity,
  }) {
    _startOffset = startOffset;
    _lastMovesDown = _movesDown;
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
    final archive = (_archive ??= [])
      ..add(
        _ArchivedPlan<T>(
          start: _planStart,
          startOffset: _startOffset,
          playback: _stepPlayback,
          values: List.of(_currentValues),
          velocities: List.of(_velocities),
        ),
      );
    if (archive.length > _maxArchivedPlans) archive.removeAt(0);
    _planStart = now;
  }

  bool get hasArchive => _archive?.isNotEmpty ?? false;

  /// Forgets all archived plans, for example after tooling detached.
  void clearArchive() {
    _archive = null;
    _shownArchive = null;
  }

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
    final archive = _archive;
    if (archive != null && elapsed < _planStart) {
      final index = archive.lastIndexWhere((plan) => plan.start <= elapsed);
      if (index >= 0) {
        if (scrubbing) return _showArchive(archive[index], elapsed);
        _restoreArchive(index);
      }
    }
    if (_playback == _TrackSlotPlayback.idle) return true;

    final seconds = _localSeconds(elapsed);
    final done = switch (_playback) {
      _TrackSlotPlayback.idle => true,
      _TrackSlotPlayback.chained => _tickStepPlayback(seconds),
    };

    if (done) _finish();
    return done;
  }

  /// Comes to rest once the plan finished: the next plan starts from rest,
  /// as after [stop].
  void _finish() {
    _lastMovesDown = _movesDown;
    _restingStatus = _finishedStatus(_currentValues);
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _velocitiesStale = false;
    _playback = _TrackSlotPlayback.idle;
  }

  bool _showArchive(_ArchivedPlan<T> plan, Duration elapsed) {
    _shownArchive = plan;
    final playback = plan.playback;
    if (playback == null) {
      _currentValues = List.of(plan.values);
      _velocityValues = List.of(plan.velocities);
      _velocitiesStale = false;
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
    _velocitiesStale = false;
    if (done) {
      // A finished plan rests, as it did when it finished.
      playback.copyValuesInto(_currentValues);
    } else {
      playback.copyStateInto(_currentValues, _velocityValues);
    }
    return done;
  }

  void _restoreArchive(int index) {
    final archive = _archive!;
    final plan = archive[index];
    archive.removeRange(index, archive.length);
    _planStart = plan.start;
    _startOffset = plan.startOffset;
    _stepPlayback = plan.playback;
    _currentValues = List.of(plan.values);
    _velocityValues = List.of(plan.velocities);
    _velocitiesStale = false;
    _playback = plan.playback == null
        ? _TrackSlotPlayback.idle
        : _TrackSlotPlayback.chained;
    _restoredArchive = true;
  }

  /// This track's status.
  ///
  /// - [AnimationStatus.dismissed] until it first moves.
  /// - While playing, [AnimationStatus.reverse] when heading for a smaller
  ///   value (directional converters only), otherwise
  ///   [AnimationStatus.forward].
  /// - After a move finished, or a jump with `set`:
  ///   [AnimationStatus.dismissed] if it went down, otherwise
  ///   [AnimationStatus.completed]. Without a direction, dismissed means
  ///   exactly back at the initial value.
  /// - After a canceled stop, the direction it was moving in.
  AnimationStatus get status {
    if (_playback == _TrackSlotPlayback.idle) return _restingStatus;
    return _movesDown ? AnimationStatus.reverse : AnimationStatus.forward;
  }

  bool get _isDirectional => converter is DirectionalMotionConverter<T>;

  /// The direction of the shown move, or of the latest one with a direction.
  bool get _movesDown => shownPlayback?.shownMovesDown ?? _lastMovesDown;

  AnimationStatus _finishedStatus(List<double> values) {
    final down = _isDirectional ? _lastMovesDown : _sameValues(values);
    return down ? AnimationStatus.dismissed : AnimationStatus.completed;
  }

  /// Takes over [other]'s status, reading its values with this converter.
  void adoptStatus(_TrackSlot other) {
    if (_initialValues case final values?) {
      values.setAll(0, other._initialValues ?? values);
    }
    _restingStatus = other._restingStatus;
    _lastMovesDown = other._lastMovesDown;
  }

  bool _sameValues(List<double> values) {
    final initial = _initialValues;
    return initial != null && _equal(values, initial);
  }

  static bool _equal(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Updates the status for a jump to [values] without animating. Jumping to
  /// the current value keeps the status.
  void _jumpTo(List<double> values) {
    if (_equal(values, _currentValues)) return;
    if (converter case final DirectionalMotionConverter<T> directional) {
      final order = directional.compare(
        _denormalize(_currentValues),
        _denormalize(values),
      );
      if (order == 0) return;
      _lastMovesDown = order > 0;
    }
    _restingStatus = _finishedStatus(values);
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
    _stepPlayback!.copyValuesInto(_currentValues);
    _velocitiesStale = true;
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

  /// Stops right away. A canceled stop keeps the direction the track was
  /// moving in as its status; otherwise the move counts as finished.
  void stop({bool canceled = false}) {
    if (_playback != _TrackSlotPlayback.idle) {
      _lastMovesDown = _movesDown;
      _restingStatus = canceled
          ? (_lastMovesDown ? AnimationStatus.reverse : AnimationStatus.forward)
          : _finishedStatus(_currentValues);
    }
    _stepPlayback = null;
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _velocitiesStale = false;
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
