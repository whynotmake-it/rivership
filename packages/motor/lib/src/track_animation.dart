import 'package:equatable/equatable.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/step.dart';
import 'package:motor/src/track.dart';

/// An animation instruction for a single [Track].
class TrackAnimation<T extends Object> with EquatableMixin {
  /// Creates an animation for [track] using [steps].
  TrackAnimation(this.track, this.steps);

  /// Creates a single target animation for [track].
  ///
  /// If [motion] is null, the track's default motion is used at playback time.
  TrackAnimation.single(
    this.track, {
    required T to,
    Motion? motion,
  }) : steps = [Step.to(to, motion: motion)];

  /// The track this animation targets.
  final Track<T> track;

  /// The steps to play for [track].
  final List<Step<T>> steps;

  @override
  List<Object?> get props => [track, ...steps];
}
