import 'package:flutter/physics.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/step.dart';

/// Stateful playback for a list of [Step]s.
///
/// Unlike [Simulation], this advances segment-by-segment and only leaves a
/// segment once all of its simulations report that they are done.
class StepPlayback<T extends Object> {
  /// Creates playback from [steps].
  ///
  /// If [fallbackMotion] is provided, it is used for any [StepTo] or [StepAt]
  /// that does not specify its own motion.
  StepPlayback({
    required List<Step<T>> steps,
    required MotionConverter<T> converter,
    required T start,
    T? velocity,
    LoopMode loop = LoopMode.none,
    Motion? fallbackMotion,
  })  : assert(steps.isNotEmpty, 'steps must not be empty'),
        assert(
          _validateStepTiming(steps),
          'steps must have non-decreasing absolute times',
        ),
        _steps = List.of(steps),
        _converter = converter,
        _loop = loop,
        _fallbackMotion = fallbackMotion,
        _initialValues = converter.normalize(start),
        _initialVelocities = switch (velocity) {
          null => List<double>.filled(converter.normalize(start).length, 0),
          final value => converter.normalize(value),
        } {
    _buildWaypoints();
    _reset();
  }

  static bool _validateStepTiming<S extends Object>(List<Step<S>> steps) {
    var minElapsed = Duration.zero;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step case StepAt<S>(:final at)) {
        if (at < minElapsed) {
          throw AssertionError(
            'Step.at(${at.inMilliseconds}ms) at index $i would go back in '
            'time. Preceding holds already consume ${minElapsed.inMilliseconds}'
            'ms. The .at() time must be >= the cumulative hold duration.',
          );
        }
        minElapsed = at;
      } else if (step case StepHold<S>(:final duration)) {
        minElapsed += duration;
      }
    }
    return true;
  }

  final List<Step<T>> _steps;
  final MotionConverter<T> _converter;
  final LoopMode _loop;
  final Motion? _fallbackMotion;
  final List<double> _initialValues;
  final List<double> _initialVelocities;

  /// Target values for each step, used by pingPong to reverse.
  /// Index i holds the normalized target that step i animates toward.
  late final List<List<double>> _waypoints;

  late List<double> _currentValues;
  late List<double> _currentVelocities;
  late List<Simulation> _simulations;
  var _stepIndex = 0;
  var _direction = 1;
  var _cycleStartSeconds = 0.0;
  var _segmentStartSeconds = 0.0;
  var _lastElapsedSeconds = 0.0;
  var _isDone = false;
  var _isWaitingForSync = false;

  void _buildWaypoints() {
    _waypoints = [
      for (final step in _steps)
        switch (step) {
          StepTo<T>(:final value) => _converter.normalize(value),
          StepAt<T>(:final value) => _converter.normalize(value),
          _ => List.of(_initialValues),
        },
    ];
  }

  /// Current normalized values.
  List<double> get values => List.unmodifiable(_currentValues);

  /// Current normalized velocities.
  List<double> get velocities => List.unmodifiable(_currentVelocities);

  /// The currently active step index.
  int get currentStepIndex => _isDone ? -1 : _stepIndex;

  /// Whether playback has completed.
  bool get isDone => _isDone;

  /// Whether playback is paused at a [SyncStep], waiting for external release.
  bool get isWaitingForSync => _isWaitingForSync;

  /// The token of the [SyncStep] currently being waited on, or `null` if
  /// playback is not waiting at a sync barrier.
  Object? get syncToken {
    if (!_isWaitingForSync) return null;
    return (_steps[_stepIndex] as SyncStep<T>).token;
  }

  /// Releases the playback past the current [SyncStep].
  ///
  /// Called by [TrackController] when all active tracks have reached their
  /// sync step and are ready to advance together.
  void releaseSync() {
    if (!_isWaitingForSync) return;
    _isWaitingForSync = false;
    _segmentStartSeconds = _lastElapsedSeconds;
    _advanceStep();
  }

  /// Advances playback to [elapsedSeconds].
  ///
  /// Processes all step boundaries that fall within the elapsed window so that
  /// large time gaps (e.g. from ticker muting during navigation) are resolved
  /// in a single call rather than one step per tick.
  bool advanceTo(double elapsedSeconds) {
    assert(elapsedSeconds >= 0, 'elapsed must be non-negative');
    if (elapsedSeconds < _lastElapsedSeconds) {
      return seekTo(elapsedSeconds);
    }

    _lastElapsedSeconds = elapsedSeconds;
    if (_isDone || _isWaitingForSync) return _isDone;

    var iterations = 0;
    while (!_isDone && !_isWaitingForSync && iterations++ < 1000) {
      if (_moveToScheduledStepIfDue(elapsedSeconds)) {
        continue;
      }

      final localSeconds = elapsedSeconds - _segmentStartSeconds;
      _sample(localSeconds);
      if (!_segmentIsDone(localSeconds)) return false;

      // Use the computed ideal completion time to prevent floating-point
      // drift across loop cycles.
      final completionSeconds = _completionTime(localSeconds);
      _sample(completionSeconds);
      _segmentStartSeconds += completionSeconds;

      // If the current step is a SyncStep, enter waitForSync instead of
      // advancing. The TrackController will call releaseSync() when all
      // tracks are synchronized.
      if (_steps[_stepIndex] is SyncStep<T>) {
        _isWaitingForSync = true;
        return false;
      }

      _advanceStep();
    }

    return _isDone;
  }

  /// Seeks playback to [elapsedSeconds].
  ///
  /// This replays from the beginning and discovers segment boundaries lazily
  /// with binary search only when a segment reports completion.
  bool seekTo(double elapsedSeconds) {
    assert(elapsedSeconds >= 0, 'elapsed must be non-negative');
    _reset();
    _lastElapsedSeconds = elapsedSeconds;

    var iterations = 0;
    while (!_isDone && iterations++ < 1000) {
      if (_moveToScheduledStepIfDue(elapsedSeconds)) {
        continue;
      }

      final localSeconds = elapsedSeconds - _segmentStartSeconds;
      _sample(localSeconds);

      if (!_segmentIsDone(localSeconds)) return false;

      final completionSeconds = _completionTime(localSeconds);
      _sample(completionSeconds);
      _segmentStartSeconds += completionSeconds;
      _advanceStep();

      if (_segmentStartSeconds > elapsedSeconds) return _isDone;
    }

    return _isDone;
  }

  void _reset() {
    _currentValues = List.of(_initialValues);
    _currentVelocities = List.of(_initialVelocities);
    _stepIndex = 0;
    _direction = 1;
    _cycleStartSeconds = 0;
    _segmentStartSeconds = 0;
    _lastElapsedSeconds = 0;
    _isDone = false;
    _isWaitingForSync = false;
    _startCurrentStep();
    _sample(0);
  }

  void _advanceStep() {
    _stepIndex += _direction;

    if (_direction > 0 && _stepIndex >= _steps.length) {
      switch (_loop) {
        case LoopMode.none:
          _isDone = true;
          return;
        case LoopMode.loop:
          _currentValues = List.of(_initialValues);
          _currentVelocities = List.of(_initialVelocities);
          _cycleStartSeconds = _segmentStartSeconds;
          _stepIndex = 0;
        case LoopMode.pingPong:
          // Reverse direction from the last step.
          _direction = -1;
          _cycleStartSeconds = _segmentStartSeconds;
          _stepIndex = _steps.length - 1;
        case LoopMode.seamless:
          // Continue from current values (no reset) so the wrap is smooth.
          // Callers should ensure first and last values match.
          _cycleStartSeconds = _segmentStartSeconds;
          _stepIndex = 0;
      }
    } else if (_direction < 0 && _stepIndex < 0) {
      // PingPong: reached start while reversing — go forward again from
      // step 0 which targets the first step value.
      _direction = 1;
      _cycleStartSeconds = _segmentStartSeconds;
      _stepIndex = 0;
    }

    _startCurrentStep();
  }

  Motion _resolveMotion(Motion? stepMotion) {
    final resolved = stepMotion ?? _fallbackMotion;
    assert(
      resolved != null,
      'Step has no motion and no fallback motion was provided. '
      'Either pass a motion to the step or set a default motion on the Track.',
    );
    return resolved!;
  }

  void _startCurrentStep() {
    if (_direction < 0) {
      _startReverseStep();
      return;
    }
    final step = _steps[_stepIndex];
    _simulations = switch (step) {
      StepTo<T>(:final value, :final motion) => () {
          final resolved = _resolveMotion(motion);
          final targets = _converter.normalize(value);
          return [
            for (var i = 0; i < targets.length; i++)
              resolved.createSimulation(
                start: _currentValues[i],
                end: targets[i],
                velocity: _currentVelocities[i],
              ),
          ];
        }(),
      StepFree<T>(:final motion) => [
          for (var i = 0; i < _currentValues.length; i++)
            motion.createSimulation(
              start: _currentValues[i],
              velocity: _currentVelocities[i],
            ),
        ],
      StepHold<T>(:final duration) => [
          for (final value in _currentValues)
            _HoldSimulation(
              value: value,
              duration: duration.toSeconds(),
            ),
        ],
      StepAt<T>(:final at, :final value, :final motion) => () {
          final resolved = _resolveMotion(motion);
          final targets = _converter.normalize(value);
          final gap = _absoluteTimeFor(at) - _segmentStartSeconds;
          final atMotion = gap > 0
              ? resolved
                  .scaleTo(Duration(microseconds: (gap * 1000000).round()))
              : resolved;
          return [
            for (var i = 0; i < targets.length; i++)
              atMotion.createSimulation(
                start: _currentValues[i],
                end: targets[i],
                velocity: _currentVelocities[i],
              ),
          ];
        }(),
      SyncStep<T>() => [
          for (final value in _currentValues)
            _HoldSimulation(value: value, duration: 0),
        ],
    };
  }

  /// Starts a step in reverse direction for pingPong mode.
  ///
  /// The target is the previous step's waypoint (or initial values for step 0).
  void _startReverseStep() {
    final targets =
        _stepIndex > 0 ? _waypoints[_stepIndex - 1] : _initialValues;
    final step = _steps[_stepIndex];
    final motion = switch (step) {
      StepTo<T>(:final motion) => motion ?? _fallbackMotion,
      StepAt<T>(:final motion) => motion ?? _fallbackMotion,
      StepFree<T>() => null,
      StepHold<T>() => null,
      SyncStep<T>() => null,
    };

    if (motion != null) {
      _simulations = [
        for (var i = 0; i < targets.length; i++)
          motion.createSimulation(
            start: _currentValues[i],
            end: targets[i],
            velocity: _currentVelocities[i],
          ),
      ];
    } else {
      // For free/hold steps in reverse, use a hold at current values with the
      // same duration.
      final duration = switch (step) {
        StepHold<T>(:final duration) => duration.toSeconds(),
        _ => 0.0,
      };
      _simulations = [
        for (final value in _currentValues)
          _HoldSimulation(value: value, duration: duration),
      ];
    }
  }

  bool _moveToScheduledStepIfDue(double elapsedSeconds) {
    final nextStepIndex = _stepIndex + _direction;
    if (nextStepIndex < 0 || nextStepIndex >= _steps.length) return false;

    final nextStep = _steps[nextStepIndex];
    if (nextStep case StepAt<T>(:final at)) {
      final absoluteAt = _absoluteTimeFor(at);
      if (elapsedSeconds < absoluteAt) return false;

      _sample(absoluteAt - _segmentStartSeconds);
      _segmentStartSeconds = absoluteAt;
      _advanceStep();
      return true;
    }

    return false;
  }

  double _absoluteTimeFor(Duration at) => _cycleStartSeconds + at.toSeconds();

  void _sample(double localSeconds) {
    final t = localSeconds < 0 ? 0.0 : localSeconds;
    _currentValues = [
      for (final simulation in _simulations) simulation.x(t),
    ];
    _currentVelocities = [
      for (final simulation in _simulations) simulation.dx(t),
    ];
  }

  bool _segmentIsDone(double localSeconds) {
    return _simulations.every((simulation) => simulation.isDone(localSeconds));
  }

  double _completionTime(double upper) {
    if (upper <= 0 || _segmentIsDone(0)) return 0;

    var low = 0.0;
    var high = upper;
    for (var i = 0; i < 24; i++) {
      final mid = (low + high) / 2;
      if (_segmentIsDone(mid)) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return high;
  }
}

class _HoldSimulation extends Simulation {
  _HoldSimulation({
    required this.value,
    required this.duration,
  });

  final double value;
  final double duration;

  @override
  double x(double time) => value;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= duration;
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
