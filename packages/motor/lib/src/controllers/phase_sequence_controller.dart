import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/phase_sequence.dart';

/// A MotionController specialized for playing phase sequences with type-safe
/// phase access.
///
/// This controller extends [MotionController] to provide reliable phase-based
/// animations
/// using the existing ticker system rather than callback-based scheduling.
///
/// Unlike the standalone PhaseController, this approach:
/// - Provides compile-time type safety for phase access
/// - Uses ticker-driven progression for reliability
/// - Naturally handles interruption through method overrides
/// - Smoothly transitions from normal animations to sequences
///
/// Example:
/// ```dart
/// final controller = PhaseSequenceController<Color, Offset>(
///   motion: Springs.smooth,
///   vsync: this,
///   converter: OffsetMotionConverter(),
///   initialValue: Offset.zero,
/// );
///
/// final sequence = PhaseSequence.map({
///   Colors.red: Offset(100, 100),
///   Colors.green: Offset(200, 200),
/// }, motion: (_) => Springs.bouncy);
///
/// await controller.playSequence(sequence);
/// ```
class PhaseSequenceController<P, T extends Object> extends MotionController<T> {
  /// Creates a PhaseSequenceController with single motion for all dimensions.
  PhaseSequenceController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  }) {
    // Listen for status changes to handle sequence progression
    addStatusListener(_onStatusChanged);
  }

  /// Creates a PhaseSequenceController with motion per dimension.
  PhaseSequenceController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  }) : super.motionPerDimension() {
    // Listen for status changes to handle sequence progression
    addStatusListener(_onStatusChanged);
  }

  /// Active phase sequence being played
  PhaseSequence<P, T>? _activeSequence;

  /// Current phase index in the sequence
  int _currentSequencePhaseIndex = 0;

  /// Direction for ping-pong sequences (1 = forward, -1 = reverse)
  int _sequenceDirection = 1;

  /// Callback for phase changes
  void Function(P phase)? _onSequencePhaseChanged;

  /// Whether we're currently playing a sequence
  bool _isPlayingSequence = false;

  /// Target phase we're currently animating toward
  P? _currentSequencePhase;

  /// The current animation's TickerFuture
  TickerFuture? _currentAnimationFuture;

  /// Current phase being animated to (null if not playing sequence)
  P? get currentSequencePhase => _currentSequencePhase;

  /// Whether a sequence is currently being played
  bool get isPlayingSequence => _isPlayingSequence;

  /// The active sequence (null if not playing)
  PhaseSequence<P, T>? get activeSequence => _activeSequence;

  /// Progress through current sequence (0.0 to 1.0, accounting for loops)
  double get sequenceProgress {
    if (_activeSequence == null || !_isPlayingSequence) return 0;

    final totalPhases = _activeSequence!.phases.length;
    if (totalPhases <= 1) return 1;

    return _currentSequencePhaseIndex / (totalPhases - 1);
  }

  /// Plays through a phase sequence starting from current value/velocity.
  ///
  /// Returns a [TickerFuture] that completes when sequence finishes
  /// (non-looping)
  /// or never completes for looping sequences.
  ///
  /// If [atPhase] is provided, the sequence will start by animating to that
  /// specific phase, then continue normal sequence progression.
  ///
  /// The [onPhaseChanged] callback is called whenever the animation transitions
  /// to a new phase.
  ///
  /// Any existing sequence or animation is smoothly interrupted when this is
  /// called.
  TickerFuture playSequence(
    PhaseSequence<P, T> sequence, {
    P? atPhase,
    void Function(P phase)? onPhaseChanged,
  }) {
    // Stop any existing sequence
    _stopSequence();

    if (sequence.phases.isEmpty) {
      return TickerFuture.complete();
    }

    // Initialize sequence state
    _activeSequence = sequence;
    _onSequencePhaseChanged = onPhaseChanged;
    _isPlayingSequence = true;
    _sequenceDirection = 1;

    // Determine target phase
    final targetPhase = atPhase ?? sequence.phases.first;
    _currentSequencePhaseIndex = sequence.phases.indexOf(targetPhase);

    if (_currentSequencePhaseIndex == -1) {
      throw ArgumentError('Phase $targetPhase not found in sequence');
    }

    // Start the sequence by animating to the target phase
    _currentAnimationFuture = super.animateTo(
      sequence.valueForPhase(targetPhase),
    );
    _currentSequencePhase = targetPhase;
    _onSequencePhaseChanged?.call(targetPhase);
    
    // Set motion for the target phase  
    motion = sequence.motionForPhase(targetPhase);

    return _currentAnimationFuture!;
  }

  /// Stops any active sequence (internal method).
  void _stopSequence() {
    if (!_isPlayingSequence) return;

    _isPlayingSequence = false;
    _currentSequencePhase = null;
    _onSequencePhaseChanged = null;

    _currentAnimationFuture = null;
    _activeSequence = null;
  }

  /// Animates to a specific phase in the active sequence.
  void _animateToPhaseInSequence(P phase) {
    if (!_isPlayingSequence || _activeSequence == null) return;

    final sequence = _activeSequence!;
    _currentSequencePhase = phase;

    // Notify phase change
    _onSequencePhaseChanged?.call(phase);

    // Get motion and target for this phase
    final phaseMotion = sequence.motionForPhase(phase);
    final targetValue = sequence.valueForPhase(phase);

    // Update motion for this phase
    motion = phaseMotion;

    // Animate to the phase (preserves current velocity for smooth transition)
    _currentAnimationFuture = super.animateTo(targetValue);
  }

  /// Handles sequence progression when a phase animation completes.
  void _handleSequencePhaseCompletion() {
    if (!_isPlayingSequence || _activeSequence == null) {
      return;
    }

    final sequence = _activeSequence!;
    final totalPhases = sequence.phases.length;

    // Determine next phase index
    var nextIndex = _currentSequencePhaseIndex + _sequenceDirection;

    // Handle sequence boundaries
    if (nextIndex >= totalPhases) {
      // Reached end of sequence
      switch (sequence.loopMode) {
        case PhaseLoopMode.none:
          _completeSequence();
          return;

        case PhaseLoopMode.loop:
          nextIndex = 0;

        case PhaseLoopMode.seamless:
          // Jump to start without animation
          nextIndex = 0;
          _jumpToSequencePhase(nextIndex);
          return;

        case PhaseLoopMode.pingPong:
          _sequenceDirection = -1;
          nextIndex = totalPhases - 2;
          if (nextIndex < 0) nextIndex = 0;
      }
    } else if (nextIndex < 0) {
      // Reached start during ping-pong reverse
      _sequenceDirection = 1;
      nextIndex = 1;
      if (nextIndex >= totalPhases) nextIndex = totalPhases - 1;
    }

    _currentSequencePhaseIndex = nextIndex;

    // Continue to next phase
    final nextPhase = sequence.phases[nextIndex];
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isPlayingSequence) {
        _animateToPhaseInSequence(nextPhase);
      }
    });
  }

  /// Completes the current sequence and stops playback.
  void _completeSequence() {
    _isPlayingSequence = false;
    _currentSequencePhase = null;
    _activeSequence = null;
    _onSequencePhaseChanged = null;
    _currentAnimationFuture = null;
  }

  /// Jumps to a sequence phase without animation (for seamless looping).
  void _jumpToSequencePhase(int phaseIndex) {
    if (_activeSequence == null) return;

    final sequence = _activeSequence!;
    final phase = sequence.phases[phaseIndex];
    final targetValue = sequence.valueForPhase(phase);

    // Set value without animation
    value = targetValue;

    _currentSequencePhaseIndex = phaseIndex;
    _currentSequencePhase = phase;

    // Notify phase change
    _onSequencePhaseChanged?.call(phase);

    // Continue sequence after a frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isPlayingSequence) {
        _handleSequencePhaseCompletion();
      }
    });
  }

  @override
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  }) {
    // Stop any active sequence when a manual animateTo is called
    _stopSequence();

    // Call parent implementation
    return super.animateTo(
      target,
      from: from,
      withVelocity: withVelocity,
    );
  }

  @override
  TickerFuture stop({bool canceled = false}) {
    // Stop sequence when animation is stopped
    _stopSequence();

    // Call parent implementation
    return super.stop(canceled: canceled);
  }

  @override
  void dispose() {
    _stopSequence();
    removeStatusListener(_onStatusChanged);
    super.dispose();
  }

  /// Internal status listener to handle sequence progression.
  void _onStatusChanged(AnimationStatus status) {
    // When animation completes, handle sequence progression
    if (!status.isAnimating && _isPlayingSequence) {
      _handleSequencePhaseCompletion();
    }
  }
}
