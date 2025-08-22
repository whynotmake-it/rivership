import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/phase_sequence.dart';

/// {@template PhaseController}
/// A controller that manages transitions between phases in a [PhaseSequence].
///
/// This controller uses Motor's [MotionController] internally to animate
/// between phase property values using physics-based or duration-based motion.
/// {@endtemplate}
class PhaseController<T extends Object, P> extends ChangeNotifier {
  /// {@macro PhaseController}
  PhaseController({
    required this.sequence,
    required this.converter,
    required TickerProvider vsync,
    Motion? motion,
    List<Motion>? motionPerPhase,
    this.onPhaseChanged,
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

    _currentPhase = sequence.initialPhase;
    _currentPhaseIndex = 0;
    _isForward = true;

    _motionController
      ..addListener(_onMotionControllerUpdate)
      ..addStatusListener(_onMotionControllerStatusChange);

    // Start auto-looping if enabled - start first phase transition
    if (sequence.autoLoop) {
      _autoLoopScheduled = true;

      // Start the first animation immediately to get things moving
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_autoLoopScheduled &&
            sequence.autoLoop &&
            sequence.phases.length > 1) {
          nextPhase();
        }
      });
    }
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

  /// The current interpolated property value.
  T get value => _motionController.value;

  /// Whether the controller is currently animating.
  bool get isAnimating => _motionController.isAnimating;

  /// The current velocity of the animation.
  T get velocity => _motionController.velocity;

  /// Direction of auto-loop progression (true = forward, false = reverse).
  bool _isForward = true;

  /// Timer for auto-looping phases.
  bool _autoLoopScheduled = false;

  /// Moves to the next phase in the sequence.
  void nextPhase() {
    if (_currentPhaseIndex >= sequence.phases.length - 1) {
      if (sequence.autoReverse) {
        _isForward = false;
        if (_currentPhaseIndex > 0) {
          _goToPhaseIndex(_currentPhaseIndex - 1);
        }
      } else if (sequence.autoLoop) {
        _goToPhaseIndex(0);
      }
      // If neither autoReverse nor autoLoop, stop here
    } else {
      _goToPhaseIndex(_currentPhaseIndex + 1);
    }
  }

  /// Moves to the previous phase in the sequence.
  void previousPhase() {
    if (_currentPhaseIndex <= 0) {
      if (sequence.autoReverse) {
        _isForward = true;
        if (sequence.phases.length > 1) {
          _goToPhaseIndex(1);
        }
      } else if (sequence.autoLoop) {
        _goToPhaseIndex(sequence.phases.length - 1);
      }
      // If neither autoReverse nor autoLoop, stop here
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

  /// Starts the phase animation sequence.
  ///
  /// If the sequence has [PhaseSequence.autoLoop] enabled, this will begin
  /// automatic phase progression.
  void start() {
    if (sequence.autoLoop && !_autoLoopScheduled) {
      _autoLoopScheduled = true;
      // Start the first animation immediately
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_autoLoopScheduled &&
            sequence.autoLoop &&
            sequence.phases.length > 1) {
          nextPhase();
        }
      });
    }
  }

  /// Stops the phase animation sequence.
  ///
  /// This will stop any ongoing animations and cancel auto-loop scheduling.
  void stop() {
    _autoLoopScheduled = false;
    _motionController.stop();
  }

  /// Resets the sequence to the initial phase.
  void reset() {
    _autoLoopScheduled = false;
    _isForward = true;
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
    if (newPhase == _currentPhase) {
      return;
    }

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
    if (!sequence.autoLoop || !_autoLoopScheduled) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!sequence.autoLoop || !_autoLoopScheduled) return;

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
    // Continue auto-loop when animation completes
    if (status == AnimationStatus.completed &&
        sequence.autoLoop &&
        _autoLoopScheduled) {
      _scheduleNextPhase();
    }
  }
}
