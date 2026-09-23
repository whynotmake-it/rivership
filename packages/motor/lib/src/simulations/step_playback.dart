import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
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
        _steps = List.of(steps),
        _converter = converter,
        _loop = loop,
        _fallbackMotion = fallbackMotion,
        _fallbackMotionPerDimension = fallbackMotionPerDimension,
        _start = start,
        _velocity = velocity,
        _initialValues = converter.normalize(start),
        _initialVelocities = switch (velocity) {
          null => List<double>.filled(converter.normalize(start).length, 0),
          final value => converter.normalize(value),
        } {
    _values = List<double>.of(_initialValues, growable: false);
    _velocities = List<double>.of(_initialVelocities, growable: false);
    _viewValues = List<double>.of(_initialValues, growable: false);
    _viewVelocities = List<double>.of(_initialVelocities, growable: false);
    if (loop == LoopMode.loop) {
      // `loop` animates back to the start after the last step. Model that as a
      // synthetic final step that returns to the start snapshot, reusing the
      // first real step's motion(s). The wrap (in `_advanceStep`) then
      // continues from there without a jump. `seamless` skips this and jumps.
      final returnMotions = _firstStepMotions(_steps, _initialValues.length) ??
          _fallbackMotionPerDimension ??
          (fallbackMotion != null
              ? List<Motion>.filled(_initialValues.length, fallbackMotion)
              : null);
      if (returnMotions != null) {
        _steps.add(StepTo<T>(start, motionPerDimension: returnMotions));
        _hasReturnStep = true;
      }
    }
    _canFold = loop.isLooping && !_steps.any((step) => step is StepSync<T>);
    _forwardSegmentSeconds = List<double?>.filled(_steps.length, null);
    _buildWaypoints();
    _recordCycleStart();
    _startCurrentStep();
    _show(0);
    _estimatedSegmentSeconds = List<double?>.filled(_steps.length, null);
  }

  /// Returns the per-dimension motions of the first step that targets a value,
  /// or `null` if no step carries a motion.
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
        default:
          break;
      }
    }
    return null;
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
      }
    }
    return true;
  }

  /// Upper bound on segments resolved in one call, so zero-length loops
  /// cannot spin forever.
  static const _maxSegmentsPerCall = 1000;

  // Segment durations are searched in fine steps up to [_scanLimit] seconds,
  // then in doubling steps up to [_horizon] seconds.
  static const _scanStep = 1 / 60;
  static const _scanLimit = 60.0;
  static const _horizon = 86400.0;

  /// Cycles after which a loop that has not folded is bounded like a loop
  /// with sync steps.
  static const _foldAttempts = 8;

  /// Gaps shorter than this (one microsecond) count as no time at all.
  static const _instant = 1e-6;

  final List<TrackStep<T>> _steps;
  final T _start;
  final T? _velocity;
  final MotionConverter<T> _converter;
  final LoopMode _loop;
  final Motion? _fallbackMotion;
  final List<Motion>? _fallbackMotionPerDimension;
  final List<double> _initialValues;
  final List<double> _initialVelocities;
  var _hasReturnStep = false;

  /// Target values for each step, used by pingPong to reverse.
  /// Index i holds the normalized target that step i animates toward.
  late final List<List<double>> _waypoints;

  /// The duration each step occupied during forward playback.
  late final List<double?> _forwardSegmentSeconds;

  /// Stable predicted durations for the forward playback plan.
  late List<double?> _estimatedSegmentSeconds;

  // Resolution state: the segment currently being resolved, at the end of
  // the table.
  final List<_Segment> _segments = [];
  late final List<double> _values;
  late final List<double> _velocities;
  late List<Simulation> _simulations;
  var _stepIndex = 0;
  var _direction = 1;
  var _cycle = 0;
  var _cycleStartSeconds = 0.0;
  var _segmentStartSeconds = 0.0;
  var _isDone = false;
  var _isWaitingForSync = false;

  /// How long the running segment lasts, or null if it never finishes.
  double? _segmentDuration;

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
  final List<_CycleStart> _cycleStarts = [];
  double? _period;
  var _foldStartSeconds = 0.0;

  // What the most recent advance or seek shows.
  late final List<double> _viewValues;
  late final List<double> _viewVelocities;
  var _lastElapsedSeconds = 0.0;
  var _viewIndex = 0;
  var _viewCycleShift = 0;
  var _viewTimeShift = 0.0;

  // The last segment handed out by [takeEnteredSteps].
  var _reportedIndex = -1;
  var _reportedShift = 0;

  _Segment get _view => _segments[_viewIndex];

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

  /// A fresh copy of this plan that plays its steps once, from the same
  /// start, for resolving ahead without affecting this playback.
  @internal
  StepPlayback<T> fork() => StepPlayback<T>(
        steps: _steps,
        converter: _converter,
        start: _start,
        velocity: _velocity,
        fallbackMotion: _fallbackMotion,
        fallbackMotionPerDimension: _fallbackMotionPerDimension,
      );

  Duration? _knownMotionDuration(
    Motion? motion,
    List<Motion>? motionPerDimension,
  ) {
    final motions = motionPerDimension ??
        (motion == null ? null : [motion]) ??
        _fallbackMotionPerDimension ??
        (_fallbackMotion == null ? null : [_fallbackMotion]);
    if (motions == null || motions.isEmpty) return null;
    var longest = Duration.zero;
    for (final candidate in motions) {
      final duration = candidate.duration;
      if (duration == null) return null;
      if (duration > longest) longest = duration;
    }
    return longest;
  }

  /// Current normalized values, as a live read-only view.
  List<double> get values => UnmodifiableListView(_viewValues);

  /// Current normalized velocities, as a live read-only view.
  List<double> get velocities => UnmodifiableListView(_viewVelocities);

  /// Copies the current normalized values and velocities into [values] and
  /// [velocities] without allocating.
  void copyStateInto(List<double> values, List<double> velocities) {
    _copyInto(values, _viewValues);
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
    _copyInto(_values, _initialValues);
    _copyInto(_velocities, _initialVelocities);
  }

  bool get _viewIsLatest => _viewIndex == _segments.length - 1;

  /// How many resolved segments are kept.
  @visibleForTesting
  int get debugSegmentCount => _segments.length;

  /// The currently active step index.
  int get currentStepIndex => isDone ? -1 : _view.stepIndex;

  /// Whether playback has completed.
  bool get isDone =>
      _isDone && _lastElapsedSeconds >= (_segments.last.end ?? double.infinity);

  /// Whether playback is paused at a [StepSync], waiting for external release.
  bool get isWaitingForSync => _isWaitingForSync && _viewIsLatest;

  /// The token of the [StepSync] currently being waited on, or `null` if
  /// playback is not waiting at a sync barrier.
  Object? get syncToken {
    if (!isWaitingForSync) return null;
    return (_steps[_view.stepIndex] as StepSync<T>).token;
  }

  /// The actual playback plan, including a synthetic loop-return step.
  @internal
  List<TrackStep<T>> get stepsView => List.unmodifiable(_steps);

  /// Whether [stepsView] ends with a synthetic loop-return step.
  @internal
  bool get hasSyntheticReturnStep => _hasReturnStep;

  /// The loop mode used by this playback.
  @internal
  LoopMode get loop => _loop;

  /// Recorded forward segment durations, in seconds.
  @internal
  List<double?> get forwardSegmentSeconds =>
      List.unmodifiable(_forwardSegmentSeconds);

  /// Predicted forward segment durations, set by inspection tooling.
  @internal
  List<double?> get estimatedSegmentSeconds =>
      List.unmodifiable(_estimatedSegmentSeconds);

  @internal
  set estimatedSegmentSeconds(List<double?> value) {
    assert(value.length == _steps.length, 'one estimate per step');
    _estimatedSegmentSeconds = value;
  }

  /// Start times of the forward steps reached so far in the shown cycle, in
  /// slot-local seconds.
  @internal
  List<double?> get stepStartSeconds {
    final starts = List<double?>.filled(_steps.length, null);
    final view = _view;
    for (var i = 0; i <= _viewIndex; i++) {
      final segment = _segments[i];
      if (segment.cycle == view.cycle && segment.direction > 0) {
        starts[segment.stepIndex] = segment.start + _viewTimeShift;
      }
    }
    return starts;
  }

  /// The current playback direction: `1` forward or `-1` reverse.
  @internal
  int get direction => _view.direction;

  /// The number of loop boundaries crossed by this playback.
  @internal
  int get cycle => _view.cycle + _viewCycleShift;

  /// The most recent slot-local elapsed time, in seconds.
  @internal
  double get lastElapsedSeconds => _lastElapsedSeconds;

  /// The slot-local time at which the current loop leg began, in seconds.
  @internal
  double get cycleStartSeconds => _view.cycleStart + _viewTimeShift;

  /// Where the shown segment starts and which value it heads for, or null if
  /// it has no target (a hold, free motion, or sync barrier).
  @internal
  ({List<double> from, List<double> to})? get shownMove {
    final segment = _view;
    final step = _steps[segment.stepIndex];
    if (step is! StepTo<T> && step is! StepAt<T>) return null;
    final index = segment.stepIndex;
    final to = segment.direction > 0
        ? _waypoints[index]
        : (index > 0 ? _waypoints[index - 1] : _initialValues);
    return (
      from: [for (final simulation in segment.simulations) simulation.x(0)],
      to: to,
    );
  }

  /// The resolved segments, oldest first: which step each one plays and when.
  ///
  /// The segment being resolved reports when it is going to end, unless that
  /// is unknown (it waits at a sync barrier or never finishes).
  @internal
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
    if (_steps[_stepIndex] is StepSync<T>) return null;
    final duration = _segmentDuration;
    return _cutAt ??
        (duration == null ? null : _segmentStartSeconds + duration);
  }

  /// Once a loop repeats exactly, how long each repetition lasts, in seconds.
  /// Segments from [loopRepeatStartSeconds] on then repeat with this period.
  @internal
  double? get loopPeriodSeconds => _period;

  /// Where the repeating part of a folded loop starts, in seconds.
  @internal
  double get loopRepeatStartSeconds => _foldStartSeconds;

  /// The indices of the steps entered since the previous call, in order.
  ///
  /// The synthetic return step of [LoopMode.loop] is not included.
  ///
  /// Every step playback passed through is included, even when one advance
  /// crosses several. Moving back in time enters nothing. When one advance
  /// skips whole loop cycles, only the steps of the last cycle entered are
  /// included.
  @internal
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
      final step = _segments[index].stepIndex;
      if (!_hasReturnStep || step != _steps.length - 1) entered.add(step);
    }
    return entered;
  }

  /// The token of the [StepSync] that resolution is held at, or `null`.
  ///
  /// Unlike [syncToken], this does not depend on the time being shown.
  @internal
  Object? get pendingSyncToken {
    if (!_isWaitingForSync) return null;
    return (_steps[_stepIndex] as StepSync<T>).token;
  }

  /// When resolution arrived at the pending [StepSync], in slot-local seconds.
  @internal
  double get pendingSyncArrivalSeconds => _segmentStartSeconds;

  /// Releases the pending [StepSync] at [atSeconds], in slot-local seconds.
  ///
  /// Called by [TrackController] once every track sharing the barrier has
  /// arrived. Playback between the arrival and [atSeconds] holds still.
  void releaseSync({required double atSeconds}) {
    if (!_isWaitingForSync) return;
    _isWaitingForSync = false;
    _closeSegment(math.max(atSeconds, _segmentStartSeconds));
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
    var resolved = 0;
    while (!_isDone &&
        !_isWaitingForSync &&
        _period == null &&
        resolved++ < _maxSegmentsPerCall) {
      final cut = _cutAt;
      if (cut != null && seconds >= cut) {
        final local = cut - _segmentStartSeconds;
        _sample(local);
        _recordForwardSegmentDuration(local);
        _closeSegment(cut);
        _advanceStep();
        continue;
      }

      final completionSeconds = _segmentDuration;
      if (completionSeconds == null ||
          seconds - _segmentStartSeconds < completionSeconds) {
        return;
      }
      _sample(completionSeconds);
      _recordForwardSegmentDuration(completionSeconds);

      if (_steps[_stepIndex] is StepSync<T>) {
        // Hold here until the TrackController calls releaseSync().
        _segmentStartSeconds += completionSeconds;
        _isWaitingForSync = true;
        return;
      }

      _closeSegment(_segmentStartSeconds + completionSeconds);
      _advanceStep();
    }
  }

  /// Ends the segment being resolved at [seconds], where the next one starts.
  void _closeSegment(double seconds) {
    _segments.last.end = seconds;
    _segmentStartSeconds = seconds;
  }

  /// Samples the segment table at [seconds] into the view buffers.
  void _show(double seconds) {
    var local = seconds;
    _viewCycleShift = 0;
    _viewTimeShift = 0;
    if (_period case final period? when period > 0) {
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
    var t = (end != null && end < local ? end : local) - segment.start;
    if (t < 0) t = 0;
    final simulations = segment.simulations;
    for (var i = 0; i < simulations.length; i++) {
      _viewValues[i] = simulations[i].x(t);
      _viewVelocities[i] = simulations[i].dx(t);
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
    _stepIndex += _direction;

    if (_direction > 0 && _stepIndex >= _steps.length) {
      switch (_loop) {
        case LoopMode.none:
          _isDone = true;
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
      // PingPong: reached start while reversing — go forward again from
      // step 0 which targets the first step value.
      _direction = 1;
      _cycleStartSeconds = _segmentStartSeconds;
      _stepIndex = 0;
    }

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
    if (!_canFold || _cycle >= _foldAttempts) _dropOldCycles(keep: 2);
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

  /// Bounds memory for loops that cannot fold by forgetting all but the
  /// last [keep] cycles. Seeking before them shows the earliest one kept.
  void _dropOldCycles({required int keep}) {
    final oldest = _cycle - keep;
    final drop = _segments.indexWhere((segment) => segment.cycle > oldest);
    if (drop > 0) {
      _segments.removeRange(0, drop);
      _reportedIndex = math.max(-1, _reportedIndex - drop);
    }
    _cycleStarts.removeWhere((start) => start.cycle <= oldest);
  }

  void _recordForwardSegmentDuration(double seconds) {
    if (_direction > 0) {
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
    if (_direction < 0) {
      _startReverseStep();
    } else {
      _startForwardStep();
    }
    _segmentDuration = _findSegmentDuration();
    _segments.add(
      _Segment(
        stepIndex: _stepIndex,
        direction: _direction,
        cycle: _cycle,
        cycleStart: _cycleStartSeconds,
        start: _segmentStartSeconds,
        simulations: _simulations,
      ),
    );
    _scheduleCutForNextAt();
  }

  void _startForwardStep() {
    final step = _steps[_stepIndex];
    _simulations = switch (step) {
      StepTo<T>(:final motion, :final motionPerDimension) => () {
          final motions = _motions(motion, motionPerDimension);
          final targets = _waypoints[_stepIndex];
          return [
            for (var i = 0; i < targets.length; i++)
              motions[i].createSimulation(
                start: _values[i],
                end: targets[i],
                velocity: _velocities[i],
              ),
          ];
        }(),
      StepFree<T>(:final motion) => [
          for (var i = 0; i < _values.length; i++)
            motion.createSimulation(
              start: _values[i],
              velocity: _velocities[i],
            ),
        ],
      StepHold<T>(:final duration) => [
          for (final value in _values)
            _HoldSimulation(
              value: value,
              duration: duration.toSeconds(),
            ),
        ],
      StepAt<T>(:final at, :final motion, :final motionPerDimension) => () {
          final motions = _motions(motion, motionPerDimension);
          final targets = _waypoints[_stepIndex];
          final gap = _absoluteTimeFor(at) - _segmentStartSeconds;
          if (gap.abs() < _instant) {
            // No time left: arrive right away.
            return [
              for (final target in targets)
                _HoldSimulation(value: target, duration: 0),
            ];
          }
          // A positive gap is filled exactly; a negative one means the
          // arrival time already passed, so the motion runs as authored.
          final atMotions = gap > 0
              ? [
                  for (final m in motions)
                    m.scaleTo(Duration(microseconds: (gap * 1000000).round())),
                ]
              : motions;
          return [
            for (var i = 0; i < targets.length; i++)
              atMotions[i].createSimulation(
                start: _values[i],
                end: targets[i],
                velocity: _velocities[i],
              ),
          ];
        }(),
      StepSync<T>() => [
          for (final value in _values)
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
    final motions = switch (step) {
      StepTo<T>(:final motion, :final motionPerDimension) =>
        _motionsOrNull(motion, motionPerDimension),
      StepAt<T>(:final motion, :final motionPerDimension) => () {
          final resolved = _motionsOrNull(motion, motionPerDimension);
          final forwardSeconds = _forwardSegmentSeconds[_stepIndex];
          if (resolved == null || forwardSeconds == null) return resolved;
          return [
            for (final motion in resolved)
              motion.scaleTo(
                Duration(
                  microseconds: (forwardSeconds * 1000000).round(),
                ),
              ),
          ];
        }(),
      StepFree<T>() => null,
      StepHold<T>() => null,
      StepSync<T>() => null,
    };

    if (motions != null) {
      _simulations = [
        for (var i = 0; i < targets.length; i++)
          motions[i].createSimulation(
            start: _values[i],
            end: targets[i],
            velocity: _velocities[i],
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
        for (final value in _values)
          _HoldSimulation(value: value, duration: duration),
      ];
    }
  }

  /// Decides when the running step yields to a following [StepAt].
  ///
  /// A [StepAt] arrives at its value exactly at its time. If the running step
  /// ends at least the [StepAt] motion's natural duration before then, the
  /// [StepAt] stretches to fill the gap. Otherwise the running step is cut
  /// short so the motion runs its natural duration, but never before the
  /// running step started. Both cases meet where the gap equals the natural
  /// duration, so timing changes continuously with the arrival time.
  void _scheduleCutForNextAt() {
    _cutAt = null;
    if (_direction < 0 || _steps[_stepIndex] is StepSync<T>) return;
    final next = _stepIndex + 1;
    if (next >= _steps.length) return;
    if (_steps[next]
        case StepAt<T>(:final at, :final motion, :final motionPerDimension)) {
      final arrival = _absoluteTimeFor(at);
      final atDuration =
          _knownMotionDuration(motion, motionPerDimension)?.toSeconds();
      final duration = _segmentDuration;
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

  double _absoluteTimeFor(Duration at) => _cycleStartSeconds + at.toSeconds();

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
    return _simulations.every((simulation) => simulation.isDone(localSeconds));
  }

  /// How long the running segment's simulations take to finish, or null if
  /// they do not finish within a day.
  ///
  /// Found once per segment, independent of how playback is advanced, so
  /// ticking and seeking always agree. A fine forward scan finds the first
  /// time the simulations report done, even for springs whose `isDone`
  /// briefly turns true near oscillation peaks before they settle.
  double? _findSegmentDuration() {
    if (_segmentIsDone(0)) return 0;
    var low = 0.0;
    var high = _scanStep;
    while (!_segmentIsDone(high)) {
      low = high;
      high = high < _scanLimit ? high + _scanStep : high * 2;
      if (high > _horizon) return null;
    }
    while (true) {
      final mid = (low + high) / 2;
      if (mid <= low || mid >= high) return high;
      if (_segmentIsDone(mid)) {
        high = mid;
      } else {
        low = mid;
      }
    }
  }
}

/// One resolved step: its simulations and the time range it occupies.
class _Segment {
  _Segment({
    required this.stepIndex,
    required this.direction,
    required this.cycle,
    required this.cycleStart,
    required this.start,
    required this.simulations,
  });

  final int stepIndex;
  final int direction;
  final int cycle;
  final double cycleStart;
  final double start;
  final List<Simulation> simulations;

  /// When the segment ends, or null while it is still running.
  double? end;
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
