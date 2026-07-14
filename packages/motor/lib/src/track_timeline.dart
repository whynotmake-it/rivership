import 'package:equatable/equatable.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';

/// A reusable multi-track animation clip.
///
/// A timeline bundles a set of [TrackAnimation]s with a [loop] mode. Per-track
/// start values and velocities live on the individual [TrackAnimation]s
/// (`from:` / `withVelocity:`), not on the timeline.
// ignore: deprecated_member_use
class TrackTimeline with EquatableMixin {
  /// Creates a timeline from track [animations].
  TrackTimeline(
    this.animations, {
    this.loop = LoopMode.none,
  });

  /// Track animations in this timeline.
  final List<TrackAnimation> animations;

  /// How this timeline should loop.
  final LoopMode loop;

  /// The resolved start value for every track in [animations].
  ///
  /// For each track this is its animation's `from` override when present,
  /// otherwise the track's [Track.initial] (or a zero-filled fallback). This is
  /// where the timeline begins playing, and is what callers jump back to in
  /// order to restart from the start.
  List<TrackValue> get startValues => [
        for (final animation in animations)
          animation.track.value(animation.resolveStartValue()),
      ];

  @override
  List<Object?> get props => [...animations, loop];
}
