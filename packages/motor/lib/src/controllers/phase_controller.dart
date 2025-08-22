import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/phase_sequence.dart';

/// The mode in which the phase animation should loop.
enum PhaseLoopMode {
  /// Don't loop the animation.
  none,

  /// The animation will loop from the last phase back to the first phase.
  loop,

  /// The animation will play forward and then reverse back to the start.
  pingPong;

  /// Whether the animation should loop.
  bool get isLooping => this == loop || this == pingPong;
}

/// {@template PhaseController}
/// A controller that manages transitions between phases in a [PhaseSequence].
///
/// This controller uses Motor's [MotionController] internally to animate
/// between phase property values using physics-based or duration-based motion.
/// {@endtemplate}
class PhaseController<T extends Object, P> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// {@macro PhaseController}
  PhaseController({
    required this.sequence,
    required this.converter,
    required TickerProvider vsync,
    Motion? motion,
    List<Motion>? motionPerPhase,
    this.onPhaseChanged,
    PhaseLoopMode loopMode = PhaseLoopMode.loop,
  })  : assert(
          motion != null || motionPerPhase != null,
          'Either motion or motionPerPhase must be provided',
        ),
        assert(
          motionPerPhase == null ||
              motionPerPhase.length == sequence.phases.length,
          'motionPerPhase length must match the number of phases',
        ),
        _motion = motion,
        _motionPerPhase = motionPerPhase {
    _motionController = MotionController<T>(
      motion: _getMotionForCurrentPhase(),
      vsync: vsync,
      converter: converter,
      initialValue: sequence.valueForPhase(sequence.initialPhase),
    );

    _loopMode = loopMode;
    _currentPhase = sequence.initialPhase;
    _isForward = true;

    _motionController
      ..addListener(_onMotionControllerUpdate)
      ..addStatusListener(_onMotionControllerStatusChange);
  }

  /// The phase sequence this controller manages.
  final PhaseSequence<T, P> sequence;

  /// Converter for interpolating between property values.
  final MotionConverter<T> converter;

  /// Called when the phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// The default motion to use for phase transitions.
  final Motion? _motion;

  /// Per-phase motions for custom transition behavior.
  final List<Motion>? _motionPerPhase;

  late final MotionController<T> _motionController;

  /// The current phase.
  P get currentPhase => _currentPhase;
  late P _currentPhase;

  /// The current phase index in the sequence.
  int get currentPhaseIndex => _currentPhaseIndex;
  int _currentPhaseIndex = 0;

  @override
  T get value => _motionController.value;

  @override
  bool get isAnimating => _motionController.isAnimating;

  bool get _isInFirstPhase => _currentPhaseIndex == 0;

  bool get _isInLastPhase => _currentPhaseIndex == sequence.phases.length - 1;

  @override
  AnimationStatus get status =>
      switch ((_playing, _isForward, _isInFirstPhase, _isInLastPhase)) {
        (true, true, _, _) ||
        (false, true, false, false) =>
          AnimationStatus.forward,
        (true, false, _, _) ||
        (false, false, false, false) =>
          AnimationStatus.reverse,
        (false, _, true, _) => AnimationStatus.dismissed,
        (false, _, _, true) => AnimationStatus.completed,
      };

  /// The current velocity of the animation.
  T get velocity => _motionController.velocity;

  /// Direction of auto-loop progression (true = forward, false = reverse).
  bool _isForward = true;

  /// Timer for auto-looping phases.
  bool _playing = false;

  PhaseLoopMode _loopMode = PhaseLoopMode.loop;

  /// The manner in which the phase animation should loop.
  PhaseLoopMode get loopMode => _loopMode;
  set loopMode(PhaseLoopMode mode) {
    _loopMode = mode;
    if (!_canAdvance) {
      _playing = false; // Stop auto-looping if set to none
      notifyListeners();
    }
  }

  /// Moves to the next phase in the sequence.
  void nextPhase() {
    if (_currentPhaseIndex >= sequence.phases.length - 1) {
      // At the last phase we loop back if desired
      if (_loopMode == PhaseLoopMode.loop) {
        _goToPhaseIndex(0);
      }
    } else {
      _goToPhaseIndex(_currentPhaseIndex + 1);
    }
  }

  /// Moves to the previous phase in the sequence.
  void previousPhase() {
    if (_currentPhaseIndex <= 0) {
      // At the first phase we loop around if desired
      if (_loopMode == PhaseLoopMode.loop) {
        _goToPhaseIndex(sequence.phases.length - 1);
      }
    } else {
      _goToPhaseIndex(_currentPhaseIndex - 1);
    }
  }

  /// Moves directly to the specified phase.
  void goToPhase(P phase) {
    final index = sequence.phases.indexOf(phase);
    if (index == -1) {
      throw ArgumentError('Phase $phase not found in sequence');
    }
    _goToPhaseIndex(index);
  }

  bool get _canAdvance => _hasMorePhases || _loopMode.isLooping;

  bool get _hasMorePhases => _currentPhaseIndex < sequence.phases.length - 1;

  /// Starts the phase animation sequence.
  ///
  /// If [loopMode] is enabled, this will begin automatic phase progression.
  void start() {
    if (!_playing) {
      // If we don't loop and we don't have phases left, do nothing
      if (!_canAdvance) {
        return;
      }

      _playing = true;
      notifyListeners();

      // Start the first animation immediately
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_playing && _canAdvance) {
          nextPhase();
        }
      });
    }
  }

  /// Stops the phase animation sequence.
  ///
  /// This will stop any ongoing animations and cancel auto-loop scheduling.
  void stop() {
    _playing = false;
    notifyListeners();

    _motionController.stop();
  }

  /// Resets the sequence to the initial phase.
  void reset() {
    _isForward = true;
    notifyListeners();
    _goToPhaseIndex(0);
  }

  /// Disposes of the controller and frees resources.
  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  /// Moves to the phase at the specified index.
  void _goToPhaseIndex(int index) {
    if (index < 0 || index >= sequence.phases.length) {
      return;
    }

    final newPhase = sequence.phases[index];
    _currentPhase = newPhase;
    _currentPhaseIndex = index;

    // Update motion controller's motion if we have per-phase motions
    _motionController.motion = _getMotionForCurrentPhase();

    // Animate to the new phase's property value
    final targetValue = sequence.valueForPhase(newPhase);
    _motionController.animateTo(targetValue);

    // Notify listeners of phase change
    onPhaseChanged?.call(newPhase);
  }

  /// Returns the motion to use for the current phase transition.
  Motion _getMotionForCurrentPhase() {
    if (_motionPerPhase != null) {
      return _motionPerPhase[_currentPhaseIndex];
    }
    return _motion!;
  }

  /// Schedules the next automatic phase transition.
  void _scheduleNextPhase() {
    if (!_canAdvance || !_playing) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_canAdvance || !_playing) return;

      // Move to next phase
      if (_isForward) {
        nextPhase();
      } else {
        previousPhase();
      }
    });
  }

  /// Called when the underlying motion controller updates.
  void _onMotionControllerUpdate() {
    notifyListeners();
  }

  /// Called when the underlying motion controller's status changes.
  void _onMotionControllerStatusChange(AnimationStatus status) {
    if (status.isAnimating) return;

    // The current phase has completed

    if (!_canAdvance) {
      _playing = false;
      notifyListeners();
      return;
    }
    if (_loopMode == PhaseLoopMode.pingPong &&
        (_isInFirstPhase || _isInLastPhase)) {
      _isForward = !_isForward;
    }

    _scheduleNextPhase();
  }
}
