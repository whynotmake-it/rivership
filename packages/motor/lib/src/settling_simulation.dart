import 'package:flutter/physics.dart';
import 'package:motor/src/simulations/simulation_end.dart';

/// A [Simulation] that knows when it settles.
///
/// Motor waits for [settlesAt] before it completes futures and starts the
/// next track step. A simulation without this mixin still works: motor
/// samples its [isDone] for up to two minutes.
///
/// ```dart
/// class _FallSimulation extends Simulation with SettlingSimulation {
///   // ...
///   @override
///   Duration get settlesAt => _restTime;
/// }
/// ```
mixin SettlingSimulation on Simulation {
  /// When the move settles, or null if it never does.
  ///
  /// From this time on [isDone] stays true: the value is at rest, and with
  /// a spring's `snapToEnd` exactly on the target. A [Duration] has
  /// microsecond resolution, so motor accepts a time up to a microsecond
  /// before [isDone] turns true, and samples [isDone] instead if the
  /// simulation isn't done by then.
  Duration? get settlesAt;
}

/// When a [Simulation] settles, whether or not it knows.
extension SimulationSettling on Simulation {
  /// When this simulation settles, or null if it never does.
  ///
  /// A [SettlingSimulation] answers with its [SettlingSimulation.settlesAt],
  /// checked against [isDone]. Any other simulation, or one that isn't done
  /// by the time it reports, is sampled: [isDone] on a 1/60 s grid, then
  /// bisected, for up to two minutes, after which it counts as never
  /// settling. Playback, motor's wrappers and devtools all read settle times
  /// through this, so that a custom wrapper can pass its parent's on too.
  ///
  /// It steps the simulation to find when it settles, unless it reports
  /// [SettlingSimulation.settlesAt], so it can be expensive: up to about 3600
  /// [isDone] calls for a minute-long move. Cache the result instead of
  /// calling it every frame. Sampling finds the first time [isDone] is true,
  /// which can be early for a simulation whose [isDone] flickers.
  Duration? simulateSettleTime() {
    final seconds = settleSecondsOf(this);
    if (seconds == null) return null;
    // A reported time that checks out is returned as it is, not rounded.
    final simulation = this;
    if (simulation is SettlingSimulation) {
      final reported = simulation.settlesAt;
      if (reported != null) {
        final reportedSeconds = reported.inMicroseconds / 1e6;
        if (seconds >= reportedSeconds && seconds <= reportedSeconds + 1e-6) {
          return reported;
        }
      }
    }
    return settlingDurationOf(seconds);
  }
}
