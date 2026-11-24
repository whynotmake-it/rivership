/// @docImport 'package:motor/src/track_phase_timeline.dart';
/// @docImport 'package:motor/src/track_step.dart';
library;

/// How a [TrackStep.loop] or [TrackPhaseTimeline] repeats.
enum LoopMode {
  /// Play once without repeating.
  none,

  /// Repeat from the first step (or phase) in order, animating smoothly from
  /// the end back to the start of the loop.
  loop,

  /// Play forward and then reverse back to the first target (or play phases in
  /// reverse order), then repeat.
  pingPong,

  /// Jump back to the first target (or first phase) without animating and play
  /// again.
  ///
  /// Author the final step to match the first so the jump is invisible, which
  /// makes circular motion (e.g. rotations) seamless.
  seamless;

  /// Whether this mode repeats.
  bool get isLooping => this != none;
}
