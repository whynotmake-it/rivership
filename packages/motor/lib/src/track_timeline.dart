import 'package:equatable/equatable.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_animation.dart';

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

  @override
  List<Object?> get props => [...animations, loop, ...from, ...withVelocity];
}
