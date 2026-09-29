import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/settling_simulation.dart';
import 'package:motor/src/simulations/simulation_end.dart';

/// A target-based motion that plays [parent] at its own speed and ends at
/// exactly [duration].
///
/// Where [parent] hasn't arrived yet at [duration], the played part is
/// corrected so that the value lands exactly on the target there:
///
/// - The correction grows with [parent]'s own progress from rest, so the
///   start value and velocity are unchanged. For a move from rest this
///   scales the played part by `1 / progress(duration)`: about 1.45% for a
///   [CupertinoMotion] cut at its perceptual duration.
/// - The velocity at [duration] is handed to a following step. A last step
///   stops there, with that velocity.
/// - If [parent] finishes earlier, it holds its target until [duration].
///
/// Its [duration] and its simulation's settle are both [duration], for
/// every move. Playback uses it for `TrackStep.at`, so a motion that keeps
/// settling after its step has ended still lands exactly on its keyframe.
@internal
@immutable
class CutMotion extends Motion {
  /// Creates a motion that plays [parent] and ends at [duration].
  CutMotion(this.parent, {required this.duration})
      : assert(!duration.isNegative, 'duration must not be negative'),
        super(tolerance: parent.tolerance);

  /// The motion that plays until the cut.
  final Motion parent;

  /// When the motion ends.
  @override
  final Duration duration;

  @override
  bool get needsSettle => parent.needsSettle;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _CutSimulation(
        parent.createSimulation(start: start, end: end, velocity: velocity),
        progress: parent.createSimulation(start: 1, end: 0),
        cut: duration.inMicroseconds / Duration.microsecondsPerSecond,
        end: end,
      );

  @override
  bool operator ==(Object other) =>
      other is CutMotion &&
      parent == other.parent &&
      duration == other.duration;

  @override
  int get hashCode => Object.hash(CutMotion, parent, duration);

  @override
  String toString() => 'CutMotion($parent, duration: $duration)';
}

class _CutSimulation extends Simulation with SettlingSimulation {
  _CutSimulation(
    this.parent, {
    required Simulation progress,
    required this.cut,
    required this.end,
  })  : _progress = progress,
        super(tolerance: parent.tolerance) {
    if (cut <= 0) return;
    // Remaining progress from rest: 1 - a(cut) for the step response a.
    final arrived = 1 - progress.x(cut);
    _miss = parent.x(cut) - end;
    _linear = arrived.abs() < 1e-9;
    _scale = _linear ? 1 / cut : 1 / arrived;
  }

  final Simulation parent;
  final Simulation _progress;
  final double cut;
  final double end;
  var _miss = 0.0;
  var _scale = 0.0;
  var _linear = false;

  @override
  Duration get settlesAt => settlingDurationOf(cut)!;

  // How much of the miss at the cut is corrected by [time], from 0 to 1.
  double _share(double time) =>
      _linear ? time * _scale : (1 - _progress.x(time)) * _scale;

  @override
  double x(double time) {
    if (time >= cut) return end;
    return parent.x(time) - _miss * _share(time);
  }

  /// At and after the cut, the velocity it ends with, which is what a
  /// following step inherits.
  @override
  double dx(double time) {
    if (cut <= 0) return 0;
    final t = time < cut ? time : cut;
    final share = _linear ? _scale : -_progress.dx(t) * _scale;
    return parent.dx(t) - _miss * share;
  }

  @override
  bool isDone(double time) => time >= cut;
}
