import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/phase_sequence.dart';

/// {@template PhaseController}
/// A controller that manages transitions between phases in a [PhaseSequence].
///
/// This controller uses Motor's [MotionController] internally to animate
/// between phase property values using physics-based or duration-based motion.
/// {@endtemplate}
class PhaseController<P, T extends Object> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// {@macro PhaseController}
  PhaseController({
    required PhaseSequence<P, T> sequence,
    required this.converter,
    required TickerProvider vsync,
    this.onPhaseChanged,
  }) : _sequence = sequence {
    _motionController = MotionController<T>(
      motion: sequence.motionForPhase(sequence.initialPhase),
      vsync: vsync,
      converter: converter,
      initialValue: sequence.valueForPhase(sequence.initialPhase),
    );

    _currentPhase = sequence.initialPhase;
    _isForward = true;

    _motionController
      ..addListener(_onMotionControllerUpdate)
      ..addStatusListener(_onMotionControllerStatusChange);
  }

  PhaseSequence<P, T> _sequence;

  /// The phase sequence this controller manages.
  PhaseSequence<P, T> get sequence => _sequence;

  set sequence(PhaseSequence<P, T> value) {
    if (_sequence == value) return;
    _sequence = value;

    // Find the current phase in the new sequence
    final currentPhaseInNewSequence = _sequence.phases.contains(_currentPhase)
        ? _currentPhase
        : _sequence.initialPhase;

    // Update current phase index to match the new sequence
    _currentPhaseIndex = _sequence.phases.indexOf(currentPhaseInNewSequence);
    _currentPhase = currentPhaseInNewSequence;

    // Update the motion controller's motion
    _motionController.motion = _sequence.motionForPhase(_currentPhase);

    // Smoothly animate to the new sequence's value for the current phase
    final targetValue = _sequence.valueForPhase(_currentPhase);
    _motionController.animateTo(targetValue);

    // Notify listeners of potential phase change
    onPhaseChanged?.call(_currentPhase);
  }

  /// Converter for interpolating between property values.
  final MotionConverter<T> converter;

  /// Called when the phase changes.
  final void Function(P phase)? onPhaseChanged;

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

  PhaseLoopMode get _loopMode => _sequence.loopMode;

  bool get _canAdvance => _hasMorePhases || _loopMode.isLooping;

  bool get _hasMorePhases => _currentPhaseIndex < sequence.phases.length - 1;

  /// Moves to the next phase in the sequence.
  void nextPhase() {
    if (_currentPhaseIndex >= sequence.phases.length - 1) {
      // At the last phase we loop back if desired
      if (_loopMode == PhaseLoopMode.loop) {
        _goToPhaseIndex(0);
      } else if (_loopMode == PhaseLoopMode.seamless) {
        _goToPhaseIndex(0, animate: false);
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
      } else if (_loopMode == PhaseLoopMode.seamless) {
        _goToPhaseIndex(sequence.phases.length - 1, animate: false);
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

  /// Jumps directly to the specified phase without animation.
  void jumpToPhase(P phase) {
    final index = sequence.phases.indexOf(phase);
    if (index == -1) {
      throw ArgumentError('Phase $phase not found in sequence');
    }
    _goToPhaseIndex(index, animate: false);
  }

  /// Starts the phase animation sequence.
  ///
  /// If the sequence's loop mode is enabled, this will begin automatic phase
  /// progression.
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

    if (currentPhaseIndex != 0) {
      _goToPhaseIndex(0);
    }
  }

  /// Disposes of the controller and frees resources.
  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  /// Moves to the phase at the specified index.
  void _goToPhaseIndex(int index, {bool animate = true}) {
    if (index < 0 || index >= sequence.phases.length) {
      return;
    }

    final newPhase = sequence.phases[index];
    _currentPhase = newPhase;
    _currentPhaseIndex = index;

    // Update motion controller's motion if we have per-phase motions
    _motionController.motion = sequence.motionForPhase(newPhase);

    // Animate to the new phase's property value
    final targetValue = sequence.valueForPhase(newPhase);
    if (animate) {
      _motionController.animateTo(targetValue);
    } else {
      _motionController.value = targetValue;
      if (_playing) {
        // Start the first animation immediately
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_playing && _canAdvance) {
            nextPhase();
          }
        });
      }
    }

    // Notify listeners of phase change
    onPhaseChanged?.call(newPhase);
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
