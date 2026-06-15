import 'package:equatable/equatable.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';

/// A reusable multi-track animation clip.
class TrackTimeline with EquatableMixin {
  /// Creates a timeline from track [animations].
  TrackTimeline(
    this.animations, {
    this.loop = LoopMode.none,
    this.from = const [],
    this.withVelocity = const [],
  });

  /// Track animations in this timeline.
  final List<TrackAnimation> animations;

  /// How this timeline should loop.
  final LoopMode loop;

  /// Optional initial-value overrides.
  final List<TrackValue> from;

  /// Optional per-track initial velocities.
  ///
  /// Each entry's [TrackValue.value] is interpreted as that track's starting
  /// velocity. Unlike [from], this does not move the track's value.
  final List<TrackValue> withVelocity;

  /// The resolved start value for every track in [animations].
  ///
  /// For each track this is its [from] override when present, otherwise the
  /// track's [Track.origin]. This is where the timeline begins playing, and is
  /// what callers jump back to in order to restart from the start.
  List<TrackValue> get startValues => [
        for (final animation in animations) _startValueFor(animation.track),
      ];

  TrackValue _startValueFor(Track track) {
    for (final override in from.reversed) {
      if (identical(override.track, track)) return override;
    }
    return track.value(track.origin);
  }

  @override
  List<Object?> get props => [...animations, loop, ...from, ...withVelocity];
}
