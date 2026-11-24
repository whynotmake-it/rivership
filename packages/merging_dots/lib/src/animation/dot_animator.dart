import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/model/dot_state.dart';
import 'package:motor/motor.dart';

/// Moves the channels of every dot from one [DotState] to the next and plays
/// [DotSequence]s.
///
/// All dots share a single motor simulation, sampled with a per-dot time
/// shift for staggers. Because a spring is linear in its start conditions,
/// a dot that is already moving keeps its velocity when retargeted: its
/// value is `from + (to - from) * p(t) + v * q(t)`, where `p` is the
/// simulation from 0 to 1 at rest and `q` the response to a unit velocity.
/// A frame is therefore two simulation samples per distinct delay plus a
/// multiply-add per channel, and dots that don't move cost nothing.
///
/// Listeners are notified every frame the values change; render objects
/// listen directly, so an animating dot widget never rebuilds or lays out.
class DotAnimator<T extends DotState> extends ChangeNotifier {
  /// Creates an animator showing [initial], ticking with [vsync].
  DotAnimator({required TickerProvider vsync, required T initial})
    : _target = initial,
      _stride = initial.channels {
    _ticker = vsync.createTicker(_tick);
    _resize(initial.dotCount);
    initial.writeChannels(_values);
  }

  final int _stride;

  late final Ticker _ticker;

  Float32List _values = Float32List(0);
  Float32List _from = Float32List(0);
  Float32List _to = Float32List(0);
  Float32List _velocity = Float32List(0);
  Float64List _delays = Float64List(0);
  Int32List _moving = Int32List(0);
  int _movingCount = 0;
  int _count = 0;

  T _target;
  Simulation? _progress;
  Simulation? _momentum;
  double _staggerSeconds = 0;
  double _maxDelay = 0;
  double _arriveAfter = 0;

  double _elapsed = 0;
  double _segmentStart = 0;
  double? _settledAt;

  DotSequence<T>? _sequence;
  int _frame = 0;
  int _direction = 1;
  bool _paused = false;

  int _revision = 0;

  /// Called when a sequence starts moving to frame `index`.
  ValueChanged<int>? onFrame;

  /// Called when a sequence that doesn't loop is over: its last frame was
  /// reached and held. It may still be settling, and the callback may start
  /// the next animation right away, keeping its momentum.
  VoidCallback? onSequenceEnd;

  /// The current channels of every dot, [DotState.channels] per dot.
  ///
  /// Only the first `dotCount * channels` values are used.
  Float32List get values => _values;

  /// How many dots [values] currently holds.
  ///
  /// While a cloud gains or loses dots, this includes the dots that are
  /// still shrinking away.
  int get dotCount => _count;

  /// The state the dots move to or rest on.
  T get target => _target;

  /// Increases whenever [values] change.
  int get revision => _revision;

  /// Whether dots are moving or a sequence is playing.
  bool get isAnimating => _ticker.isActive;

  /// The frame of the playing sequence the dots move to or rest on.
  int get frame => _frame;

  /// Whether a sequence is paused.
  bool get isPaused => _paused;

  /// Moves the dots to [state] with [motion], delayed per dot by [stagger].
  ///
  /// Stops a playing sequence. Dots that are moving keep their momentum.
  void animateTo(
    T state, {
    Motion motion = const CupertinoMotion.smooth(),
    DotStagger stagger = const DotStagger.none(),
  }) {
    _sequence = null;
    _paused = false;
    _moveTo(state, motion, stagger);
  }

  /// Shows [state] right away.
  ///
  /// Stops a playing sequence.
  void jumpTo(T state) {
    _sequence = null;
    _paused = false;
    _jump(state);
  }

  /// Plays [sequence], moving to its first frame from wherever the dots are.
  ///
  /// When [restart] is false and [sequence] has as many frames as the one
  /// playing, playback continues at the current frame instead.
  void play(DotSequence<T> sequence, {bool restart = true}) {
    final previous = _sequence;
    _sequence = sequence;
    _paused = false;
    if (!restart &&
        previous != null &&
        previous.frames.length == sequence.frames.length) {
      final frame = sequence.frames[_frame];
      if (frame.state != _target) {
        _moveTo(
          frame.state,
          sequence.motionInto(_frame),
          sequence.staggerInto(_frame),
        );
      }
      _ensureTicking();
      return;
    }
    _frame = 0;
    _direction = 1;
    _enterFrame(0);
  }

  /// Freezes the dots where they are.
  void pause() {
    if (_paused) return;
    _paused = true;
    _ticker.stop();
  }

  /// Continues after [pause].
  void resume() {
    if (!_paused) return;
    _paused = false;
    _ensureTicking(resume: true);
  }

  void _enterFrame(int index) {
    final sequence = _sequence!;
    onFrame?.call(index);
    _moveTo(
      sequence.frames[index].state,
      sequence.motionInto(index),
      sequence.staggerInto(index),
    );
    // A sequence keeps ticking while it holds.
    _ensureTicking();
  }

  void _jump(T state) {
    _ticker.stop();
    _target = state;
    _progress = null;
    _momentum = null;
    _movingCount = 0;
    _settledAt = 0;
    _arriveAfter = 0;
    _resize(state.dotCount);
    state.writeChannels(_values);
    _changed();
  }

  void _moveTo(T state, Motion motion, DotStagger stagger) {
    assert(
      state.channels == _stride,
      'All states of one animator need the same number of channels.',
    );
    if (!_target.canAnimateTo(state) || motion.duration == Duration.zero) {
      final sequence = _sequence;
      _jump(state);
      _sequence = sequence;
      _segmentStart = _elapsed;
      if (sequence != null) _ensureTicking();
      return;
    }

    _sampleVelocities();

    final previousCount = _count;
    final targetCount = state.dotCount;
    final count = math.max(previousCount, targetCount);
    final sizeChannel = state.sizeChannel;

    final from = Float32List(count * _stride)
      ..setRange(0, previousCount * _stride, _values);
    final to = Float32List(count * _stride);
    state.writeChannels(to);
    final velocity = Float32List(count * _stride)
      ..setRange(
        0,
        math.min(_velocity.length, previousCount * _stride),
        _velocity,
      );

    // Dots that appear grow where they will be, dots that disappear shrink
    // where they are.
    for (var i = previousCount; i < count; i++) {
      final o = i * _stride;
      for (var c = 0; c < _stride; c++) {
        from[o + c] = c == sizeChannel ? 0 : to[o + c];
      }
    }
    for (var i = targetCount; i < count; i++) {
      final o = i * _stride;
      for (var c = 0; c < _stride; c++) {
        to[o + c] = c == sizeChannel ? 0 : from[o + c];
      }
    }

    final moving = Int32List(count);
    var movingCount = 0;
    var hasMomentum = false;
    for (var i = 0; i < count; i++) {
      final o = i * _stride;
      var moves = false;
      for (var c = 0; c < _stride; c++) {
        if (from[o + c] != to[o + c] || velocity[o + c] != 0) moves = true;
        if (velocity[o + c] != 0) hasMomentum = true;
      }
      if (moves) moving[movingCount++] = i;
    }

    final delays = Float64List(count);
    _staggerSeconds =
        stagger.duration.inMicroseconds / Duration.microsecondsPerSecond;
    if (_staggerSeconds > 0) {
      stagger.computeDelays(
        delays,
        count,
        (i) => i < targetCount
            ? state.normalizedPosition(i)
            : const Offset(0.5, 0.5),
      );
    }
    var maxDelay = 0.0;
    for (var m = 0; m < movingCount; m++) {
      maxDelay = math.max(maxDelay, delays[moving[m]]);
    }

    _values = Float32List.fromList(from);
    _from = from;
    _to = to;
    _velocity = velocity;
    _delays = delays;
    _moving = moving;
    _movingCount = movingCount;
    _maxDelay = maxDelay;
    _count = count;
    _target = state;
    _progress = motion.createSimulation();
    _momentum = hasMomentum
        ? motion.createSimulation(end: 0, velocity: 1)
        : null;
    _segmentStart = _ticker.isActive ? _elapsed : 0;
    _settledAt = null;
    final duration = motion.duration;
    _arriveAfter = duration == null
        ? double.infinity
        : duration.inMicroseconds / Duration.microsecondsPerSecond +
              maxDelay * _staggerSeconds;

    if (movingCount == 0) {
      _settle();
    }
    _ensureTicking();
  }

  /// Writes the velocity of every dot at the current time into [_velocity].
  void _sampleVelocities() {
    final progress = _progress;
    if (progress == null || _settledAt != null) {
      _velocity = Float32List(_count * _stride);
      return;
    }
    final momentum = _momentum;
    final t = _elapsed - _segmentStart;
    final velocity = Float32List(_count * _stride);
    for (var m = 0; m < _movingCount; m++) {
      final i = _moving[m];
      final tau = t - _delays[i] * _staggerSeconds;
      if (tau <= 0) continue;
      final dp = progress.dx(tau);
      final dq = momentum?.dx(tau) ?? 0;
      final o = i * _stride;
      for (var c = 0; c < _stride; c++) {
        velocity[o + c] =
            (_to[o + c] - _from[o + c]) * dp + _velocity[o + c] * dq;
      }
    }
    _velocity = velocity;
  }

  void _ensureTicking({bool resume = false}) {
    if (_paused || _ticker.isActive) return;
    if (_progress == null && _sequence == null) return;
    // The ticker's clock restarts at zero, so move the segment with it.
    final t = _elapsed - _segmentStart;
    _elapsed = 0;
    if (resume) {
      _segmentStart = -t;
    } else {
      _segmentStart = 0;
      if (_settledAt != null) _settledAt = 0;
    }
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    // A frame can pass several short keyframes; catch up on all of them.
    for (var step = 0; step < 32 && _advance(); step++) {}
  }

  /// Applies the current segment at [_elapsed], and moves on to the next
  /// keyframe if this one is over. Returns whether it moved on.
  ///
  /// A keyframe starts exactly when the previous one was due to end, not
  /// at the frame that noticed, so short steps keep their timing instead of
  /// each rounding up to the next frame.
  bool _advance() {
    final t = _elapsed - _segmentStart;

    if (_settledAt == null) {
      _apply(t);
      final progress = _progress!;
      final tEnd = t - _maxDelay * _staggerSeconds;
      final done =
          tEnd > 0 &&
          progress.isDone(tEnd) &&
          (_momentum == null || _momentum!.isDone(tEnd));
      if (done) {
        _settledAt = t;
        _settle();
      } else {
        _changed();
      }
    }

    final settledAt = _settledAt;
    final sequence = _sequence;
    if (sequence == null) {
      if (settledAt != null) _ticker.stop();
      return false;
    }
    // A frame counts as reached once its motion's duration is over, even if
    // a spring is still settling, so loops flow on with their momentum.
    final arrivedAt = math.min(settledAt ?? double.infinity, _arriveAfter);
    final hold =
        sequence.frames[_frame].hold.inMicroseconds /
        Duration.microsecondsPerSecond;
    if (t - arrivedAt < hold) return false;
    final next = sequence.next(_frame, _direction);
    if (next == null) {
      _sequence = null;
      if (settledAt != null) _ticker.stop();
      onSequenceEnd?.call();
      return false;
    }
    // Start the next keyframe from where this one stood when it was due to
    // end, then let the caller apply it at the current time.
    final boundary = _segmentStart + arrivedAt + hold;
    if (_settledAt == null) _apply(boundary - _segmentStart);
    final now = _elapsed;
    _elapsed = boundary;
    final (frame, direction) = next;
    _frame = frame;
    _direction = direction;
    _enterFrame(_frame);
    _elapsed = now;
    return true;
  }

  void _apply(double t) {
    final progress = _progress!;
    final momentum = _momentum;
    final values = _values;
    final from = _from;
    final to = _to;
    final velocity = _velocity;

    if (_staggerSeconds == 0) {
      final tau = t <= 0 ? 0.0 : t;
      final p = progress.x(tau);
      final q = momentum?.x(tau) ?? 0;
      for (var m = 0; m < _movingCount; m++) {
        final o = _moving[m] * _stride;
        for (var c = o; c < o + _stride; c++) {
          values[c] = from[c] + (to[c] - from[c]) * p + velocity[c] * q;
        }
      }
      return;
    }

    for (var m = 0; m < _movingCount; m++) {
      final i = _moving[m];
      final tau = t - _delays[i] * _staggerSeconds;
      final o = i * _stride;
      if (tau <= 0) {
        for (var c = o; c < o + _stride; c++) {
          values[c] = from[c];
        }
        continue;
      }
      final p = progress.x(tau);
      final q = momentum?.x(tau) ?? 0;
      for (var c = o; c < o + _stride; c++) {
        values[c] = from[c] + (to[c] - from[c]) * p + velocity[c] * q;
      }
    }
  }

  void _settle() {
    _settledAt ??= 0;
    _progress = null;
    _momentum = null;
    _movingCount = 0;
    _resize(_target.dotCount);
    _target.writeChannels(_values);
    _velocity = Float32List(_count * _stride);
    _changed();
  }

  void _resize(int count) {
    _count = count;
    if (_values.length != count * _stride) {
      _values = Float32List(count * _stride);
    }
  }

  void _changed() {
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
