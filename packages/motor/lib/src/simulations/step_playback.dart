import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/inspection/controller_registry.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/settling_simulation.dart';
import 'package:motor/src/simulations/curve_simulation.dart';
import 'package:motor/src/simulations/cut_motion.dart';
import 'package:motor/src/simulations/simulation_end.dart';
import 'package:motor/src/track_step.dart';

/// Playback for a list of [TrackStep]s.
///
/// Steps are resolved lazily into a table of segments, each holding the
/// simulations of one step and the time range it occupies. Ticking and
/// seeking both sample that table, so any time that has been resolved can be
/// revisited without replaying from the start. A segment is left only once
/// all of its simulations report that they are done.
///
/// Simulations must be pure functions of time: re-sampling a segment has to
/// reproduce the values it produced during playback.
@internal
class StepPlayback<T extends Object> {
  /// Creates playback from [steps].
  ///
  /// If [fallbackMotion] (single) or [fallbackMotionPerDimension] (one motion
  /// per normalized dimension) is provided, it is used for any [StepTo] or
  /// [StepAt] that does not specify its own motion. Pass at most one.
  StepPlayback({
    required List<TrackStep<T>> steps,
    required MotionConverter<T> converter,
    required T start,
    T? velocity,
    LoopMode loop = LoopMode.none,
    Motion? fallbackMotion,
    List<Motion>? fallbackMotionPerDimension,
  }) : this.normalized(
          steps: steps,
          converter: converter,
          initialValues: converter.normalize(start),
          initialVelocities:
              velocity == null ? null : converter.normalize(velocity),
          loop: loop,
          fallbackMotion: fallbackMotion,
          fallbackMotionPerDimension: fallbackMotionPerDimension,
        );

  /// Creates playback from [steps], starting at the normalized
  /// [initialValues] with the normalized [initialVelocities] (at rest when
  /// null). Nothing is converted back to `T`, which converters may clamp.
  ///
  /// [waypoints] reuses the targets of an existing plan.
  ///
  /// [incoming] is the motion of a plan this one replaces, still playing at
  /// the start (see [liveSimulations]): leading holds and barriers keep it
  /// playing, and the first step that moves takes over its value and
  /// velocity. [delay] postpones the plan: it starts that long after, with
  /// [incoming] playing meanwhile, or resting.
  StepPlayback.normalized({
    required List<TrackStep<T>> steps,
    required this.converter,
    required List<double> initialValues,
    List<double>? initialVelocities,
    LoopMode loop = LoopMode.none,
    Motion? fallbackMotion,
    List<Motion>? fallbackMotionPerDimension,
    List<List<double>>? waypoints,
    this.incoming,
    this.delay = 0,
  })  : assert(steps.isNotEmpty, 'steps must not be empty'),
        assert(
          fallbackMotion == null || fallbackMotionPerDimension == null,
          'Provide either fallbackMotion or fallbackMotionPerDimension, '
          'not both.',
        ),
        assert(
          _validateStepTiming(steps),
          'steps must have non-decreasing absolute times',
        ),
        assert(
          _validateDurations(
            steps,
            fallbackMotion,
            fallbackMotionPerDimension,
          ),
          'durations must not be negative',
        ),
        _steps = List.of(steps),
        _loop = loop,
        _fallbackMotion = fallbackMotion,
        _fallbackMotionPerDimension = fallbackMotionPerDimension,
        _initialValues = List<double>.of(initialValues, growable: false),
        _initialVelocities = initialVelocities == null
            ? List<double>.filled(initialValues.length, 0)
            : List<double>.of(initialVelocities, growable: false) {
    _values = List<double>.of(_initialValues, growable: false);
    _velocities = List<double>.of(_initialVelocities, growable: false);
    _viewValues = List<double>.of(_initialValues, growable: false);
    _viewVelocities = List<double>.of(_initialVelocities, growable: false);
    if (loop == LoopMode.loop) {
      // `loop` animates back to the start after the last step. Model that as a
      // synthetic final step that returns to the start snapshot, reusing the
      // first real step's motion(s) and how it ends. The wrap (in
      // `_advanceStep`) then continues from there without a jump. `seamless`
      // skips this and jumps.
      final returnMotions = _firstStepMotions(_steps, _initialValues.length) ??
          _fallbackMotionPerDimension ??
          (fallbackMotion != null
              ? List<Motion>.filled(_initialValues.length, fallbackMotion)
              : null);
      if (returnMotions != null) {
        _steps.add(
          StepTo<T>(
            // Only shown by inspection: the target is [_initialValues].
            converter.denormalize(_initialValues),
            motionPerDimension: returnMotions,
            until: _firstStepWait(_steps),
          ),
        );
        _hasReturnStep = true;
      }
    }
    assert(
      _steps.every(
        (step) => switch (step) {
          StepTo<T>(:final motion, :final motionPerDimension) ||
          StepAt<T>(:final motion, :final motionPerDimension) =>
            _motionsOrNull(motion, motionPerDimension) != null,
          _ => true,
        },
      ),
      'A TrackStep has no motion and no fallback motion was provided. '
      'Either pass a motion to the step or set a default motion on the Track.',
    );
    _canFold = loop.isLooping && !_steps.any((step) => step is StepSync<T>);
    _forwardSegmentSeconds = List<double?>.filled(_steps.length, null);
    _buildWaypoints(waypoints);
    if (delay > 0) {
      _startLead();
    } else {
      _startPlan();
    }
    _show(0);
  }

  /// Returns the per-dimension motions of the first step that targets a value,
  /// or `null` if it uses the track's motion or no step targets a value.
  static List<Motion>? _firstStepMotions<S extends Object>(
    List<TrackStep<S>> steps,
    int dimensions,
  ) {
    for (final step in steps) {
      switch (step) {
        case StepTo<S>(:final motion, :final motionPerDimension) ||
              StepAt<S>(:final motion, :final motionPerDimension):
          if (motionPerDimension != null) return motionPerDimension;
          if (motion != null) return List<Motion>.filled(dimensions, motion);
          return null;
        default:
          break;
      }
    }
    return null;
  }

  /// What the step after the first one that targets a value waits for.
  static WaitUntil _firstStepWait<S extends Object>(List<TrackStep<S>> steps) {
    for (final step in steps) {
      if (step is StepTo<S>) return step.until;
      if (step is StepAt<S>) return WaitUntil.settled;
    }
    return WaitUntil.settled;
  }

  static bool _validateStepTiming<S extends Object>(List<TrackStep<S>> steps) {
    var minElapsed = Duration.zero;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step case StepAt<S>(:final at)) {
        if (at < minElapsed) {
          throw AssertionError(
            'TrackStep.at(${at.inMilliseconds}ms) at index $i would go back in '
            'time. Preceding holds already consume ${minElapsed.inMilliseconds}'
            'ms. The .at() time must be >= the cumulative hold duration.',
          );
        }
        minElapsed = at;
      } else if (step case StepHold<S>(:final duration)) {
        minElapsed += duration;
      } else if (step is PhaseBoundary<S>) {
        // Keyframes after it count from the start of its phase.
        minElapsed = Duration.zero;
      }
    }
    return true;
  }

  /// Throws if a hold or a motion lasts a negative time, which would move
  /// playback back in time.
  static bool _validateDurations<S extends Object>(
    List<TrackStep<S>> steps,
    Motion? fallbackMotion,
    List<Motion>? fallbackMotionPerDimension,
  ) {
    void check(MotionBase? motion, String where) {
      final duration = motion?.duration;
      if (duration == null || !duration.isNegative) return;
      throw AssertionError(
        '$where has a negative duration (${duration.inMicroseconds} µs).',
      );
    }

    check(fallbackMotion, 'The track motion');
    for (final motion in fallbackMotionPerDimension ?? const <Motion>[]) {
      check(motion, 'A track motion');
    }
    for (var i = 0; i < steps.length; i++) {
      final where = 'The motion of the step at index $i';
      switch (steps[i]) {
        case StepHold<S>(:final duration) when duration.isNegative:
          throw AssertionError(
            'TrackStep.hold at index $i has a negative duration '
            '(${duration.inMicroseconds} µs).',
          );
        case StepTo<S>(:final motion, :final motionPerDimension) ||
              StepAt<S>(:final motion, :final motionPerDimension):
          check(motion, where);
          for (final motion in motionPerDimension ?? const <Motion>[]) {
            check(motion, where);
          }
        case StepFree<S>(:final motion):
          check(motion, where);
        default:
          break;
      }
    }
    return true;
  }

  /// Upper bound on segments resolved in a row without time passing, so
  /// zero-length loops cannot spin forever. Segments that take time don't
  /// count, so a jump far ahead always catches up.
  static const _maxSegmentsPerCall = 1000;

  // Segment durations are searched on the grid of [nextSettleScan] up to
  // [settleSearchSeconds], as for any simulation's settle time; past that,
  // only a simulation that reports when it settles ends.

  /// The shortest loop cycle, in seconds, that is repeated when shown.
  static const _minFoldPeriod = 1e-9;

  /// Cycles after which a loop that has not folded is bounded like a loop
  /// with sync steps.
  static const _foldAttempts = 8;

  /// How many segments a loop that does not fold keeps for seeking back
  /// while inspection tooling is attached. Whole cycles are dropped, oldest
  /// first, but never the last two; without tooling only those two are kept.
  static const _maxKeptSegments = 1024;

  /// Gaps shorter than this (one microsecond) count as no time at all.
  static const _instant = 1e-6;

  final List<TrackStep<T>> _steps;

  /// The converter, which a converter swap that keeps playing replaces with
  /// one that reads the normalized values the same way.
  MotionConverter<T> converter;

  final LoopMode _loop;
  final Motion? _fallbackMotion;
  final List<Motion>? _fallbackMotionPerDimension;
  final List<double> _initialValues;
  final List<double> _initialVelocities;
  var _hasReturnStep = false;

  /// The normalized value each step ends at, used by pingPong to reverse.
  /// A step without a target keeps the value of the step before it.
  late final List<List<double>> _waypoints;

  /// Whether each step ends at a value only a free step before it decides,
  /// so that pingPong reverses toward [_forwardStarts] instead of
  /// [_waypoints].
  late final List<bool> _endsFree;

  /// The values each step started from on its last forward pass, recorded
  /// for the steps that follow a free step's end.
  late final List<List<double>?> _forwardStarts =
      List<List<double>?>.filled(_steps.length, null);

  /// The duration each step occupied during forward playback.
  late final List<double?> _forwardSegmentSeconds;

  /// Stable predicted durations for the forward playback plan.
  List<double?>? _estimatedSegmentSeconds;

  // Resolution state: the segment currently being resolved, at the end of
  // the table.
  final List<_Segment> _segments = [];
  late final List<double> _values;
  late final List<double> _velocities;
  late List<Simulation> _simulations;

  /// When the running segment ends, if its step says so up front: holds,
  /// sync barriers, `.at` arrivals, and steps a later motion takes over from.
  double? _plannedEnd;

  /// The simulations of the plan this one replaced, still playing when this
  /// one started, continuing from that time; or null.
  final List<Simulation>? incoming;

  /// How long after its start this plan begins, in seconds.
  final double delay;

  /// Whether the running segment is the wait for [delay], which is no step.
  var _leading = false;

  /// Whether the running segment is one of the plan's own steps.
  bool get _inStep => !_settlingTail && !_leading;

  /// Whether the running segment ends before its simulations are done, so
  /// that holds and sync barriers after it keep playing them out.
  var _handsOver = false;

  /// Whether the step before the running one handed over.
  var _handedOver = false;

  /// Whether the running segment plays out, after the last step, what that
  /// step's simulations still had to settle.
  var _settlingTail = false;

  /// Whether the running segment's simulations are still to be asked when
  /// they settle ([SettlingSimulation.settlesAt]).
  var _askEnd = false;
  var _stepIndex = 0;
  var _direction = 1;
  var _cycle = 0;
  var _cycleStartSeconds = 0.0;
  var _segmentStartSeconds = 0.0;
  var _isDone = false;
  var _isWaitingForSync = false;

  /// How long the running segment lasts, or null if it never settles;
  /// only valid once [_segmentEndFound].
  double? _segmentDuration;
  var _segmentEndFound = false;

  // The search for the running segment's end, on the grid of [nextSettleScan]:
  // the last point checked, where it is not done yet, and the next one.
  var _scanLow = 0.0;
  var _scanHigh = 0.0;

  /// When the running step yields to a following [StepAt], if it has to.
  double? _cutAt;

  // Loop cycles. A cycle ends where the forward pass ends (for pingPong it
  // spans the reverse and the next forward pass). Once a cycle starts in the
  // same state as the previous one, playback repeats with a fixed period and
  // resolution stops ("folding").
  // Plans with sync steps never fold because their release times come from
  // other tracks; they, and loops that have not folded after
  // [_foldAttempts] cycles, keep only the most recent cycles instead.
  late final bool _canFold;
  late final List<_CycleStart> _cycleStarts = [];
  double? _period;
  var _foldStartSeconds = 0.0;

  // What the most recent advance or seek shows.
  late final List<double> _viewValues;
  late final List<double> _viewVelocities;
  List<Simulation> _viewSimulations = const [];
  var _viewTime = 0.0;
  var _viewVelocitiesStale = false;
  var _viewAtRest = false;
  var _lastElapsedSeconds = 0.0;
  var _viewIndex = 0;
  var _viewCycleShift = 0;
  var _viewTimeShift = 0.0;

  // The last segment handed out by [takeEnteredSteps].
  var _reportedIndex = -1;
  var _reportedShift = 0;

  _Segment get _view => _segments[_viewIndex];

  void _buildWaypoints(List<List<double>>? reused) {
    // Periodic dimensions take the short way from the previous target.
    final dimensions = converter.dimensions;
    var previous = _initialValues;
    List<double> normalize(T value) {
      var values = converter.normalize(value);
      assert(
        debugCheckDimensions(converter, values.length),
        'normalize must match the converter dimensions',
      );
      if (dimensions != null) {
        for (var i = 0; i < values.length; i++) {
          if (dimensions[i].period case final period?) {
            final turns = ((previous[i] - values[i]) / period).round();
            if (turns != 0) {
              values = List.of(values);
              values[i] += period * turns;
            }
          }
        }
      }
      return previous = values;
    }

    // A step without a target ends where the step before it ended. After a
    // free step that is only known once it has played, so pingPong reverses
    // toward the recorded start of the next forward step instead.
    var last = _initialValues;
    var free = false;
    _endsFree = [
      for (final step in _steps)
        free = switch (step) {
          StepTo<T>() || StepAt<T>() => false,
          StepFree<T>() => true,
          _ => free,
        },
    ];
    _waypoints = reused ??
        [
          for (final (index, step) in _steps.indexed)
            last = switch (step) {
              // The return step goes back to exactly where the plan started.
              StepTo<T>() when _hasReturnStep && index == _steps.length - 1 =>
                _initialValues,
              StepTo<T>(:final value) ||
              StepAt<T>(:final value) =>
                normalize(value),
              _ => last,
            },
        ];
  }

  /// Where the step at [index] started on its last forward pass, or where
  /// the step before it ends, which pingPong reverses toward.
  List<double> _reverseTargets(int index) {
    if (index == 0) return _initialValues;
    if (_endsFree[index - 1]) {
      if (_forwardStarts[index] case final recorded?) return recorded;
    }
    return _waypoints[index - 1];
  }

  /// A fresh copy of this plan that plays its steps once, from the same
  /// start, for resolving ahead without affecting this playback.
  StepPlayback<T> fork() => StepPlayback<T>.normalized(
        steps: _steps,
        converter: converter,
        initialValues: _initialValues,
        initialVelocities: _initialVelocities,
        fallbackMotion: _fallbackMotion,
        fallbackMotionPerDimension: _fallbackMotionPerDimension,
        waypoints: _waypoints,
        incoming: incoming,
        delay: delay,
      );

  /// The simulations playing at the time shown, continuing from there, for a
  /// plan that replaces this one; null once this one is done.
  List<Simulation>? get liveSimulations => isDone
      ? null
      : [
          for (final simulation in _viewSimulations)
            _ContinuedSimulation.after(simulation, _viewTime),
        ];

  /// How long the [StepAt] at [index] runs at its natural speed: its
  /// motion's [Motion.duration], or when a move from where the running
  /// segment is at [from] seconds (or its start when null) settles. Null if
  /// that never happens.
  double? _atNaturalSeconds(
    int index,
    Motion? motion,
    List<Motion>? motionPerDimension,
    double? from,
  ) {
    final motions = _motionsOrNull(motion, motionPerDimension);
    if (motions == null) return null;
    final targets = _waypoints[index];
    var longest = 0.0;
    for (var i = 0; i < motions.length; i++) {
      final seconds = motions[i].duration?.toSeconds() ??
          settleSecondsOf(
            motions[i].createSimulation(
              start: from == null ? _values[i] : _simulations[i].x(from),
              end: targets[i],
              velocity:
                  from == null ? _velocities[i] : _simulations[i].dx(from),
            ),
          );
      if (seconds == null || !seconds.isFinite) return null;
      if (seconds > longest) longest = seconds;
    }
    return longest;
  }

  /// Current normalized values, as a live read-only view.
  List<double> get values => UnmodifiableListView(_viewValues);

  /// Current normalized velocities, as a live read-only view.
  List<double> get velocities {
    _showVelocities();
    return UnmodifiableListView(_viewVelocities);
  }

  /// Copies the current normalized values and velocities into [values] and
  /// [velocities] without allocating.
  void copyStateInto(List<double> values, List<double> velocities) {
    copyValuesInto(values);
    copyVelocitiesInto(velocities);
  }

  /// Copies the current normalized values into [values] without allocating.
  void copyValuesInto(List<double> values) => _copyInto(values, _viewValues);

  /// Copies the current normalized velocities into [velocities] without
  /// allocating. They are only computed when asked for.
  void copyVelocitiesInto(List<double> velocities) {
    _showVelocities();
    _copyInto(velocities, _viewVelocities);
  }

  static void _copyInto(List<double> target, List<double> source) {
    assert(
      target.length == source.length,
      'dimension mismatch: ${target.length} != ${source.length}',
    );
    for (var i = 0; i < source.length; i++) {
      target[i] = source[i];
    }
  }

  void _restoreInitialState() {
    _handsOver = false;
    _copyInto(_values, _initialValues);
    _copyInto(_velocities, _initialVelocities);
  }

  bool get _viewIsLatest => _viewIndex == _segments.length - 1;

  /// The currently active step index.
  int get currentStepIndex => isDone ? -1 : _view.stepIndex;

  /// The per-dimension motions of the active step, or null when it doesn't
  /// move toward a target (free motions, holds and sync barriers).
  List<Motion>? get currentMotions {
    if (isDone) return null;
    if (_view.stepIndex < 0) return null;
    return switch (_steps[_view.stepIndex]) {
      StepTo<T>(:final motion, :final motionPerDimension) ||
      StepAt<T>(:final motion, :final motionPerDimension) =>
        _motionsOrNull(motion, motionPerDimension),
      _ => null,
    };
  }

  /// Whether playback has settled: its last step is done and at rest.
  bool get isDone =>
      _isDone && _lastElapsedSeconds >= (_segments.last.end ?? double.infinity);

  /// Whether playback has ended: its last step's motion has reached its
  /// [MotionBase.duration], while it may still be settling.
  ///
  /// That holds whatever the step's [WaitUntil]. A hold ends after its
  /// duration and a `.at` at its time. A motion without a duration and a
  /// barrier end when playback settles. Looping playback never ends.
  bool get hasEnded {
    if (isDone) return true;
    final end = _lastEndsAt;
    return end != null && _lastElapsedSeconds >= end;
  }

  /// When the last step of a plan that doesn't loop ends, once it has
  /// started; infinite if it ends when it settles.
  double? _lastEndsAt;

  /// Whether playback is paused at a [StepSync], waiting for external release.
  bool get isWaitingForSync => _isWaitingForSync && _viewIsLatest;

  /// The token of the [StepSync] currently being waited on, or `null` if
  /// playback is not waiting at a sync barrier.
  Object? get syncToken {
    if (!isWaitingForSync) return null;
    return (_steps[_view.stepIndex] as StepSync<T>).token;
  }

  /// The actual playback plan, including a synthetic loop-return step.
  List<TrackStep<T>> get stepsView => List.unmodifiable(_steps);

  /// Whether [stepsView] ends with a synthetic loop-return step.
  bool get hasSyntheticReturnStep => _hasReturnStep;

  /// The loop mode used by this playback.
  LoopMode get loop => _loop;

  /// Recorded forward segment durations, in seconds.
  List<double?> get forwardSegmentSeconds =>
      List.unmodifiable(_forwardSegmentSeconds);

  /// Predicted forward segment durations, set by inspection tooling.
  List<double?> get estimatedSegmentSeconds => List.unmodifiable(
        _estimatedSegmentSeconds ?? List<double?>.filled(_steps.length, null),
      );

  set estimatedSegmentSeconds(List<double?> value) {
    assert(value.length == _steps.length, 'one estimate per step');
    _estimatedSegmentSeconds = value;
  }

  /// The current playback direction: `1` forward or `-1` reverse.
  int get direction => _view.direction;

  /// The number of loop boundaries crossed by this playback.
  int get cycle => _view.cycle + _viewCycleShift;

  /// The most recent slot-local elapsed time, in seconds.
  double get lastElapsedSeconds => _lastElapsedSeconds;

  /// Whether the shown segment heads for a smaller value than it started
  /// from, as judged by a [DirectionalMotionConverter].
  ///
  /// Segments without a direction (holds, free motions, sync barriers, moves
  /// to the value they start from) take the direction of the most recent
  /// segment that has one. Null when there is none, or for converters
  /// without a direction.
  bool? get shownMovesDown {
    final converter = this.converter;
    if (converter is! DirectionalMotionConverter<T>) return null;
    for (var index = _viewIndex; index >= 0; index--) {
      final segment = _segments[index];
      final movesDown = segment.movesDown ??= _movesDown(segment, converter);
      if (movesDown != null) return movesDown;
    }
    return null;
  }

  /// Whether [segment] heads down, or null if it has no direction.
  bool? _movesDown(
    _Segment segment,
    DirectionalMotionConverter<T> converter,
  ) {
    final index = segment.stepIndex;
    if (index < 0) return null;
    final step = _steps[index];
    if (step is! StepTo<T> && step is! StepAt<T>) return null;
    final to =
        segment.direction > 0 ? _waypoints[index] : _reverseTargets(index);
    final from = segment.from ??
        [for (final simulation in segment.simulations) simulation.x(0)];
    final order = converter.compare(
      converter.denormalize(from),
      converter.denormalize(to),
    );
    return order == 0 ? null : order > 0;
  }

  /// The resolved segments, oldest first: which step each one plays and when.
  ///
  /// The segment being resolved reports when it is going to end, unless that
  /// is unknown (it waits at a sync barrier or never settles).
  List<({int stepIndex, int direction, int cycle, double start, double? end})>
      get segmentsView => [
            for (final segment in _segments)
              (
                stepIndex: segment.stepIndex,
                direction: segment.direction,
                cycle: segment.cycle,
                start: segment.start,
                end: segment.end ??
                    (identical(segment, _segments.last) ? _upcomingEnd : null),
              ),
          ];

  double? get _upcomingEnd {
    if (_isDone || _isWaitingForSync || _period != null) return null;
    if (_inStep && _steps[_stepIndex] is StepSync<T>) return null;
    if (_cutAt case final cut?) return cut;
    final duration = _findSegmentEnd();
    return duration == null ? null : _segmentStartSeconds + duration;
  }

  /// Once a loop repeats exactly, how long each repetition lasts, in seconds.
  /// Segments from [loopRepeatStartSeconds] on then repeat with this period.
  double? get loopPeriodSeconds => _period;

  /// Where the repeating part of a folded loop starts, in seconds.
  double get loopRepeatStartSeconds => _foldStartSeconds;

  /// The indices of the steps entered since the previous call, in order.
  ///
  /// The synthetic return step of [LoopMode.loop] is not included.
  ///
  /// Every step playback passed through is included, even when one advance
  /// crosses several. Moving back in time enters nothing. When one advance
  /// skips whole loop cycles, only the steps of the last cycle entered are
  /// included.
  List<int> takeEnteredSteps() {
    final targetShift = _viewCycleShift;
    final targetIndex = _viewIndex;
    var shift = _reportedShift;
    var index = _reportedIndex;
    _reportedShift = targetShift;
    _reportedIndex = targetIndex;

    final behind =
        targetShift < shift || (targetShift == shift && targetIndex <= index);
    if (behind) return const [];

    final entered = <int>[];
    var walked = 0;
    while ((shift != targetShift || index != targetIndex) &&
        walked++ <= _segments.length) {
      index++;
      if (index >= _segments.length) {
        shift = targetShift;
        index = _segmentIndexAt(_foldStartSeconds);
      }
      final segment = _segments[index];
      if (segment.tail) continue;
      final step = segment.stepIndex;
      if (!_hasReturnStep || step != _steps.length - 1) entered.add(step);
    }
    return entered;
  }

  /// The token of the [StepSync] that resolution is held at, or `null`.
  ///
  /// Unlike [syncToken], this does not depend on the time being shown.
  Object? get pendingSyncToken {
    if (!_isWaitingForSync) return null;
    return (_steps[_stepIndex] as StepSync<T>).token;
  }

  /// When resolution arrived at the pending [StepSync], in slot-local seconds.
  double get pendingSyncArrivalSeconds => _segmentStartSeconds;

  /// Releases the pending [StepSync] at [atSeconds], in slot-local seconds.
  ///
  /// Called by [TrackController] once every track sharing the barrier has
  /// arrived. Playback between the arrival and [atSeconds] holds still.
  void releaseSync({required double atSeconds}) {
    if (!_isWaitingForSync) return;
    _isWaitingForSync = false;
    final release = math.max(atSeconds, _segmentStartSeconds);
    final local = release - _segmentStartSeconds;
    _sample(local);
    _closeSegment(release, local);
    if (_steps[_stepIndex] is PhaseBoundary<T>) _phaseStartSeconds = release;
    _advanceStep();
    _show(_lastElapsedSeconds);
  }

  /// Advances playback to [elapsedSeconds], waiting at sync barriers.
  ///
  /// Resolves all step boundaries that fall within the elapsed window, so
  /// large time gaps (e.g. from ticker muting during navigation) are handled
  /// in a single call. Times that were already resolved are sampled from the
  /// segment table, so earlier times can be revisited.
  bool advanceTo(double elapsedSeconds) {
    assert(elapsedSeconds >= 0, 'elapsed must be non-negative');
    _lastElapsedSeconds = elapsedSeconds;
    _resolveUntil(elapsedSeconds);
    _show(elapsedSeconds);
    return isDone;
  }

  void _resolveUntil(double seconds) {
    var stalled = 0;
    var from = _segmentStartSeconds;
    while (!_isDone &&
        !_isWaitingForSync &&
        _period == null &&
        stalled < _maxSegmentsPerCall) {
      if (_segmentStartSeconds - from > _instant) {
        from = _segmentStartSeconds;
        stalled = 0;
      } else {
        stalled++;
      }
      final cut = _cutAt;
      if (cut != null && seconds >= cut) {
        final local = cut - _segmentStartSeconds;
        _sample(local);
        _recordForwardSegmentDuration(local);
        _closeSegment(cut, local);
        _advanceStep();
        continue;
      }

      final local = seconds - _segmentStartSeconds;
      if (!_findSegmentEndBy(local) && !_endRoundsOnto(seconds, local)) {
        return;
      }
      final completionSeconds = _segmentDuration;
      // Compared where the segment is closed, so that a time that rounds
      // onto the end is past it however playback got there.
      if (completionSeconds == null ||
          seconds < _segmentStartSeconds + completionSeconds) {
        return;
      }
      _sample(completionSeconds);
      _recordForwardSegmentDuration(completionSeconds);

      if (_inStep && _steps[_stepIndex] is StepSync<T>) {
        // Hold here until the TrackController calls releaseSync().
        _segmentStartSeconds += completionSeconds;
        _isWaitingForSync = true;
        return;
      }

      _closeSegment(
        _segmentStartSeconds + completionSeconds,
        completionSeconds,
      );
      _advanceStep();
    }
  }

  /// How far into the running segment its end is searched for at [seconds]:
  /// [local], `seconds - start`, or one rounding step further when a
  /// segment a hair longer than [local] still ends at [seconds] once its
  /// start is added. The search finds the same end either way.
  double _searchedLocal(double seconds, double local) {
    if (local < 0 || !seconds.isFinite) return local;
    if (_segmentStartSeconds + justAfter(local) > seconds) return local;
    return local + (justAfter(seconds) - seconds);
  }

  /// Whether the running segment's end, not found by [local], is found
  /// [_searchedLocal] further. That can only be when the search stopped
  /// within a rounding step of [local], so that is checked first.
  bool _endRoundsOnto(double seconds, double local) {
    if (_scanLow - local > seconds.abs() * 1e-15) return false;
    return _findSegmentEndBy(_searchedLocal(seconds, local));
  }

  /// Ends the segment being resolved at [seconds], where the next one starts,
  /// after it played for [local] seconds.
  void _closeSegment(double seconds, double local) {
    _segments.last
      ..end = seconds
      ..duration = local;
    _segmentStartSeconds = seconds;
  }

  /// Samples the segment table at [seconds] into the view buffers.
  void _show(double seconds) {
    var local = seconds;
    _viewCycleShift = 0;
    _viewTimeShift = 0;
    // A cycle too short to divide by, such as one of zero-length steps, is
    // shown where it ends.
    if (_period case final period? when period > _minFoldPeriod) {
      final foldEnd = _foldStartSeconds + period;
      if (seconds >= foldEnd) {
        final periods = ((seconds - _foldStartSeconds) / period).floor();
        _viewCycleShift = periods;
        _viewTimeShift = periods * period;
        // Rounding can land a hair before the repeating window.
        local = math.max(seconds - _viewTimeShift, _foldStartSeconds);
      }
    }

    final last = _segments.length - 1;
    _viewIndex = _segments[last].start <= local ? last : _segmentIndexAt(local);
    final segment = _segments[_viewIndex];
    final end = segment.end;
    // A segment that ended shows where it was resolved to end: `end - start`
    // can round to just before that, where a curve isn't on its target yet.
    var t =
        end != null && end <= local ? segment.duration! : local - segment.start;
    if (t < 0) t = 0;
    final simulations = segment.simulations;
    CurveSimulation? shared;
    var progress = 0.0;
    for (var i = 0; i < simulations.length; i++) {
      final simulation = simulations[i];
      if (simulation is CurveSimulation) {
        if (shared == null || !simulation.sharesTiming(shared)) {
          shared = simulation;
          progress = simulation.progressAt(t);
        }
        _viewValues[i] = simulation.valueAt(progress);
      } else {
        _viewValues[i] = simulation.x(t);
      }
    }
    _viewSimulations = simulations;
    _viewTime = t;
    // Past the end of playback, it has been at rest for that long.
    _viewAtRest = end != null && local - end > _instant;
    _viewVelocitiesStale = true;
  }

  void _showVelocities() {
    if (!_viewVelocitiesStale) return;
    _viewVelocitiesStale = false;
    if (_viewAtRest) {
      _viewVelocities.fillRange(0, _viewVelocities.length, 0);
      return;
    }
    final simulations = _viewSimulations;
    for (var i = 0; i < simulations.length; i++) {
      _viewVelocities[i] = simulations[i].dx(_viewTime);
    }
  }

  /// The index of the last segment starting at or before [seconds].
  int _segmentIndexAt(double seconds) {
    var low = 0;
    var high = _segments.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_segments[mid].start <= seconds) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  void _advanceStep() {
    if (_leading) {
      _leading = false;
      _startPlan();
      return;
    }
    _stepIndex += _direction;

    if (_direction > 0 && _stepIndex >= _steps.length) {
      switch (_loop) {
        case LoopMode.none:
          if (_handsOver) {
            _startSettlingTail();
          } else {
            _isDone = true;
          }
          return;
        case LoopMode.loop:
          // The synthetic return step appended at construction has already
          // animated back to the start snapshot, so just continue the next
          // cycle from there without jumping. Timelines without a target
          // motion have no return step, so restart from their initial state.
          if (!_hasReturnStep) {
            _restoreInitialState();
          }
          _stepIndex = 0;
        case LoopMode.pingPong:
          // Reverse direction from the last step.
          _direction = -1;
          _stepIndex = _steps.length - 1;
        case LoopMode.seamless:
          // Jump straight back to the start snapshot and replay. The timeline
          // is expected to end where it began, so the jump is invisible.
          _restoreInitialState();
          _stepIndex = 0;
      }
      _cycleStartSeconds = _segmentStartSeconds;
      _cycle++;
      if (_startCycle()) return;
    } else if (_direction < 0 && _stepIndex < 0) {
      // PingPong: reached start while reversing, so go forward again from
      // step 0 which targets the first step value.
      _direction = 1;
      _cycleStartSeconds = _segmentStartSeconds;
      _stepIndex = 0;
    }

    _startCurrentStep();
  }

  /// Waits for [delay], playing [incoming] or resting, before the first step.
  void _startLead() {
    _leading = true;
    _cutAt = null;
    _simulations = incoming == null ? _hold(_values, delay) : incoming!;
    _plannedEnd = delay;
    _handsOver = incoming != null;
    _startSegmentEnd();
    _segments.add(
      _Segment(
        stepIndex: -1,
        direction: 1,
        cycle: 0,
        start: _segmentStartSeconds,
        simulations: _simulations,
        tail: true,
      ),
    );
  }

  /// Starts the first step, after any delay. [incoming] plays on through
  /// leading holds and barriers.
  void _startPlan() {
    _cycleStartSeconds = _segmentStartSeconds;
    if (incoming == null) {
      // The hold of a delay has no velocity; the plan starts with its own.
      _copyInto(_velocities, _initialVelocities);
      // The motion handed over is not part of what a later cycle repeats.
      if (_loop.isLooping) _recordCycleStart();
    }
    _handsOver = incoming != null;
    _startCurrentStep();
  }

  /// Records the start of a new loop cycle and folds playback when the cycle
  /// repeats an earlier one. Returns true when resolution stops.
  bool _startCycle() {
    _recordCycleStart();
    if (_canFold && _cycleStarts.length > 1) {
      final current = _cycleStarts.last;
      final earlier = _cycleStarts[_cycleStarts.length - 2];
      if (current.repeats(earlier)) {
        _cycleStarts.removeLast();
        _period = current.start - earlier.start;
        _foldStartSeconds = earlier.start;
        return true;
      }
    }
    if (!_canFold || _cycle >= _foldAttempts) _dropOldCycles();
    return false;
  }

  void _recordCycleStart() {
    _cycleStarts.add(
      _CycleStart(
        cycle: _cycle,
        direction: _direction,
        start: _segmentStartSeconds,
        values: List.of(_values),
        velocities: List.of(_velocities),
      ),
    );
  }

  /// Bounds memory for loops that cannot fold by forgetting their oldest
  /// cycles beyond [_maxKeptSegments], or all but the last two without
  /// inspection tooling. Seeking before the cycles kept shows the earliest
  /// one kept.
  void _dropOldCycles() {
    final budget = MotorInspectionRegistry.isInspecting ? _maxKeptSegments : 0;
    final excess = _segments.length - budget;
    if (excess <= 0) return;
    final oldest = math.min(_segments[excess - 1].cycle, _cycle - 2);
    final drop = _segments.indexWhere((segment) => segment.cycle > oldest);
    if (drop > 0) {
      _segments.removeRange(0, drop);
      _reportedIndex = math.max(-1, _reportedIndex - drop);
    }
    _cycleStarts.removeWhere((start) => start.cycle <= oldest);
  }

  void _recordForwardSegmentDuration(double seconds) {
    if (_direction > 0 && _inStep) {
      _forwardSegmentSeconds[_stepIndex] = seconds;
    }
  }

  int get _dimensions => _initialValues.length;

  /// Resolves the per-dimension motions for a step, or `null` if no motion is
  /// available from the step or the fallback.
  ///
  /// Priority (most specific first): the step's per-dimension motions, the
  /// step's single motion (applied to every dimension), the track's
  /// [_fallbackMotionPerDimension], then the track's single [_fallbackMotion].
  List<Motion>? _motionsOrNull(Motion? stepMotion, List<Motion>? stepPerDim) {
    if (stepPerDim != null) return _checkLength(stepPerDim);
    if (stepMotion != null) return List<Motion>.filled(_dimensions, stepMotion);
    if (_fallbackMotionPerDimension case final perDim?) {
      return _checkLength(perDim);
    }
    if (_fallbackMotion case final m?) {
      return List<Motion>.filled(_dimensions, m);
    }
    return null;
  }

  /// Like [_motionsOrNull] but asserts that a motion is available.
  List<Motion> _motions(Motion? stepMotion, List<Motion>? stepPerDim) {
    final motions = _motionsOrNull(stepMotion, stepPerDim);
    assert(
      motions != null,
      'TrackStep has no motion and no fallback motion was provided. '
      'Either pass a motion to the step or set a default motion on the Track.',
    );
    return motions!;
  }

  List<Motion> _checkLength(List<Motion> motions) {
    assert(
      motions.length == _dimensions,
      'motionPerDimension length (${motions.length}) must match the number of '
      'normalized dimensions ($_dimensions).',
    );
    return motions;
  }

  void _startCurrentStep() {
    _plannedEnd = null;
    _askEnd = false;
    _handedOver = _handsOver;
    _handsOver = false;
    if (_direction < 0) {
      _startReverseStep();
    } else {
      _startForwardStep();
    }
    _startSegmentEnd();
    if (!_loop.isLooping && _stepIndex == _steps.length - 1) {
      _lastEndsAt =
          _segmentStartSeconds + (_lastStepSeconds() ?? double.infinity);
    }
    _segments.add(
      _Segment(
        stepIndex: _stepIndex,
        direction: _direction,
        cycle: _cycle,
        start: _segmentStartSeconds,
        simulations: _simulations,
        // A motion that arrives at once, such as Motion.instant(), is already
        // at its target at time 0, so its direction needs the start values.
        from: converter is DirectionalMotionConverter<T>
            ? List.of(_values)
            : null,
      ),
    );
    _scheduleCutForNextAt();
  }

  /// After a last hold or barrier that a spring kept settling through, plays
  /// the spring out until it has settled: the timeline never cuts a motion
  /// short.
  void _startSettlingTail() {
    _stepIndex = _steps.length - 1;
    _settlingTail = true;
    _cutAt = null;
    _plannedEnd = null;
    _handedOver = true;
    _handsOver = false;
    _simulations = _handedSimulations();
    _askEnd = true;
    _startSegmentEnd();
    _segments.add(
      _Segment(
        stepIndex: _stepIndex,
        direction: _direction,
        cycle: _cycle,
        start: _segmentStartSeconds,
        simulations: _simulations,
        tail: true,
      ),
    );
  }

  void _startForwardStep() {
    final step = _steps[_stepIndex];
    if (_stepIndex > 0 && _endsFree[_stepIndex - 1]) {
      _forwardStarts[_stepIndex] = List.of(_values);
    }
    _simulations = switch (step) {
      StepTo<T>(:final motion, :final motionPerDimension) => _simulateTo(
          _motions(motion, motionPerDimension),
          _waypoints[_stepIndex],
        ),
      StepFree<T>(:final motion) => _simulateFree(motion),
      StepHold<T>(:final duration) => _wait(duration.toSeconds()),
      StepAt<T>(:final at, :final motion, :final motionPerDimension) =>
        _simulateAt(at, _motions(motion, motionPerDimension)),
      StepSync<T>() => _wait(0),
    };
  }

  /// Waits for [seconds] at the current value, or while the simulations the
  /// step before handed over keep playing out.
  List<Simulation> _wait(double seconds) {
    if (!_handedOver) return _hold(_values, seconds);
    _plannedEnd = seconds;
    _handsOver = true;
    return _handedSimulations();
  }

  /// The simulations the step before handed over, continued from where it
  /// ended; for the first step, [incoming].
  List<Simulation> _handedSimulations() {
    if (_segments.isEmpty) return incoming!;
    final previous = _segments.last;
    final offset = previous.duration!;
    return [
      for (final simulation in previous.simulations)
        _ContinuedSimulation.after(simulation, offset),
    ];
  }

  List<Simulation> _simulateFree(FreeMotion motion) {
    _askEnd = true;
    if (_isFollowed()) _planHandOver([motion]);
    return [
      for (var i = 0; i < _values.length; i++)
        motion.createSimulation(start: _values[i], velocity: _velocities[i]),
    ];
  }

  /// Holds [values] for [seconds].
  List<Simulation> _hold(List<double> values, double seconds) {
    _plannedEnd = seconds;
    return [
      for (final value in values)
        _HoldSimulation(value: value, seconds: seconds),
    ];
  }

  List<Simulation> _simulateTo(List<Motion> motions, List<double> targets) {
    _askEnd = true;
    if (_isFollowed()) _planHandOver(motions);
    return [
      for (var i = 0; i < targets.length; i++)
        motions[i].createSimulation(
          start: _values[i],
          end: targets[i],
          velocity: _velocities[i],
        ),
    ];
  }

  List<Simulation> _simulateAt(Duration at, List<Motion> motions) {
    final targets = _waypoints[_stepIndex];
    final gap = _absoluteTimeFor(at) - _segmentStartSeconds;
    // No time left: arrive right away.
    if (gap.abs() < _instant) return _hold(targets, 0);
    // A positive gap is filled exactly; a negative one means the arrival
    // time already passed, so the motion runs as authored.
    if (gap <= 0) return _simulateTo(motions, targets);
    final duration = Duration(microseconds: (gap * 1000000).round());
    final scaled = _simulateTo(
      [for (final motion in motions) _landing(motion, duration)],
      targets,
    );
    _plannedEnd = gap;
    _handsOver = false;
    return [
      for (var i = 0; i < scaled.length; i++)
        _ArrivalSimulation(scaled[i], arrival: gap, target: targets[i]),
    ];
  }

  /// Starts a step in reverse direction for pingPong mode.
  ///
  /// The target is where the previous step ended (or the initial values for
  /// step 0).
  void _startReverseStep() {
    final targets = _reverseTargets(_stepIndex);
    final step = _steps[_stepIndex];
    final motions = switch (step) {
      StepTo<T>(:final motion, :final motionPerDimension) =>
        _motionsOrNull(motion, motionPerDimension),
      StepAt<T>(:final motion, :final motionPerDimension) => () {
          final resolved = _motionsOrNull(motion, motionPerDimension);
          final forwardSeconds = _forwardSegmentSeconds[_stepIndex];
          if (resolved == null || forwardSeconds == null) return resolved;
          final duration =
              Duration(microseconds: (forwardSeconds * 1000000).round());
          return [
            for (final motion in resolved) _landing(motion, duration),
          ];
        }(),
      StepFree<T>() => null,
      StepHold<T>() => null,
      StepSync<T>() => null,
    };

    if (motions != null) {
      _simulations = _simulateTo(motions, targets);
    } else {
      // For free/hold steps in reverse, use a hold at current values with the
      // same duration.
      final duration = switch (step) {
        StepHold<T>(:final duration) => duration.toSeconds(),
        _ => 0.0,
      };
      _simulations = _wait(duration);
    }
  }

  /// When the running step, the last one, ends: its motion's duration, a
  /// hold's duration or a `.at`'s arrival, whatever its [WaitUntil]. Null if
  /// it ends when it settles.
  double? _lastStepSeconds() => switch (_steps[_stepIndex]) {
        StepSync<T>() => null,
        StepTo<T>(:final motion, :final motionPerDimension) =>
          _stepSeconds(motion, motionPerDimension),
        StepFree<T>(:final motion) => motion.duration?.toSeconds(),
        StepHold<T>() || StepAt<T>() => _plannedEnd,
      };

  /// The [MotionBase.duration] of a target step's motions, as
  /// [_logicalSeconds] of [_motions] finds it, without building the list.
  double? _stepSeconds(Motion? stepMotion, List<Motion>? stepPerDim) {
    if (stepPerDim != null) return _logicalSeconds(stepPerDim);
    if (stepMotion != null) return stepMotion.duration?.toSeconds();
    if (_fallbackMotionPerDimension case final perDim?) {
      return _logicalSeconds(perDim);
    }
    return _fallbackMotion?.duration?.toSeconds();
  }

  /// Whether a step follows the running one, so that with
  /// [WaitUntil.ended] it ends after its motion's [MotionBase.duration]
  /// instead of when it has settled. A last step plays out until settled.
  bool _isFollowed() => _loop.isLooping || _stepIndex < _steps.length - 1;

  /// Ends the running step after its [motions]' [MotionBase.duration], when
  /// it ends at its duration ([WaitUntil.ended]) instead of once settled, so
  /// that the next step takes over then.
  void _planHandOver(List<MotionBase> motions) {
    final until = switch (_steps[_stepIndex]) {
      StepTo<T>(:final until) || StepFree<T>(:final until) => until,
      _ => WaitUntil.settled,
    };
    if (until != WaitUntil.ended) return;
    if (_logicalSeconds(motions) case final seconds?) {
      _plannedEnd = seconds;
      _handsOver = true;
    }
  }

  /// The longest [MotionBase.duration] of [motions], in seconds, or null if
  /// one has none.
  static double? _logicalSeconds(List<MotionBase> motions) {
    var longest = 0.0;
    for (final motion in motions) {
      final duration = motion.duration;
      if (duration == null) return null;
      final seconds = duration.toSeconds();
      if (seconds > longest) longest = seconds;
    }
    return longest;
  }

  /// [motion] played over exactly [duration], landing on its target. A
  /// motion that keeps settling after its [Motion.duration] is cut there
  /// first, so that it lands at its natural speed when [duration] matches.
  static Motion _landing(Motion motion, Duration duration) {
    final length = motion.duration;
    final lands = length != null && motion.needsSettle
        ? CutMotion(motion, duration: length)
        : motion;
    return lands.scaleTo(duration);
  }

  /// Decides when the running step yields to a following [StepAt].
  ///
  /// A [StepAt] arrives at its value exactly at its time. If the running step
  /// ends at least the [StepAt] motion's natural length before then, that
  /// motion slows down to fill the gap. Otherwise the running step is cut
  /// short so the motion runs its natural length, but never before the
  /// running step started. Both cases meet where the gap equals the natural
  /// length, so timing changes continuously with the arrival time. The
  /// natural length is the motion's [Motion.duration], or when its move from
  /// where the running step ends settles if it has none.
  void _scheduleCutForNextAt() {
    _cutAt = null;
    if (_direction < 0 || _steps[_stepIndex] is StepSync<T>) return;
    final next = _stepIndex + 1;
    if (next >= _steps.length) return;
    if (_steps[next]
        case StepAt<T>(:final at, :final motion, :final motionPerDimension)) {
      final arrival = _absoluteTimeFor(at);
      final duration = _findSegmentEnd();
      final atDuration =
          _atNaturalSeconds(next, motion, motionPerDimension, duration);
      if (duration != null) {
        // A motion of unknown duration can stretch over any gap.
        final gap = arrival - (_segmentStartSeconds + duration);
        if (gap >= (atDuration ?? 0)) return;
      }
      _cutAt = atDuration == null
          ? _segmentStartSeconds
          : math.max(_segmentStartSeconds, arrival - atDuration);
    }
  }

  /// When the phase of a phase timeline playing now started, as its
  /// [PhaseBoundary] was released, or never.
  var _phaseStartSeconds = double.negativeInfinity;

  /// When a keyframe at [at] arrives: [at] after the start of the cycle, or
  /// of the phase of a phase timeline that started since.
  double _absoluteTimeFor(Duration at) =>
      math.max(_cycleStartSeconds, _phaseStartSeconds) + at.toSeconds();

  void _sample(double localSeconds) {
    final t = localSeconds < 0 ? 0.0 : localSeconds;
    final simulations = _simulations;
    assert(
      simulations.length == _values.length,
      'step has ${simulations.length} dimensions, expected ${_values.length}',
    );
    for (var i = 0; i < simulations.length; i++) {
      _values[i] = simulations[i].x(t);
      _velocities[i] = simulations[i].dx(t);
    }
  }

  bool _segmentIsDone(double localSeconds) {
    for (final simulation in _simulations) {
      if (!simulation.isDone(localSeconds)) return false;
    }
    return true;
  }

  /// Starts finding when the running segment ends.
  ///
  /// Holds, sync barriers, `.at` arrivals and steps a later motion takes over
  /// from know it up front. Otherwise it is found lazily, as time passes: on
  /// the grid of [nextSettleScan] from the segment's start, the first point
  /// where its simulations report done. They are then asked for the exact
  /// end ([SettlingSimulation.settlesAt]), which is never before the last
  /// point that isn't done; one without the mixin is bisected between the
  /// two grid points. A look-ahead asks right away instead of searching the
  /// grid when every simulation has the mixin. A simulation that never
  /// settles leaves the segment open: it keeps playing until it is retargeted
  /// or stopped.
  ///
  /// The end depends only on the segment, so ticking and seeking always
  /// agree. See [_findSegmentEndBy].
  void _startSegmentEnd() {
    _segmentEndFound = false;
    _scanLow = 0;
    _scanHigh = 0;
    if (_plannedEnd case final end?) _endSegmentAt(end);
    assert(
      !_loop.isLooping || _segmentEndFound || !_neverEnds(),
      'Step $_stepIndex of a looping plan never ends: its motion never '
      'settles (settlesAt is null) and the step does not end at a '
      'duration, so the loop would never repeat. Give the step '
      'until: WaitUntil.ended and the motion a duration, or play the step '
      'without looping.',
    );
  }

  /// Whether one of the running segment's simulations never settles.
  bool _neverEnds() {
    if (!_askEnd) return false;
    for (final simulation in _simulations) {
      if (settleSecondsOf(simulation) == null) return true;
    }
    return false;
  }

  /// Asks the running segment's simulations when it ends, the first time
  /// only: when the last one settles, or never if one doesn't. Returns false
  /// if there's nothing to ask.
  ///
  /// A simulation without [SettlingSimulation] is bisected between the last
  /// grid point that isn't done and [doneAt], the grid point where all are
  /// done. Without [doneAt] the grid found none, so it never settles.
  bool _askSegmentEnd({double? doneAt}) {
    if (!_askEnd) return false;
    _askEnd = false;
    var end = 0.0;
    for (final simulation in _simulations) {
      final seconds = simulation is SettlingSimulation
          ? settleSecondsOf(simulation)
          : doneAt == null
              ? null
              : bisectDone(simulation, _scanLow, doneAt);
      if (seconds == null) {
        _endSegmentAt(null);
        return true;
      }
      if (seconds > end) end = seconds;
    }
    // Just after the last grid point found not done, if any, so that a
    // simulation whose isDone flickers ends where the grid says.
    _endSegmentAt(_scanHigh > 0 ? math.max(end, justAfter(_scanLow)) : end);
    return true;
  }

  void _endSegmentAt(double? duration) {
    _segmentDuration = duration;
    _segmentEndFound = true;
  }

  /// Searches the grid points up to the first one at or past [local] seconds
  /// into the running segment. Returns whether the end was found, which it
  /// always is when it lies at or before [local].
  bool _findSegmentEndBy(double local) {
    while (!_segmentEndFound && (_scanLow < local || _scanHigh <= local)) {
      final high = _scanHigh;
      if (_segmentIsDone(high)) {
        if (!_askSegmentEnd(doneAt: high)) _endSegmentAt(high);
      } else {
        _scanLow = high;
        if (high >= settleSearchSeconds) {
          if (!_askSegmentEnd()) _endSegmentAt(null);
        } else {
          _scanHigh = high == 0 ? settleScanStep : nextSettleScan(high);
        }
      }
    }
    return _segmentEndFound;
  }

  /// How long the running segment lasts, or null if it never settles,
  /// searching ahead as far as needed. Simulations that all say when they
  /// settle are asked right away.
  double? _findSegmentEnd() {
    if (!_segmentEndFound &&
        _simulations.every((simulation) => simulation is SettlingSimulation) &&
        _askSegmentEnd()) {
      return _segmentDuration;
    }
    _findSegmentEndBy(double.infinity);
    return _segmentDuration;
  }
}

/// One resolved step: its simulations and the time range it occupies.
class _Segment {
  _Segment({
    required this.stepIndex,
    required this.direction,
    required this.cycle,
    required this.start,
    required this.simulations,
    this.from,
    this.tail = false,
  });

  final int stepIndex;
  final int direction;
  final int cycle;
  final double start;
  final List<Simulation> simulations;

  /// The normalized values the segment started from, when its direction may
  /// be asked for.
  final List<double>? from;

  /// Whether this segment plays out the last step's simulations after it
  /// ended, rather than a step of its own.
  final bool tail;

  /// When the segment ends, or null while it is still running.
  double? end;

  /// How long the segment played, once it ended: the local time it was
  /// resolved to end at, which `end - start` can miss by a rounding step.
  double? duration;

  /// Whether the segment heads for a smaller value, once computed; null
  /// until then, and also when the segment has no direction.
  bool? movesDown;
}

/// The state playback was in when a loop cycle started.
class _CycleStart {
  _CycleStart({
    required this.cycle,
    required this.direction,
    required this.start,
    required this.values,
    required this.velocities,
  });

  final int cycle;
  final int direction;
  final double start;
  final List<double> values;
  final List<double> velocities;

  bool repeats(_CycleStart other) =>
      direction == other.direction &&
      _near(values, other.values) &&
      _near(velocities, other.velocities);

  static bool _near(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-9 * math.max(1, a[i].abs())) return false;
    }
    return true;
  }
}

/// Plays [inner] until [arrival], and holds [target] exactly from then on,
/// so a [StepAt] lands on its value at its time whatever the motion.
///
/// From [arrival] on it reports the velocity it arrived with, so that a step
/// taking over then keeps the slope. A hold or barrier after it, and the
/// last step, come to rest instead.
class _ArrivalSimulation extends Simulation with SettlingSimulation {
  _ArrivalSimulation(
    this.inner, {
    required this.arrival,
    required this.target,
  });

  final Simulation inner;
  final double arrival;
  final double target;

  @override
  Duration get settlesAt => settlingDurationOf(arrival)!;

  @override
  double x(double time) => time >= arrival ? target : inner.x(time);

  @override
  double dx(double time) => inner.dx(time < arrival ? time : arrival);

  @override
  bool isDone(double time) => time >= arrival;
}

/// [inner] from [offset] seconds on.
class _ContinuedSimulation extends Simulation with SettlingSimulation {
  _ContinuedSimulation._(this.inner, this.offset);

  factory _ContinuedSimulation.after(Simulation simulation, double offset) =>
      simulation is _ContinuedSimulation
          ? _ContinuedSimulation._(simulation.inner, simulation.offset + offset)
          : _ContinuedSimulation._(simulation, offset);

  final Simulation inner;
  final double offset;

  @override
  late final Duration? settlesAt = switch (settleSecondsOf(inner)) {
    final seconds? => settlingDurationOf(math.max(0, seconds - offset)),
    null => null,
  };

  @override
  double x(double time) => inner.x(offset + time);

  /// At rest once [inner] is done: a curve keeps reporting the slope it
  /// ended with, for a step that takes over right then, but a hold or
  /// barrier after it holds still.
  @override
  double dx(double time) =>
      inner.isDone(offset + time) ? 0 : inner.dx(offset + time);

  @override
  bool isDone(double time) => inner.isDone(offset + time);
}

class _HoldSimulation extends Simulation with SettlingSimulation {
  _HoldSimulation({
    required this.value,
    required this.seconds,
  });

  final double value;
  final double seconds;

  @override
  Duration get settlesAt => settlingDurationOf(seconds)!;

  @override
  double x(double time) => value;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= seconds;
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
