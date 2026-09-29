import 'package:flutter/physics.dart';

/// A [Simulation] that knows its own timing.
///
/// A motion's simulation is one move, from a start value to an end value
/// with a start velocity. With this mixin it tells motor two times, both
/// measured from the start of the move:
///
/// - [duration]: how long a step with this move lasts. In a track, the next
///   step takes over here, from the current value and velocity.
/// - [settlesAt]: when the move is done for good. Futures, `status` and the
///   ticker wait for it, and so does the last step of a track.
///
/// Curves end where their step ends, so both times are equal. A spring's
/// [duration] is its perceptual duration, and it keeps settling for a while
/// after it, under a following hold or barrier, or until [settlesAt] if its
/// step is the last one.
///
/// Every simulation motor creates has this mixin. A simulation without it
/// still works: its step lasts until it has settled, and motor finds when
/// that is by sampling [isDone], for up to two minutes.
///
/// ```dart
/// class _FallSimulation extends Simulation with TimedSimulation {
///   // ...
///   @override
///   Duration? get duration => null; // no pace of its own: until it rests
///
///   @override
///   Duration get settlesAt => _restTime;
/// }
/// ```
mixin TimedSimulation on Simulation {
  /// How long a step with this move lasts, or null if the step lasts until
  /// the move has settled.
  ///
  /// It should not depend on the move, so that loops and staggers keep their
  /// rhythm whatever the distance.
  Duration? get duration;

  /// When the move is done for good, or null if it never is.
  ///
  /// From this time on [isDone] stays true. With a spring's `snapToEnd` the
  /// value is then exactly on the target. A [Duration] has microsecond
  /// resolution, so motor accepts a time up to a microsecond before [isDone]
  /// turns true, and searches for the end if the simulation isn't done by
  /// then.
  Duration? get settlesAt;
}
