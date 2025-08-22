import 'dart:collection';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/src/controllers/single_motion_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/phase_sequence.dart';

/// A base [MotionController] that can manage a [Motion] of any value that you
/// can pass a [MotionConverter] for.
///
/// In a lot of ways, this class works like [AnimationController], but a few key
/// differences have been made to make it generalize easier for different types
/// of motion.
///
/// 1. [status] works differently for unbounded controllers:
///   - It will always return [AnimationStatus.forward] if the controller is
///     running.
///   - It will return [AnimationStatus.dismissed] if the controller is stopped
///     and at its initial value.
///   - It will return [AnimationStatus.completed] if the controller is stopped
///     and not at its initial value.
///   - Note: [BoundedMotionController]s restore a concept of directionality,
///     and will return [AnimationStatus.reverse] in certain cases.
/// 2. [stop] will not stop the animation right away, unless `canceled` is true.
///   Instead, it will wait until the simulation is done, and then settle at
///   the current value. This allows for a more graceful stop, for example, a
///   bouncy spring will perform its overshoot.
///
/// See also:
///   * [BoundedMotionController] for a version that adds bounds, as well as
///     `forward` and `reverse` methods to the controller.
///   * [SingleMotionController] and [BoundedSingleMotionController] for a one-
///     dimensional version of this class. These are most closely related to
///     [AnimationController]s.
class MotionController<T extends Object> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a [MotionController] with the given parameters and a single motion
  /// that is used for all dimensions.
  ///
  /// The [motion] parameter defines the characteristics of the motion
  /// and the [vsync] parameter is required to drive the animation.
  MotionController({
    required Motion motion,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  }) : this._(
          motionPerDimension: List.filled(
            converter.normalize(initialValue).length,
            motion,
          ),
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
        );

  /// Creates a [MotionController] with the given parameters and a list of
  /// motions for each dimension.
  MotionController.motionPerDimension({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  }) : this._(
          motionPerDimension: motionPerDimension,
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
        );

  MotionController._({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required this.converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  }) : assert(
          converter.normalize(initialValue).isNotEmpty,
          'normalizing all given values must result in a non-empty list',
        ) {
    _initialValue = initialValue;
    final normalized = converter.normalize(initialValue);
    _motionPerDimension = motionPerDimension;
    _dimensions = normalized.length;

    // Initialize the values and velocities
    _currentValues = List.of(normalized);

    // Create the ticker
    _ticker = vsync.createTicker(_tick);

    // Initialize status based on its position relative to bounds
    _animationBehavior = behavior;

    // Initialize with a dismissed status by default
    _status = AnimationStatus.dismissed;
  }

  late final T _initialValue;

  /// Converts the value of type T to a List<double> for internal processing.
  final MotionConverter<T> converter;

  /// Number of dimensions being animated
  late final int _dimensions;

  /// The motion style controlling the animation characteristics.
  late List<Motion> _motionPerDimension;

  /// The current values for each dimension
  late List<double> _currentValues;

  /// The amount of time that has passed between the time the animation started
  /// and the most recent tick of the animation.
  ///
  /// If the controller is not animating, the last elapsed duration is null.
  Duration? get lastElapsedDuration => _lastElapsedDuration;
  Duration? _lastElapsedDuration;

  /// The ticker that drives the animation
  Ticker? _ticker;

  /// The target values for each dimension when animating.
  List<double>? _target;

  /// List of simulations, one for each dimension
  List<Simulation> _simulations = [];

  /// The current status of the animation
  late AnimationStatus _status;

  /// The animation behavior
  late final AnimationBehavior _animationBehavior;

  /// The current value of this animation.
  @override
  T get value => converter.denormalize(_currentValues);

  /// Sets the current value of the animation.
  set value(T newValue) {
    _ticker?.stop();
    _status = _getStatusWhenDone();

    final normalized = converter.normalize(newValue);
    _internalSetValue(normalized);
    notifyListeners();
    _checkStatusChanged();
  }

  /// Updates the internal values array
  void _internalSetValue(List<double> newValues) {
    assert(
      newValues.length == _dimensions,
      'New values must have the same number of dimensions as the controller',
    );

    _currentValues = List.of(newValues);
  }

  /// The current status of this [Animation].
  ///
  /// Spring simulations don't really have a concept of directionality,
  /// especially in higher dimensions.
  /// Thus, this will never return [AnimationStatus.reverse].
  @override
  AnimationStatus get status => _status;

  /// Whether this animation is currently animating in either the forward or
  /// reverse direction.
  @override
  bool get isAnimating => switch (_ticker) {
        null => false,
        Ticker(:final isActive) => isActive,
      };

  /// The current velocity of the simulation in units per second for each
  /// dimension.
  List<double> get velocities {
    if (!isAnimating) return List.filled(_dimensions, 0);

    return [
      for (var i = 0; i < _dimensions; i++)
        _simulations[i].dx(_lastElapsedDuration!.toSec()),
    ];
  }

  /// The type-specific velocity representation.
  T get velocity => converter.denormalize(velocities);

  /// The single motion that is used for all dimensions.
  ///
  /// This assumes that all motions in [motionPerDimension] are the same.
  Motion get motion {
    assert(
      motionPerDimension.every((e) => e == motionPerDimension.first),
      'tried to access a single motion in a '
      '${objectRuntimeType(this, 'MotionController')}, but not all motions '
      'per dimension are the same',
    );
    return motionPerDimension.first;
  }

  /// Sets the default motion to use for each dimension.
  set motion(Motion value) {
    _motionPerDimension = List.filled(_motionPerDimension.length, value);
    _redirectSimulation();
  }

  /// {@template MotionController.motionStyle}
  /// The current motion style
  ///
  /// When set, this will create a new simulation with the current velocity if
  /// an animation is in progress.
  /// {@endtemplate}
  List<Motion> get motionPerDimension => List.unmodifiable(_motionPerDimension);

  /// {@macro MotionController.motionStyle}
  set motionPerDimension(Iterable<Motion> value) {
    assert(
      value.length == _motionPerDimension.length,
      'the number of motions must match the number of dimensions',
    );
    if (motionsEqual(_motionPerDimension, value)) return;

    _motionPerDimension = value.toList();
    _redirectSimulation();
  }

  /// The behavior of the animation.
  ///
  /// Defaults to [AnimationBehavior.normal] for bounded, and
  /// [AnimationBehavior.preserve] for unbounded controllers.
  AnimationBehavior get animationBehavior => _animationBehavior;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider vsync) {
    final oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

  /// Animates towards [target], while ensuring that any current velocity is
  /// maintained.
  ///
  /// If [from] is provided, the animation will start from there instead of from
  /// the current [value].
  ///
  /// If [withVelocity] is provided, the animation will start with that velocity
  /// instead of [velocity].
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  }) =>
      _animateToInternal(
        target: converter.normalize(target),
        from: from != null ? converter.normalize(from) : null,
        velocity:
            withVelocity != null ? converter.normalize(withVelocity) : null,
      );

  TickerFuture _animateToInternal({
    required List<double> target,
    List<double>? from,
    List<double>? velocity,
    bool forward = true,
  }) {
    _target = target;

    final fromValue = from ?? List.of(_currentValues);
    final velocityValue = velocity ?? velocities;

    // Stop any existing animations
    _stopTicker(canceled: true);

    _simulations = [
      for (var i = 0; i < _dimensions; i++)
        _motionPerDimension[i].createSimulation(
          start: fromValue[i],
          end: target[i],
          velocity: velocityValue[i],
        ),
    ];

    _internalSetValue(_simulations.map((e) => e.x(0)).toList());
    _lastElapsedDuration = Duration.zero;
    final result = _ticker!.start();
    _status = forward ? AnimationStatus.forward : AnimationStatus.reverse;
    _checkStatusChanged();
    return result;
  }

  /// Evaluates the current status when we're at the end of the animation.
  AnimationStatus _getStatusWhenDone() => value == _initialValue
      ? AnimationStatus.dismissed
      : AnimationStatus.completed;

  /// Tick function called by the ticker
  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;

    final elapsedInSeconds = elapsed.toSec();

    assert(elapsedInSeconds >= 0, 'elapsed must be non-negative');

    _currentValues = [
      for (var i = 0; i < _dimensions; i++) _simulations[i].x(elapsedInSeconds),
    ];

    // Check if all simulations are done
    if (_simulations.every((e) => e.isDone(elapsedInSeconds))) {
      _status = _getStatusWhenDone();
      _stopTicker();
    }

    notifyListeners();
    _checkStatusChanged();
  }

  /// Redirect a motion when the [motionPerDimension] changes.
  void _redirectSimulation() {
    if (!isAnimating) return;

    if (_target case final target?) {
      animateTo(converter.denormalize(target));
    }
  }

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    if (_status != _lastReportedStatus) {
      _lastReportedStatus = _status;
      notifyStatusListeners(_status);
    }
  }

  /// Stops the current simulation, and depending on the value of [canceled],
  /// either settles the simulation at the current value, or interrupts the
  /// simulation immediately
  ///
  /// Unlike [AnimationController.stop], [canceled] defaults to false.
  /// If you set it to true, the simulation will be stopped immediately.
  /// Otherwise, the simulation will redirect to settle at the current value, if
  /// [Motion.needsSettle] is true for any [motionPerDimension].
  TickerFuture stop({bool canceled = false}) {
    if (canceled || _motionPerDimension.every((e) => !e.needsSettle)) {
      _stopTicker(canceled: canceled);
      return TickerFuture.complete();
    } else {
      return animateTo(value);
    }
  }

  void _stopTicker({bool canceled = false}) {
    _lastElapsedDuration = null;
    if (isAnimating) {
      _ticker?.stop(canceled: canceled);
    }
  }

  /// Frees any resources used by this object.
  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// A [MotionController] that is bounded.
///
/// See [MotionController] for more information.
///
/// {@template motor.MotionController.boundedExplainer}
/// This adds a [lowerBound] and [upperBound] to the controller, and will
/// automatically clamp the [value] to be within the bounds when setting
/// (although) it can still overshoot as part of the [motion]s that are used.
///
/// This also adds [forward] and [reverse] methods that will animate towards
/// the [lowerBound] and [upperBound] respectively.
///
/// Furthermore, [status] behaves differently for bounded controllers:
///   - It will return [AnimationStatus.reverse] when animating towards the
///     [lowerBound], and [AnimationStatus.forward] when animating towards the
///     [upperBound].
///   - [status] will return [AnimationStatus.dismissed] if the controller is
///     stopped and at its lower bound.
///   - [status] will return the last reported direction if the controller is
///     stopped and not at its lower or upper bound.
/// {@endtemplate}
class BoundedMotionController<T extends Object> extends MotionController<T> {
  /// Creates a [BoundedMotionController].
  BoundedMotionController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    required T lowerBound,
    required T upperBound,
    super.behavior,
  })  : _lowerBound = converter.normalize(lowerBound),
        _upperBound = converter.normalize(upperBound);

  /// Creates a [BoundedMotionController] with the given parameters and a list
  /// of motions for each dimension.
  BoundedMotionController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    required T lowerBound,
    required T upperBound,
    super.behavior,
  })  : _lowerBound = converter.normalize(lowerBound),
        _upperBound = converter.normalize(upperBound),
        super.motionPerDimension();

  /// The lower bounds for each dimension.
  final List<double> _lowerBound;

  /// The upper bounds for each dimension.
  final List<double> _upperBound;

  /// The lower bound of the animation value.
  /// The lower bound of the animation value.
  ///
  /// {@template motor.spring_simulation.bounds_overshoot_warning}
  /// **Note:** since springs can, and often will, overshoot, [value] is not
  /// guaranteed to be within [lowerBound] and [upperBound]. Make sure to clamp
  /// [value] upon consumption if necessary.
  /// {@endtemplate}
  T get lowerBound => converter.denormalize(_lowerBound);

  /// The upper bound of the animation value.
  ///
  /// {@macro motor.spring_simulation.bounds_overshoot_warning}
  T get upperBound => converter.denormalize(_upperBound);

  /// Sets the current value of the animation.
  ///
  /// This will clamp the value to be within the bounds.
  @override
  set value(T newValue) {
    final normalized = converter.normalize(newValue);
    _status = _getStatusWhenDone();
    final clamped = [
      for (final (i, v) in normalized.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];
    _internalSetValue(clamped);
    notifyListeners();
  }

  bool _forward = true;

  /// Evaluates the current status when we're at the end of the animation.
  @override
  AnimationStatus _getStatusWhenDone() => switch (value) {
        final v when v == lowerBound => AnimationStatus.dismissed,
        final v when v == upperBound => AnimationStatus.completed,
        _ when !_forward => AnimationStatus.reverse,
        _ => AnimationStatus.forward,
      };

  /// Animates towards [upperBound].
  TickerFuture forward({
    T? from,
    T? withVelocity,
  }) {
    return animateTo(
      upperBound,
      from: from,
      withVelocity: withVelocity,
    );
  }

  /// Animates towards [lowerBound].
  ///
  /// **Note**: [status] will still return [AnimationStatus.forward] when
  /// this is called. See [status] for more information.
  TickerFuture reverse({
    T? from,
    T? withVelocity,
  }) {
    return animateTo(
      lowerBound,
      from: from,
      withVelocity: withVelocity,
      forward: false,
    );
  }

  @override
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
    bool forward = true,
  }) {
    _forward = forward;
    final normalizedTarget = converter.normalize(target);
    final clamped = [
      for (final (i, v) in normalizedTarget.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];
    return _animateToInternal(
      target: clamped,
      from: from != null ? converter.normalize(from) : null,
      velocity: withVelocity != null ? converter.normalize(withVelocity) : null,
      forward: forward,
    );
  }

  @override
  TickerFuture stop({bool canceled = false}) {
    if (canceled || _motionPerDimension.every((e) => !e.needsSettle)) {
      _stopTicker(canceled: canceled);
      return TickerFuture.complete();
    } else {
      return animateTo(value, forward: _forward);
    }
  }
}

@internal
bool motionsEqual(Iterable<Motion>? a, Iterable<Motion>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;

  return a.length == b.length &&
      [for (final (i, m) in a.indexed) m == b.elementAt(i)].every((e) => e);
}

/// A MotionController specialized for playing phase sequences with type-safe
/// phase access.
///
/// This controller extends [MotionController] to provide reliable phase-based
/// animations with compile-time type safety and smooth transitions between
/// phases. This implementation uses the tick method for deterministic phase
/// progression instead of relying on animation status callbacks.
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
  });

  /// Creates a PhaseSequenceController with motion per dimension.
  PhaseSequenceController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  }) : super.motionPerDimension();

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

  /// The elapsed time when the current phase started
  Duration? _currentPhaseStartTime;

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

  /// Plays through a phase sequence starting from current value/velocity.
  ///
  /// Returns a [TickerFuture] that completes when sequence finishes
  /// (non-looping) or never completes for looping sequences.
  ///
  /// If [atPhase] is provided, the sequence will start by animating to that
  /// specific phase, then continue normal sequence progression.
  ///
  /// The [onPhaseChanged] callback is called whenever the animation transitions
  /// to a new phase.
  ///
  /// Any existing sequence or animation is interrupted when this is called.
  TickerFuture playSequence(
    PhaseSequence<P, T> sequence, {
    P? atPhase,
    void Function(P phase)? onPhaseChanged,
  }) {
    // Stop any existing sequence by stopping underlying animation
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

    // Set up the initial phase simulation
    _setupPhaseSimulation(targetPhase);

    // Stop any existing ticker and start fresh
    _stopTicker(canceled: true);
    _lastElapsedDuration = Duration.zero;
    _currentPhaseStartTime = Duration.zero;
    final tickerFuture = _ticker!.start();
    _status = AnimationStatus.forward;
    _checkStatusChanged();

    // Notify phase change
    _onSequencePhaseChanged?.call(targetPhase);

    return tickerFuture;
  }

  /// Sets up simulations for transitioning to a specific phase
  void _setupPhaseSimulation(P phase) {
    if (!_isPlayingSequence || _activeSequence == null) return;

    final sequence = _activeSequence!;
    _currentSequencePhase = phase;

    // Get motion and target for this phase
    final motion = sequence.motionForPhase(phase);
    final targetValue = sequence.valueForPhase(phase);
    final target = converter.normalize(targetValue);

    // Update motion for this phase
    this.motion = motion;

    // Set target for sequence tracking
    _target = target;

    // Create simulations for this phase, preserving current velocity
    final velocityValue = velocities;
    _simulations = [
      for (var i = 0; i < _dimensions; i++)
        _motionPerDimension[i].createSimulation(
          start: _currentValues[i],
          end: target[i],
          velocity: velocityValue[i],
        ),
    ];

    // Set the start time for this phase to the current elapsed time
    _currentPhaseStartTime = _lastElapsedDuration ?? Duration.zero;
  }

  /// Stops any active sequence (internal method)
  void _stopSequence() {
    if (!_isPlayingSequence) return;

    _isPlayingSequence = false;
    _currentSequencePhase = null;
    _onSequencePhaseChanged = null;
    _currentPhaseStartTime = null;

    _activeSequence = null;
  }

  @override
  void _tick(Duration elapsed) {
    if (_isPlayingSequence) {
      // Handle sequence animation manually
      _tickSequence(elapsed);
    } else {
      // Use parent implementation for normal animations
      super._tick(elapsed);
    }
  }

  /// Handles tick updates during sequence playback
  void _tickSequence(Duration elapsed) {
    _lastElapsedDuration = elapsed;

    // Calculate elapsed time for the current phase
    final phaseElapsed = elapsed - (_currentPhaseStartTime ?? Duration.zero);
    final phaseElapsedInSeconds = phaseElapsed.toSec();

    assert(phaseElapsedInSeconds >= 0, 'phase elapsed must be non-negative');

    // Update current values from simulations using phase-specific elapsed time
    _currentValues = [
      for (var i = 0; i < _dimensions; i++)
        _simulations[i].x(phaseElapsedInSeconds),
    ];

    // Check if current phase animation is done
    final currentPhaseComplete =
        _simulations.every((e) => e.isDone(phaseElapsedInSeconds));

    if (currentPhaseComplete && _isPlayingSequence) {
      // Current phase is complete, move to next phase
      _handleSequencePhaseCompletion();
    }

    notifyListeners();
    _checkStatusChanged();
  }

  /// Handles sequence progression when a phase animation completes.
  void _handleSequencePhaseCompletion() {
    if (!_isPlayingSequence || _activeSequence == null) {
      _completeSequence();
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

    // Set up next phase simulation and continue
    final nextPhase = sequence.phases[nextIndex];
    _setupPhaseSimulation(nextPhase);
    _onSequencePhaseChanged?.call(nextPhase);
  }

  /// Completes the current sequence and stops playback.
  void _completeSequence() {
    _isPlayingSequence = false;
    _currentSequencePhase = null;

    _activeSequence = null;
    _onSequencePhaseChanged = null;

    // Update status and stop ticker
    _status = _getStatusWhenDone();
    _stopTicker();
    _checkStatusChanged();
  }

  /// Jumps to a sequence phase without animation.
  void _jumpToSequencePhase(int phaseIndex) {
    if (_activeSequence == null) return;

    final sequence = _activeSequence!;
    final phase = sequence.phases[phaseIndex];
    final targetValue = sequence.valueForPhase(phase);

    // Set value without animation
    _internalSetValue(converter.normalize(targetValue));

    _currentSequencePhaseIndex = phaseIndex;
    _currentSequencePhase = phase;

    // Notify phase change
    _onSequencePhaseChanged?.call(phase);

    // Immediately continue with the next phase
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isPlayingSequence) {
        _handleSequencePhaseCompletion();
      }
    });
  }

  @override
  set value(T newValue) {
    // Stop any active sequence when value is set
    _stopSequence();
    
    // Call parent implementation
    super.value = newValue;
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
    super.dispose();
  }
}

extension on Duration {
  double toSec() => inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
}
