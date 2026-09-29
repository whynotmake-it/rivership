import 'package:flutter/physics.dart';
import 'package:motor/src/simulations/simulation_end.dart';

/// A [Simulation] that knows when it settles.
///
/// A motion's simulation is one move, from a start value to an end value
/// with a start velocity. When the motion has *ended* is its own
/// `duration`, the same for every move. When the move has *settled*, at
/// rest and exactly on its target, depends on the move (a spring takes
/// longer to settle over a longer distance), so the simulation says it,
/// through [settlesAt].
///
/// Awaited futures, `status` and the ticker wait for it, and by default so
/// does the next step of a track. Every simulation motor
/// creates has this mixin. A simulation without it still works: motor
/// samples its [isDone] instead, for up to two minutes; see
/// [SimulationSettling.estimateSettle].
///
/// ```dart
/// class _FallSimulation extends Simulation with SettlingSimulation {
///   // ...
///   @override
///   Duration get settlesAt => _restTime;
/// }
/// ```
mixin SettlingSimulation on Simulation {
  /// When the move is done for good, or null if it never is.
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
  /// When this simulation is done for good, or null if it never is.
  ///
  /// A [SettlingSimulation] answers with its [SettlingSimulation.settlesAt],
  /// checked against [isDone]. Any other simulation, or one that isn't done
  /// by the time it reports, is sampled: [isDone] on a 1/60 s grid, then
  /// bisected, for up to two minutes, after which it counts as never
  /// settling. Playback, motor's wrappers and devtools all read settle times
  /// through this, so that a custom wrapper can pass its parent's on too.
  ///
  /// Sampling costs up to about 3600 [isDone] calls for a minute-long move,
  /// and finds the first time [isDone] is true, which can be early for a
  /// simulation whose [isDone] flickers.
  Duration? estimateSettle() {
    final simulation = this;
    if (simulation is SettlingSimulation) {
      final reported = simulation.settlesAt;
      if (reported == null) return null;
      if (settledAt(simulation, reported.inMicroseconds / 1e6) != null) {
        return reported;
      }
    }
    return settlingDurationOf(searchSettlingSeconds(simulation));
  }
}
