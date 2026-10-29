import 'package:flutter/foundation.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';

/// A reusable multi-track animation clip.
///
/// A timeline bundles a set of [TrackAnimation]s with a [loop] mode. Per-track
/// start values and velocities live on the individual [TrackAnimation]s
/// (`from:` / `withVelocity:`), not on the timeline.
///
/// Timelines compare by value: building an equal timeline on rebuild will not
/// restart playback in `TrackBuilder`. Reuse instances or hoist them to fields
/// for clarity; equality makes both safe.
@immutable
class TrackTimeline {
  /// Creates a timeline from track [animations].
  TrackTimeline(
    List<TrackAnimation> animations, {
    this.loop = LoopMode.none,
  }) : animations = List.unmodifiable(animations);

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackTimeline &&
          other.runtimeType == runtimeType &&
          other.loop == loop &&
          listEquals(other.animations, animations);

  @override
  int get hashCode =>
      Object.hash(runtimeType, loop, Object.hashAll(animations));

  @override
  String toString() => 'TrackTimeline($animations, loop: $loop)';
}
