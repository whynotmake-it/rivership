part of 'track_controller.dart';

class _TrackSlot<T extends Object> {
  _TrackSlot({
    required this.converter,
    required List<double> initialValues,
    this.fallbackMotion,
    this.fallbackMotionPerDimension,
  })  : assert(
          debugCheckDimensions(converter, initialValues.length),
          'normalize must match the converter dimensions',
        ),
        _currentValues = _ownedCopy(initialValues),
        _initialValues = converter is DirectionalMotionConverter<T>
            ? null
            : _ownedCopy(initialValues),
        _velocityValues = List<double>.filled(initialValues.length, 0);

  MotionConverter<T> converter;
  final Motion? fallbackMotion;
  final List<Motion>? fallbackMotionPerDimension;

  // Owned by this slot and updated in place while playing. Converters get
  // them directly: they must not keep the list they are given.
  List<double> _currentValues;
  List<double> _velocityValues;
  StepPlayback<T>? _stepPlayback;
  var _playing = false;
  Duration _startOffset = Duration.zero;

  // Plans replaced while inspection tooling was attached, oldest first, so
  // scrubbing can show them. The current plan started at [_planStart].
  static const _maxArchivedPlans = 8;
  List<_ArchivedPlan<T>>? _archive;
  Duration _planStart = Duration.zero;
  _ArchivedPlan<T>? _shownArchive;

  // Per-track status: the value the track started out at (only kept for
  // converters without a direction, whose status compares to it), its status
  // while not playing, and the direction of its latest move.
  final List<double>? _initialValues;
  var _restingStatus = AnimationStatus.dismissed;
  var _lastMovesDown = false;

  // While a graceful stop settles, whether the track was moving down when it
  // was stopped. A stop interrupts the move, so the status keeps that
  // direction.
  bool? _stoppedDown;

  // The presented value clamps bounded dimensions in a reused buffer.
  MotionConverter<T>? _boundsFor;
  List<MotionDimension>? _bounds;
  List<double>? _scratch;

  T get value {
    if (!identical(_boundsFor, converter)) {
      _boundsFor = converter;
      final dimensions = converter.dimensions;
      _bounds = dimensions != null &&
              dimensions.any((d) => d.min.isFinite || d.max.isFinite)
          ? dimensions
          : null;
    }
    final bounds = _bounds;
    if (bounds == null) return converter.denormalize(_currentValues);
    final length = _currentValues.length;
    final scratch = _scratch?.length == length
        ? _scratch!
        : _scratch = List<double>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      scratch[i] = _currentValues[i].clamp(bounds[i].min, bounds[i].max);
    }
    return converter.denormalize(scratch);
  }

  /// Velocities are presented unclamped.
  T get velocity => converter.denormalize(_velocities);

  /// The current values and velocities, normalized and live: do not keep or
  /// change them.
  List<double> get normalizedValues => _currentValues;
  List<double> get normalizedVelocities => _velocities;

  /// Whether this track's velocity comes from its velocity tracker, which
  /// the controller then estimates whenever it is needed.
  bool velocityFromTracker = false;

  // While playing, velocities are only pulled from the playback when read.
  var _velocitiesStale = false;

  List<double> get _velocities {
    if (_velocitiesStale) {
      _velocitiesStale = false;
      _stepPlayback?.copyVelocitiesInto(_velocityValues);
    }
    return _velocityValues;
  }

  static List<double> _ownedCopy(List<double> values) =>
      List<double>.of(values, growable: false);

  bool get isAnimating => _playing;

  /// Whether this track's plan has ended: its last step's motion has reached
  /// its duration, or it is idle, or a graceful stop is settling it.
  bool get hasEnded =>
      !_playing || _stoppedDown != null || (_stepPlayback?.hasEnded ?? true);

  bool get hasPlayback => _stepPlayback != null;

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

  /// Jumps to [value] like [setValue], but keeps the current velocity.
  void jumpKeepingVelocity(T value) {
    // Reading it pulls the velocities from the playback that jumping drops.
    _velocities;
    _setValues(converter.normalize(value));
  }

  void setValueWithVelocity(T value, T velocity) =>
      setNormalized(converter.normalize(value), converter.normalize(velocity));

  void setNormalized(List<double> values, List<double> velocities) {
    _setValues(values);
    _velocityValues = _ownedCopy(velocities);
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
    _stoppedDown = null;
    _jumpTo(values);
    _currentValues.setAll(0, values);
    _velocitiesStale = false;
    _stepPlayback = null;
    _playing = false;
  }

  /// Rests at [values] without playing. A plan this replaces counts as
  /// finished there.
  void rest(List<double> values) {
    final wasPlaying = _playing;
    final down = _movesDown;
    _setValues(values);
    _velocityValues.fillRange(0, _velocityValues.length, 0);
    if (wasPlaying) {
      _lastMovesDown = down;
      _restingStatus = _finishedStatus(_currentValues);
    }
  }

  /// Replaces the velocity, given normalized, without touching the value or
  /// playback.
  void setVelocity(List<double> velocity) {
    _velocityValues = _ownedCopy(velocity);
    _velocitiesStale = false;
  }

  /// Plays [steps] from the current value, and [velocity] (normalized) or
  /// the current velocity, [delay] after [startOffset].
  ///
  /// With [handOver], the plan this one replaces keeps playing as far as
  /// this one doesn't move yet.
  void play(
    List<TrackStep<T>> steps, {
    required Duration startOffset,
    LoopMode loop = LoopMode.none,
    List<double>? velocity,
    List<List<double>>? waypoints,
    Duration delay = Duration.zero,
    bool handOver = false,
  }) {
    final incoming =
        handOver && _playing ? _stepPlayback?.liveSimulations : null;
    _startOffset = startOffset;
    _lastMovesDown = _movesDown;
    _stoppedDown = null;
    _stepPlayback = StepPlayback<T>.normalized(
      steps: steps,
      converter: converter,
      initialValues: _currentValues,
      initialVelocities: velocity ?? _velocities,
      waypoints: waypoints,
      loop: loop,
      fallbackMotion: fallbackMotion,
      fallbackMotionPerDimension: fallbackMotionPerDimension,
      incoming: incoming,
      delay: delay.inMicroseconds / Duration.microsecondsPerSecond,
    );
    _pullPlaybackState();
    _playing = true;
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

  /// Advances to [elapsed]. While [scrubbing], times before the current plan
  /// show the archived plan that was active then, for viewing only; playback
  /// always continues the current plan.
  bool tick(Duration elapsed, {bool scrubbing = false}) {
    _shownArchive = null;
    final archive = _archive;
    if (scrubbing && archive != null && elapsed < _planStart) {
      final index = archive.lastIndexWhere((plan) => plan.start <= elapsed);
      if (index >= 0) return _showArchive(archive[index], elapsed);
    }
    if (!_playing) return true;

    final done = _tickStepPlayback(_localSeconds(elapsed));
    if (done) _finish();
    return done;
  }

  /// Comes to rest once the plan finished: the next plan starts from rest,
  /// as after [stop].
  void _finish() {
    if (_stoppedDown case final down?) {
      _stoppedDown = null;
      _restAfterStop(down);
    } else {
      _lastMovesDown = _movesDown;
      _restingStatus = _finishedStatus(_currentValues);
    }
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _velocitiesStale = false;
    _playing = false;
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
  /// - After a stop, the direction it was moving in, also while a graceful
  ///   stop settles.
  AnimationStatus get status {
    if (_stoppedDown case final down?) {
      return down ? AnimationStatus.reverse : AnimationStatus.forward;
    }
    if (!_playing) return _restingStatus;
    return _movesDown ? AnimationStatus.reverse : AnimationStatus.forward;
  }

  bool get _isDirectional => converter is DirectionalMotionConverter<T>;

  /// The direction of the shown move, or of the latest one with a direction.
  bool get _movesDown => shownPlayback?.shownMovesDown ?? _lastMovesDown;

  /// Whether the track is moving down, or was when it was stopped.
  bool get movingDown => _stoppedDown ?? _movesDown;

  /// Treats the running animation as the settle of a stop moving [down].
  void keepStopDirection({required bool down}) {
    if (!_playing) {
      _restAfterStop(down);
    } else {
      _stoppedDown = down;
    }
  }

  void _restAfterStop(bool down) {
    _lastMovesDown = down;
    _restingStatus = down ? AnimationStatus.reverse : AnimationStatus.forward;
  }

  AnimationStatus _finishedStatus(List<double> values) {
    final down = _isDirectional ? _lastMovesDown : _sameValues(values);
    return down ? AnimationStatus.dismissed : AnimationStatus.completed;
  }

  /// Swaps in [value], which reads the normalized values the same way, and
  /// keeps playing.
  void replaceConverter(MotionConverter<T> value) {
    converter = value;
    _stepPlayback?.converter = value;
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
        converter.denormalize(_currentValues),
        converter.denormalize(values),
      );
      if (order == 0) return;
      _lastMovesDown = order > 0;
    }
    _restingStatus = _finishedStatus(values);
  }

  /// Makes a retained plan playable again, e.g. after it completed.
  void reactivate() {
    if (_stepPlayback != null) _playing = true;
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
      initialValues: _currentValues,
      fallbackMotion: fallbackMotion,
      fallbackMotionPerDimension: fallbackMotionPerDimension,
    )
      .._stepPlayback = playback.fork()
      .._startOffset = _startOffset
      .._playing = true;
  }

  void _pullPlaybackState() {
    _stepPlayback!.copyValuesInto(_currentValues);
    _velocitiesStale = true;
  }

  /// Redirects this slot to settle at its current value, preserving the
  /// current velocity, with the motion of the running step, or the fallback
  /// motion while a free motion, hold or barrier runs.
  ///
  /// Returns true if a settling animation was started. Returns false when the
  /// slot is idle or none of those motions needs to settle, in which case the
  /// caller should hard-[stop] instead.
  bool settle({required Duration startOffset}) {
    if (!_playing) return false;
    final motions = _stepPlayback?.currentMotions ?? _fallbackMotions;
    if (motions == null || !motions.any((motion) => motion.needsSettle)) {
      return false;
    }
    final down = _movesDown;
    play(
      [TrackStep.to(value, motionPerDimension: motions)],
      startOffset: startOffset,
      // The step's value is only for show: settle at the exact current values.
      waypoints: [List.of(_currentValues)],
    );
    _stoppedDown = down;
    return true;
  }

  List<Motion>? get _fallbackMotions {
    if (fallbackMotionPerDimension case final perDim?) return perDim;
    if (fallbackMotion case final motion?) {
      return List.filled(_currentValues.length, motion);
    }
    return null;
  }

  /// Stops right away. A stop interrupts the move, so the track keeps the
  /// direction it was moving in as its status.
  void stop() {
    if (_playing) {
      _restAfterStop(_stoppedDown ?? _movesDown);
    }
    _stoppedDown = null;
    _stepPlayback = null;
    _velocityValues = List<double>.filled(_currentValues.length, 0);
    _velocitiesStale = false;
    _playing = false;
  }

  List<int> takeEnteredSteps() => _stepPlayback?.takeEnteredSteps() ?? const [];
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
