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

  @override
  T get value => _motionController.value;

  @override
  bool get isAnimating => _motionController.isAnimating;

  @override
  // TODO
  AnimationStatus get status => AnimationStatus.forward;

  /// The current velocity of the animation.
  T get velocity => _motionController.velocity;

  /// Direction of auto-loop progression (true = forward, false = reverse).
  bool _isForward = true;

  /// Timer for auto-looping phases.
  bool _autoLoopScheduled = false;

  /// Moves to the next phase in the sequence.
  void nextPhase() {
    debugPrint(
        'nextPhase: currentIndex=$_currentPhaseIndex, length=${sequence.phases.length}, autoLoop=${sequence.autoLoop}, scheduled=$_autoLoopScheduled');
    if (_currentPhaseIndex >= sequence.phases.length - 1) {
      // At the last phase
      debugPrint(
          'At last phase, autoReverse=${sequence.autoReverse}, autoLoop=${sequence.autoLoop}');
      if (sequence.autoReverse && sequence.phases.length > 1) {
        _isForward = false;
        _goToPhaseIndex(_currentPhaseIndex - 1);
      } else if (sequence.autoLoop) {
        debugPrint('Looping back to phase 0');
        _goToPhaseIndex(0);
      } else {
        // If neither autoReverse nor autoLoop, stop the auto-loop
        debugPrint('Stopping auto-loop');
        _autoLoopScheduled = false;
        return;
      }
    } else {
      debugPrint('Moving to next phase: ${_currentPhaseIndex + 1}');
      _goToPhaseIndex(_currentPhaseIndex + 1);
    }
  }

  /// Moves to the previous phase in the sequence.
  void previousPhase() {
    if (_currentPhaseIndex <= 0) {
      // At the first phase
      if (sequence.autoReverse && sequence.phases.length > 1) {
        _isForward = true;
        _goToPhaseIndex(1);
      } else if (sequence.autoLoop) {
        _goToPhaseIndex(sequence.phases.length - 1);
      } else {
        // If neither autoReverse nor autoLoop, stop the auto-loop
        _autoLoopScheduled = false;
        return;
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
  }

  /// Moves to the phase at the specified index.
  void _goToPhaseIndex(int index) {
    if (index < 0 || index >= sequence.phases.length) {
      return;
    }

    // Don't return early if we're going to the same phase index - we might be looping
    if (index == _currentPhaseIndex) {
      return;
    }

    final newPhase = sequence.phases[index];
    _currentPhase = newPhase;
    _currentPhaseIndex = index;

    // Update motion controller's motion if we have per-phase motions
    _motionController.motion = _getMotionForCurrentPhase();

    // Animate to the new phase's property value
    final targetValue = sequence.valueForPhase(newPhase);
    
    debugPrint('Going to phase $index ($newPhase), target: $targetValue, current: ${_motionController.value}');
    
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
    debugPrint(
        '_scheduleNextPhase: autoLoop=${sequence.autoLoop}, scheduled=$_autoLoopScheduled');
    if (!sequence.autoLoop || !_autoLoopScheduled) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          'PostFrame callback: autoLoop=${sequence.autoLoop}, scheduled=$_autoLoopScheduled, forward=$_isForward');
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
    debugPrint(
        'Status change: $status, autoLoop=${sequence.autoLoop}, scheduled=$_autoLoopScheduled');
    // Continue auto-loop when animation completes or is dismissed
    // We need to check for both completed and dismissed because the animation
    // can be dismissed when animating to a lower value than the current one
    if ((status.isCompleted || status.isDismissed) &&
        sequence.autoLoop &&
        _autoLoopScheduled) {
      debugPrint('Scheduling next phase');
      _scheduleNextPhase();
    }
  }
}
