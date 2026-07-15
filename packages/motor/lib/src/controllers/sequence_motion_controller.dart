// ignore_for_file: deprecated_member_use_from_same_package

part of 'motion_controller.dart';

/// A motion controller that adds the capability to play motion sequences.
///
/// Extends [MotionController] with sequence playback capabilities,
/// automatic phase progression, and loop mode support.
///
/// ```dart
/// final controller = SequenceMotionController<ButtonState, Offset>(
///   motion: Motion.smoothSpring(),
///   vsync: this,
///   converter: MotionConverter.offset,
///   initialValue: Offset.zero,
/// );
///
/// final sequence = MotionSequence.states({
///   ButtonState.idle: Offset(0, 0),
///   ButtonState.pressed: Offset(0, 5),
/// }, motion: Motion.smoothSpring());
///
/// await controller.playSequence(sequence);
/// ```
@Deprecated(
  'Use PhaseTrackController with a TrackPhaseTimeline instead. '
  'See MIGRATION.md. '
  'SequenceMotionController will be removed in motor 3.0.',
)
class SequenceMotionController<P, T extends Object>
    extends MotionController<T> {
  /// Creates a phase motion controller with single motion for all dimensions.
  @Deprecated(
    'Use PhaseTrackController with a TrackPhaseTimeline instead. '
    'See MIGRATION.md. '
    'SequenceMotionController will be removed in motor 3.0.',
  )
  SequenceMotionController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
    super.velocityTracking,
  });

  /// Creates a sequence motion controller with motion per dimension.
  @Deprecated(
    'Use PhaseTrackController with a TrackPhaseTimeline instead. '
    'See MIGRATION.md. '
    'SequenceMotionController will be removed in motor 3.0.',
  )
  SequenceMotionController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
    super.velocityTracking,
  }) : super.motionPerDimension();

  MotionSequence<P, T>? _activeSequence;
  List<P> _chainRun = const [];
  int _currentSequencePhaseIndex = 0;
  int _sequenceDirection = 1;
  void Function(PhaseTransition<P> transition)? _onPhaseTransition;
  bool _isPlayingSequence = false;
  P? _currentSequencePhase;
  P? _previousSequencePhase;

  /// Current target phase (null if not playing sequence).
  P? get currentSequencePhase => _currentSequencePhase;

  /// Whether a sequence is currently playing.
  bool get isPlayingSequence => _isPlayingSequence;

  /// The active sequence (null if not playing).
  MotionSequence<P, T>? get activeSequence => _activeSequence;

  /// Progress through current sequence (0.0 to 1.0).
  double get sequenceProgress {
    if (_activeSequence == null || !_isPlayingSequence) return 0;
    final totalPhases = _activeSequence!.phases.length;
    if (totalPhases <= 1) return 1;
    return _currentSequencePhaseIndex / (totalPhases - 1);
  }

  TickerFuture _playChain(
    List<P> run, {
    required P? fromPhaseForFirstLeg,
    T? withVelocity,
    bool emitTransition = true,
  }) {
    final sequence = _activeSequence!;
    _chainRun = run;
    _previousSequencePhase = _currentSequencePhase;
    final previous = _previousSequencePhase;
    _currentSequencePhase = run.first;
    _currentSequencePhaseIndex = sequence.phases.indexOf(run.first);

    final steps = <Step<T>>[
      Step.to(
        sequence.valueForPhase(run.first),
        motion: sequence.motionForPhase(
          toPhase: run.first,
          fromPhase: fromPhaseForFirstLeg,
        ),
      ),
      for (var i = 1; i < run.length; i++) ...[
        // A fresh identity keeps each phase barrier independent.
        // ignore: prefer_const_constructors
        Step.sync(token: Object()),
        Step.to(
          sequence.valueForPhase(run[i]),
          motion: sequence.motionForPhase(
            toPhase: run[i],
            fromPhase: run[i - 1],
          ),
        ),
      ],
    ];

    if (withVelocity != null) {
      // Seed the track's velocity without moving its value.
      _inner.set(
        [_track.value(value)],
        withVelocity: [_track.velocity(withVelocity)],
      );
    }
    if (emitTransition && previous != null) {
      _onPhaseTransition?.call(
        PhaseTransitioning(from: previous, to: run.first),
      );
    }
    final future = super.play(steps, loop: LoopMode.none, onStep: _onChainStep);
    // play() nulls _lastTarget; restore it so _getStatusWhenDone() reports
    // completed/dismissed against the current phase target, like legacy.
    _lastTarget = sequence.valueForPhase(run.first);
    return future;
  }

  void _onChainStep(int stepIndex) {
    if (!_isPlayingSequence) return;
    if (stepIndex.isEven) return;
    final runIndex = (stepIndex + 1) ~/ 2;
    final from = _chainRun[runIndex - 1];
    final to = _chainRun[runIndex];
    _previousSequencePhase = from;
    _currentSequencePhase = to;
    _currentSequencePhaseIndex = _activeSequence!.phases.indexOf(to);
    _lastTarget = _activeSequence!.valueForPhase(to);
    _onPhaseTransition?.call(PhaseTransitioning(from: from, to: to));
  }

  /// Plays through a motion sequence with automatic phase progression.
  ///
  /// Returns a future that completes when non-looping sequences finish.
  /// Looping sequences run indefinitely until stopped.
  ///
  /// Optionally start [atPhase] and receive [onTransition] callbacks.
  /// Preserves current velocity unless [withVelocity] is provided.
  TickerFuture playSequence(
    MotionSequence<P, T> sequence, {
    P? atPhase,
    T? withVelocity,
    void Function(PhaseTransition<P> transition)? onTransition,
  }) {
    _stopSequence();
    if (sequence.phases.isEmpty) return TickerFuture.complete();
    _activeSequence = sequence;
    _onPhaseTransition = onTransition;
    _isPlayingSequence = true;
    _sequenceDirection = 1;
    final targetPhase = atPhase ?? sequence.initialPhase;
    final startIndex = sequence.phases.indexOf(targetPhase);
    if (startIndex == -1) {
      throw ArgumentError('Phase $targetPhase not found in sequence');
    }
    return _playChain(
      sequence.phases.sublist(startIndex),
      fromPhaseForFirstLeg: null,
      withVelocity: withVelocity,
      emitTransition: false,
    );
  }

  @override
  void _handleInnerStatus(AnimationStatus status) {
    if (!_isPlayingSequence || status != AnimationStatus.completed) {
      super._handleInnerStatus(status);
      return;
    }
    final sequence = _activeSequence!;
    final phases = sequence.phases;
    switch (sequence.loop) {
      case LoopMode.none:
        _completeSequence();
      case LoopMode.loop:
        _playChain(phases, fromPhaseForFirstLeg: _chainRun.last);
      case LoopMode.pingPong:
        if (_sequenceDirection == 1) {
          _sequenceDirection = -1;
          var start = phases.length - 2;
          if (start < 0) start = 0;
          _playChain(
            [for (var i = start; i >= 0; i--) phases[i]],
            fromPhaseForFirstLeg: _chainRun.last,
          );
        } else {
          _sequenceDirection = 1;
          var start = 1;
          if (start >= phases.length) start = phases.length - 1;
          _playChain(
            phases.sublist(start),
            fromPhaseForFirstLeg: _chainRun.last,
          );
        }
      case LoopMode.seamless:
        final first = phases.first;
        _inner.set([_track.value(sequence.valueForPhase(first))]);
        _inner.resetVelocityTracking();
        _previousSequencePhase = _currentSequencePhase;
        _currentSequencePhase = first;
        _currentSequencePhaseIndex = 0;
        _onPhaseTransition?.call(PhaseSettled(first));
        if (phases.length == 1) {
          _completeSequence();
          return;
        }
        _playChain(phases.sublist(1), fromPhaseForFirstLeg: first);
    }
  }

  void _completeSequence() {
    final finalPhase = _currentSequencePhase;
    _isPlayingSequence = false;
    _currentSequencePhase = null;
    _previousSequencePhase = null;
    _activeSequence = null;
    _chainRun = const [];
    if (finalPhase != null) {
      _onPhaseTransition?.call(PhaseSettled(finalPhase));
    }
    _onPhaseTransition = null;
    // Now let the base class evaluate the resting status (completed, or
    // dismissed when the final phase value equals the initial value).
    super._handleInnerStatus(AnimationStatus.completed);
  }

  void _stopSequence() {
    if (!_isPlayingSequence) return;
    _isPlayingSequence = false;
    _currentSequencePhase = null;
    _previousSequencePhase = null;
    _onPhaseTransition = null;
    _activeSequence = null;
    _chainRun = const [];
  }

  @override
  set value(T newValue) {
    _stopSequence();
    super.value = newValue;
  }

  @override
  TickerFuture animateTo(T target, {T? from, T? withVelocity}) {
    _stopSequence();
    return super.animateTo(target, from: from, withVelocity: withVelocity);
  }

  @override
  TickerFuture play(
    List<Step<T>> steps, {
    LoopMode? loop,
    void Function(int stepIndex)? onStep,
  }) {
    _stopSequence();
    return super.play(steps, loop: loop, onStep: onStep);
  }

  @override
  TickerFuture stop({bool canceled = false}) {
    _stopSequence();
    return super.stop(canceled: canceled);
  }

  @override
  void dispose() {
    _stopSequence();
    super.dispose();
  }

  @override
  set converter(MotionConverter<T> newConverter) {
    _stopSequence();
    super.converter = newConverter;
  }

  @override
  set motion(Motion value) {
    _motionPerDimension = List.filled(_motionPerDimension.length, value);
  }

  @override
  set motionPerDimension(Iterable<Motion> value) {
    assert(
      value.length == _motionPerDimension.length,
      'the number of motions must match the number of dimensions',
    );
    if (motionsEqual(_motionPerDimension, value)) return;
    _motionPerDimension = value.toList();
  }
}
