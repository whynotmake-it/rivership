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

  /// The sequence passed to [playSequence], or null when nothing plays.
  MotionSequence<P, T>? _activeSequence;

  /// The phases of the chain currently playing, in playback order.
  ///
  /// A "chain" is one directional run through the sequence, played as a
  /// single [play] call. For [LoopMode.pingPong] this can be the reversed
  /// phase list, so [_onChainStep] indexes into this list rather than into
  /// [_activeSequence]'s (always-forward) phases.
  List<P> _chainRun = const [];

  /// Where [_currentSequencePhase] sits in [_activeSequence]'s phase list.
  ///
  /// Kept separately because [sequenceProgress] is defined over the
  /// sequence's own phase order, not the (possibly reversed) [_chainRun].
  int _currentSequencePhaseIndex = 0;

  /// 1 while playing forward, -1 during a pingPong reverse pass.
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

  /// Plays one directional run of phases as a single step chain.
  ///
  /// The chain alternates `Step.to` and `Step.sync`: each phase becomes a
  /// `Step.to` leg, and a sync barrier sits between consecutive legs. The
  /// barriers are what reproduce the legacy timing: a single-track barrier
  /// releases in the same tick it is reached, re-anchoring the next leg's
  /// start time to that tick (instead of the previous leg's ideal end time),
  /// which is exactly how the old controller started each phase.
  ///
  /// Resulting step indices: even = the `Step.to` for `run[index ~/ 2]`,
  /// odd = the barrier released when the leg before it finishes.
  ///
  /// [fromPhaseForFirstLeg] is forwarded to [MotionSequence.motionForPhase]
  /// for the first leg: null means "sequence start" (a `NoMotion` hold for
  /// plain sequences), while loop/pingPong continuations pass the phase the
  /// previous chain ended on so the first leg animates.
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

  /// Translates the chain's step indices into phase transitions.
  ///
  /// Called by the engine whenever playback enters a new step.
  void _onChainStep(int stepIndex) {
    if (!_isPlayingSequence) return;
    // Even indices are the Step.to legs; entering one is not news — its
    // target phase was already reported when the barrier before it released.
    // Odd indices are the sync barriers, reached in the exact tick the
    // previous leg finished: that is the moment a phase transition happens.
    if (stepIndex.isEven) return;
    // Barrier at index 2i-1 sits between run[i - 1] and run[i], so the
    // barrier's own index maps to its destination leg like this:
    final runIndex = (stepIndex + 1) ~/ 2;
    final from = _chainRun[runIndex - 1];
    final to = _chainRun[runIndex];
    _previousSequencePhase = from;
    _currentSequencePhase = to;
    // sequenceProgress is defined over the sequence's forward phase order,
    // so look the phase up there (not in the possibly-reversed _chainRun).
    _currentSequencePhaseIndex = _activeSequence!.phases.indexOf(to);
    // Keep the base class's resting-status bookkeeping pointed at the phase
    // we are now heading for (it compares this against the initial value to
    // report completed vs dismissed once everything settles).
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

  /// Intercepts the inner controller's completion to chain the next cycle.
  ///
  /// Overriding this (instead of adding a status listener) matters: the base
  /// class would otherwise report [AnimationStatus.completed] between loop
  /// cycles, while a looping sequence should stay `forward` throughout.
  /// Everything here runs synchronously inside the completion tick, so the
  /// next chain's ticker is backdated to this frame and each cycle anchors
  /// where the previous one ended — the same timing the legacy controller
  /// produced. Deferring any of this to a post-frame callback would lose
  /// that anchoring.
  @override
  void _handleInnerStatus(AnimationStatus status) {
    // Not our completion to intercept: either no sequence is playing, or the
    // inner controller reported something other than "done".
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
        // Replay the whole sequence. Passing the phase we ended on as the
        // first leg's fromPhase makes motionForPhase return a real motion,
        // so the wrap-around leg animates back to the start instead of
        // holding (NoMotion is only for a sequence's very first leg).
        _playChain(phases, fromPhaseForFirstLeg: _chainRun.last);
      case LoopMode.pingPong:
        if (_sequenceDirection == 1) {
          // Forward pass finished: walk back down from the second-to-last
          // phase (we are already resting on the last one).
          _sequenceDirection = -1;
          var start = phases.length - 2;
          if (start < 0) start = 0; // Single-phase sequence: stay put.
          _playChain(
            [for (var i = start; i >= 0; i--) phases[i]],
            fromPhaseForFirstLeg: _chainRun.last,
          );
        } else {
          // Reverse pass finished: head forward again from the second
          // phase (we are already resting on the first one).
          _sequenceDirection = 1;
          var start = 1;
          if (start >= phases.length) start = phases.length - 1;
          _playChain(
            phases.sublist(start),
            fromPhaseForFirstLeg: _chainRun.last,
          );
        }
      case LoopMode.seamless:
        // Seamless assumes the last phase's value matches the first's, so
        // jump straight there (no animated return leg) and clear any
        // velocity samples the jump would otherwise pollute.
        final first = phases.first;
        _inner.set([_track.value(sequence.valueForPhase(first))]);
        _inner.resetVelocityTracking();
        _previousSequencePhase = _currentSequencePhase;
        _currentSequencePhase = first;
        _currentSequencePhaseIndex = 0;
        _onPhaseTransition?.call(PhaseSettled(first));
        if (phases.length == 1) {
          // Nothing to continue to after the jump.
          _completeSequence();
          return;
        }
        _playChain(phases.sublist(1), fromPhaseForFirstLeg: first);
    }
  }

  /// Ends a sequence that ran to natural completion.
  ///
  /// Unlike [_stopSequence], this reports [PhaseSettled] for the final phase
  /// before clearing the bookkeeping — interruptions stay silent, natural
  /// completion announces itself.
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

  /// Silently abandons the active sequence, emitting no events.
  ///
  /// Used when something interrupts playback (`value=`, [animateTo], [play],
  /// [stop], [dispose], a converter swap, or a new [playSequence]).
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

  // The base setter stops the inner track and replaces the Track identity
  // (forgetting the old one), which would strand the sequence bookkeeping on
  // a dead chain. Treat a converter swap as an interruption, like value=.
  // (Canceled stops are silent since the status-semantics fix, so this is
  // pure bookkeeping — not a defense against spurious status events.)
  @override
  set converter(MotionConverter<T> newConverter) {
    _stopSequence();
    super.converter = newConverter;
  }

  // The base motion setters redirect an in-flight animation to its target.
  // The legacy controller deliberately skipped that during sequences (the
  // new motion should only apply from the next leg on), so these overrides
  // update the motions without calling _redirect().
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
