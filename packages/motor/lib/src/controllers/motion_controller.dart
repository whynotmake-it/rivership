import 'dart:collection';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show objectRuntimeType;
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/single_motion_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/motion_sequence.dart';
import 'package:motor/src/motion_velocity_tracker.dart';
import 'package:motor/src/phase_transition.dart';

/// A base [MotionController] that can manage a [Motion] of any value that you
/// can pass a [MotionConverter] for.
///
/// In a lot of ways, this class works like [AnimationController], but a few key
/// differences have been made to make it generalize easier for different types
/// of motion.
///
/// 1. [status] behavior depends on the [MotionConverter]:
///   - If the converter is directional (e.g. [SingleMotionConverter]), [status]
///     will report [AnimationStatus.forward] or [AnimationStatus.reverse]
///     appropriately.
///   - For non-directional converters (common for multi-dimensional types),
///     [status] will always be [AnimationStatus.forward] while animating.
///   - When stopped, it generally returns [AnimationStatus.completed] unless
///     at the initial value (or lower bound), where it returns
///     [AnimationStatus.dismissed].
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
///   * [SequenceMotionController] for a version that can play
///     [MotionSequence]s.
class MotionController<T extends Object> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a motion controller with a single motion for all dimensions.
  ///
  /// Velocity tracking is enabled by default to track velocity when manually
  /// setting [value]. Use [VelocityTracking.off] to disable.
  MotionController({
    required Motion motion,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
    VelocityTracking velocityTracking = const VelocityTracking.on(),
  }) : this._(
          motionPerDimension: List.filled(
            converter.normalize(initialValue).length,
            motion,
          ),
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
          velocityTracking: velocityTracking,
        );

  /// Creates a motion controller with individual motions per dimension.
  MotionController.motionPerDimension({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
    VelocityTracking velocityTracking = const VelocityTracking.on(),
  }) : this._(
          motionPerDimension: motionPerDimension,
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
          velocityTracking: velocityTracking,
        );

  MotionController._({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
    VelocityTracking velocityTracking = const VelocityTracking.on(),
  })  : assert(
          converter.normalize(initialValue).isNotEmpty,
          'normalizing all given values must result in a non-empty list',
        ),
        _converter = converter,
        _velocityTrackerBuilder = velocityTracking.call {
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

    // Initialize velocity tracker
    _velocityTracker = velocityTracking.call(converter);
  }

  late final T _initialValue;

  MotionConverter<T> _converter;

  set converter(MotionConverter<T> value) {
    if (value == _converter) return;

    final normalized = value.normalize(value.denormalize(_currentValues));
    assert(
      normalized.length == _dimensions,
      'new converter must have the same number of dimensions as the '
      'previous converter',
    );

    _converter = value;
    // Recreate velocity tracker with new converter if tracking is enabled
    _velocityTracker = _velocityTrackerBuilder?.call(value);
    _internalSetValue(normalized);
  }

  /// Converts the value of type T to a List<double> for internal processing.
  MotionConverter<T> get converter => _converter;

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

  /// The normalized target values for each dimension when animating.
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
  ///
  /// When velocity tracking is enabled (the default), this tracks the value
  /// for velocity estimation. The tracked velocity is used when [animateTo]
  /// is called without explicit velocity, and is available via [velocity].
  set value(T newValue) {
    _ticker?.stop();
    _status = _getStatusWhenDone();

    final normalized = converter.normalize(newValue);
    _internalSetValue(normalized);

    // Track velocity sample if tracker is available
    _trackVelocitySample(newValue);

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
  /// This reports [AnimationStatus.forward] or [AnimationStatus.reverse] based
  /// on the directionality defined by the [converter].
  ///
  /// If the [converter] is not a [DirectionalMotionConverter], this will always
  /// report [AnimationStatus.forward] while animating.
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
  ///
  /// When animating, this returns the velocity from the active simulation.
  /// When not animating, this returns the tracked velocity from user input
  /// if a velocity tracker is available, otherwise zeros.
  List<double> get velocities {
    if (isAnimating) {
      return [
        for (var i = 0; i < _dimensions; i++)
          _simulations[i].dx(_lastElapsedDuration!.toSec()),
      ];
    }

    // Return tracked velocity if available, otherwise zeros
    return _trackedVelocities;
  }

  /// The type-specific velocity representation.
  ///
  /// When animating, this returns the velocity from the active simulation.
  /// When not animating, this returns the tracked velocity from user input
  /// if a velocity tracker is available, otherwise the zero value for type T.
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

  /// Function that creates a [MotionVelocityTracker], or null if disabled.
  final MotionVelocityTracker<T>? Function(MotionConverter<T> converter)?
      _velocityTrackerBuilder;

  MotionVelocityTracker<T>? _velocityTracker;

  /// Stopwatch for tracking elapsed time for velocity samples.
  Stopwatch? _velocityStopwatch;

  Stopwatch get _velocityTime {
    _velocityStopwatch ??= Stopwatch()..start();
    return _velocityStopwatch!;
  }

  /// Tracks a velocity sample for the given value.
  ///
  /// Called automatically when [value] is set. No-op if velocity tracking
  /// is disabled.
  void _trackVelocitySample(T value) {
    if (_velocityTracker case final tracker?) {
      tracker.addPosition(_velocityTime.elapsed, value);
    }
  }

  /// Returns the tracked velocity estimate from user input.
  ///
  /// Returns `null` if no velocity tracker is available or no samples have
  /// been recorded.
  MotionVelocityEstimate<T>? get trackedVelocityEstimate =>
      _velocityTracker?.getVelocityEstimate();

  /// The tracked velocity in normalized form (List<double>), or zeros if
  /// no tracked velocity is available.
  List<double> get _trackedVelocities {
    if (_velocityTracker?.getVelocityEstimate() case final estimate?) {
      return converter.normalize(estimate.perSecond);
    }
    return List.filled(_dimensions, 0.0);
  }

  /// Resets the velocity tracker, clearing all tracked samples.
  ///
  /// Called automatically when animations start via [animateTo].
  void _resetVelocityTracking() {
    _velocityTracker = _velocityTrackerBuilder?.call(converter);
    _velocityStopwatch?.reset();
  }

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
        forward: converter.motionIsForward(from: from ?? value, to: target),
      );

  TickerFuture _animateToInternal({
    required List<double> target,
    List<double>? from,
    List<double>? velocity,
    bool forward = true,
  }) {
    _target = target;

    final fromValue = from ?? List.of(_currentValues);
    // Use provided velocity, or fall back to current velocities (which may
    // include tracked velocity from user input when not animating)
    final velocityValue = velocity ?? velocities;
    // Reset velocity tracking since we're starting an animation
    // This ensures fresh tracking when the animation ends
    _resetVelocityTracking();

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
  AnimationStatus _getStatusWhenDone() => switch (_target) {
        final v? when converter.denormalize(v) == _initialValue =>
          AnimationStatus.dismissed,
        _ => AnimationStatus.completed
      };

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
    super.velocityTracking,
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
    super.velocityTracking,
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
  /// The value is clamped to be within bounds. When velocity tracking is
  /// enabled (the default), this also tracks the value for velocity estimation.
  @override
  set value(T newValue) {
    final normalized = converter.normalize(newValue);
    _status = _getStatusWhenDone();
    final clamped = [
      for (final (i, v) in normalized.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];
    _internalSetValue(clamped);

    // Track velocity sample if tracker is available
    _trackVelocitySample(newValue);

    notifyListeners();
  }

  bool _forward = true;

  /// Evaluates the current status when we're at the end of the animation.
  @override
  AnimationStatus _getStatusWhenDone() => switch (_target) {
        final v? when converter.denormalize(v) == lowerBound =>
          AnimationStatus.dismissed,
        final v? when converter.denormalize(v) == upperBound =>
          AnimationStatus.completed,
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
  /// **Note**: [status] might still return [AnimationStatus.forward] when
  /// this is called, depending on the directionality of [converter].
  /// See [status] for more information.
  TickerFuture reverse({
    T? from,
    T? withVelocity,
  }) {
    return animateTo(
      lowerBound,
      from: from,
      withVelocity: withVelocity,
    );
  }

  @override
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  }) {
    final clamped = _clamp(target);

    _forward = converter.motionIsForward(
      from: from ?? value,
      to: clamped,
    );

    return _animateToDirectional(
      target,
      from: from,
      withVelocity: withVelocity,
      forward: _forward,
    );
  }

  /// Clamps [value] within the bounds of this controller.
  T _clamp(T value) {
    final normalized = converter.normalize(value);
    final clamped = [
      for (final (i, v) in normalized.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];
    return converter.denormalize(clamped);
  }

  TickerFuture _animateToDirectional(
    T target, {
    required bool forward,
    T? from,
    T? withVelocity,
  }) {
    final normalizedTarget = converter.normalize(target);
    final clamped = [
      for (final (i, v) in normalizedTarget.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];

    return _animateToInternal(
      target: clamped,
      from: from != null ? converter.normalize(from) : null,
      velocity: withVelocity != null ? converter.normalize(withVelocity) : null,
      forward: _forward,
    );
  }

  @override
  TickerFuture stop({bool canceled = false}) {
    if (canceled || _motionPerDimension.every((e) => !e.needsSettle)) {
      _stopTicker(canceled: canceled);
      return TickerFuture.complete();
    } else {
      return _animateToDirectional(_clamp(value), forward: _forward);
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
class SequenceMotionController<P, T extends Object>
    extends MotionController<T> {
  /// Creates a phase motion controller with single motion for all dimensions.
  SequenceMotionController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
    super.velocityTracking,
  });

  /// Creates a sequence motion controller with motion per dimension.
  SequenceMotionController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
    super.velocityTracking,
  }) : super.motionPerDimension();

  /// Active phase sequence being played
  MotionSequence<P, T>? _activeSequence;

  /// Current phase index in the sequence
  int _currentSequencePhaseIndex = 0;

  /// Direction for ping-pong sequences (1 = forward, -1 = reverse)
  int _sequenceDirection = 1;

  /// Callback for phase transition changes
  void Function(PhaseTransition<P> transition)? _onPhaseTransition;

  /// Whether we're currently playing a sequence
  bool _isPlayingSequence = false;

  /// Target phase we're currently animating toward
  P? _currentSequencePhase;

  /// The previous phase we're transitioning from
  P? _previousSequencePhase;

  /// The elapsed time when the current phase started
  Duration? _currentPhaseStartTime;

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
    // Stop any existing sequence by stopping underlying animation
    _stopSequence();

    if (sequence.phases.isEmpty) {
      return TickerFuture.complete();
    }

    // Initialize sequence state
    _activeSequence = sequence;
    _onPhaseTransition = onTransition;
    _isPlayingSequence = true;
    _sequenceDirection = 1;

    // Determine target phase
    final targetPhase = atPhase ?? sequence.initialPhase;
    _currentSequencePhaseIndex = sequence.phases.indexOf(targetPhase);

    if (_currentSequencePhaseIndex == -1) {
      throw ArgumentError('Phase $targetPhase not found in sequence');
    }

    final velocities = switch (withVelocity) {
      null => this.velocities,
      final v => converter.normalize(v),
    };

    // Set up the initial phase simulation
    _setupPhaseSimulation(targetPhase, velocities);

    // Stop any existing ticker and start fresh
    _stopTicker(canceled: true);
    _lastElapsedDuration = Duration.zero;
    _currentPhaseStartTime = Duration.zero;
    final tickerFuture = _ticker!.start();
    _status = AnimationStatus.forward;
    _checkStatusChanged();

    // Notify phase transition (starting animation to target phase)
    final previousPhase = _previousSequencePhase;
    if (previousPhase != null) {
      _onPhaseTransition?.call(
        PhaseTransitioning(
          from: previousPhase,
          to: targetPhase,
        ),
      );
    }

    return tickerFuture;
  }

  /// Sets up simulations for transitioning to a specific phase
  void _setupPhaseSimulation(P phase, List<double> velocities) {
    if (!_isPlayingSequence || _activeSequence == null) return;

    final sequence = _activeSequence!;
    _previousSequencePhase = _currentSequencePhase;
    _currentSequencePhase = phase;

    // Get motion and target for this phase, using the previous phase context
    final motion = sequence.motionForPhase(
      toPhase: phase,
      fromPhase: _previousSequencePhase,
    );
    final targetValue = sequence.valueForPhase(phase);
    final target = converter.normalize(targetValue);

    // Set target for sequence tracking
    _target = target;

    // Create simulations for this phase, preserving current velocity
    final velocityValue = velocities;
    _simulations = [
      for (var i = 0; i < _dimensions; i++)
        motion.createSimulation(
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
    _previousSequencePhase = null;
    _onPhaseTransition = null;
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
      _handleSequencePhaseCompletion(velocities);
    }

    notifyListeners();
    _checkStatusChanged();
  }

  /// Handles sequence progression when a phase animation completes.
  void _handleSequencePhaseCompletion(List<double> velocities) {
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
      switch (sequence.loop) {
        case LoopMode.none:
          _completeSequence();
          return;

        case LoopMode.loop:
          nextIndex = 0;

        case LoopMode.seamless:
          // Jump to start without animation
          nextIndex = 0;
          _jumpToSequencePhase(nextIndex);
          return;

        case LoopMode.pingPong:
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
    _setupPhaseSimulation(nextPhase, velocities);
    final previousPhase = _previousSequencePhase;
    if (previousPhase != null) {
      _onPhaseTransition?.call(
        PhaseTransitioning(
          from: previousPhase,
          to: nextPhase,
        ),
      );
    }
  }

  /// Completes the current sequence and stops playback.
  void _completeSequence() {
    final finalPhase = _currentSequencePhase;

    _isPlayingSequence = false;
    _currentSequencePhase = null;
    _previousSequencePhase = null;

    _activeSequence = null;

    // Notify that we've settled at the final phase
    if (finalPhase != null) {
      _onPhaseTransition?.call(PhaseSettled(finalPhase));
    }
    _onPhaseTransition = null;

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
    _onPhaseTransition?.call(PhaseSettled(phase));

    // Immediately continue with the next phase
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isPlayingSequence) {
        _handleSequencePhaseCompletion(velocities);
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

extension<T> on MotionConverter<T> {
  bool motionIsForward({required T from, required T to}) {
    if (this case final DirectionalMotionConverter<T> directional) {
      return switch (directional.compare(from, to)) {
        > 0 => false,
        _ => true,
      };
    }

    // Always consider motion forward for non-directional converters
    return true;
  }
}
