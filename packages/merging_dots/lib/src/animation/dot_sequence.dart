import 'package:flutter/foundation.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/animation/motion_json.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/model/dot_scene.dart';
import 'package:merging_dots/src/model/dot_state.dart';
import 'package:motor/motor.dart';

/// One pose of a [DotSequence]: the dots move to [state], then stay for
/// [hold].
@immutable
class DotKeyframe<T extends DotState> {
  /// Creates a keyframe that moves to [state].
  ///
  /// [motion] and [stagger] override the sequence's for the move *into*
  /// this keyframe.
  const DotKeyframe(
    this.state, {
    this.hold = Duration.zero,
    this.motion,
    this.stagger,
  });

  /// The pose the dots move to.
  final T state;

  /// How long the dots rest on [state] once they arrived.
  final Duration hold;

  /// The motion into this keyframe, or null for the sequence's.
  final Motion? motion;

  /// The stagger into this keyframe, or null for the sequence's.
  final DotStagger? stagger;

  /// A copy with the given fields replaced.
  DotKeyframe<T> copyWith({
    T? state,
    Duration? hold,
    Motion? motion,
    DotStagger? stagger,
  }) => DotKeyframe(
    state ?? this.state,
    hold: hold ?? this.hold,
    motion: motion ?? this.motion,
    stagger: stagger ?? this.stagger,
  );

  @override
  bool operator ==(Object other) =>
      other is DotKeyframe<T> &&
      other.state == state &&
      other.hold == hold &&
      other.motion == motion &&
      other.stagger == stagger;

  @override
  int get hashCode => Object.hash(state, hold, motion, stagger);
}

/// A dot animation: [frames] played one after the other. It needs at least
/// one frame.
///
/// Every move between two frames runs [motion], delayed per dot by
/// [stagger], unless the target frame overrides them. A sequence with a
/// single frame is a static pose.
///
/// Export one from the merging_dots editor as JSON and load it with
/// [DotSequence.gridFromJson] or [DotSequence.cloudFromJson], or as Dart
/// code that builds it directly.
@immutable
class DotSequence<T extends DotState> {
  /// Creates a sequence of [frames].
  const DotSequence(
    this.frames, {
    this.motion = const CupertinoMotion.smooth(),
    this.stagger = const DotStagger.none(),
    this.loop = LoopMode.loop,
  });

  /// A sequence that only shows [state].
  DotSequence.single(
    T state, {
    this.motion = const CupertinoMotion.smooth(),
    this.stagger = const DotStagger.none(),
  }) : frames = [DotKeyframe(state)],
       loop = LoopMode.none;

  /// Reads a grid sequence written by [toJson].
  static DotSequence<DotGrid> gridFromJson(Map<String, Object?> json) =>
      _fromJson(json, DotGrid.fromJson);

  /// Reads a cloud sequence written by [toJson].
  static DotSequence<DotCloud> cloudFromJson(Map<String, Object?> json) =>
      _fromJson(json, DotCloud.fromJson);

  /// Reads a scene sequence written by [toJson].
  static DotSequence<DotScene> sceneFromJson(Map<String, Object?> json) =>
      _fromJson(json, DotScene.fromJson);

  static DotSequence<S> _fromJson<S extends DotState>(
    Map<String, Object?> json,
    S Function(Map<String, Object?> state) readState,
  ) {
    Motion? motion(Object? json) =>
        json == null ? null : MotionJson.fromJson(json as Map<String, Object?>);
    DotStagger? stagger(Object? json) =>
        json == null ? null : DotStagger.fromJson(json as Map<String, Object?>);
    return DotSequence<S>(
      [
        for (final frame in json['frames']! as List)
          if (frame case final Map<String, Object?> frame)
            DotKeyframe<S>(
              readState(frame['state']! as Map<String, Object?>),
              hold: Duration(
                milliseconds: (frame['hold'] as num? ?? 0).round(),
              ),
              motion: motion(frame['motion']),
              stagger: stagger(frame['stagger']),
            ),
      ],
      motion: motion(json['motion']) ?? const CupertinoMotion.smooth(),
      stagger: stagger(json['stagger']) ?? const DotStagger.none(),
      loop: LoopMode.values.asNameMap()[json['loop']] ?? LoopMode.loop,
    );
  }

  /// The poses, in order.
  final List<DotKeyframe<T>> frames;

  /// The motion between frames, unless a frame overrides it.
  final Motion motion;

  /// The stagger between frames, unless a frame overrides it.
  final DotStagger stagger;

  /// What happens after the last frame.
  ///
  /// [LoopMode.loop] and [LoopMode.seamless] move back to the first frame,
  /// [LoopMode.pingPong] plays the frames backwards, and [LoopMode.none]
  /// stops.
  final LoopMode loop;

  /// The motion into frame [index].
  Motion motionInto(int index) => frames[index].motion ?? motion;

  /// The stagger into frame [index].
  DotStagger staggerInto(int index) => frames[index].stagger ?? stagger;

  /// The frame after [index] when playing in [direction] (`1` or `-1`),
  /// and the direction after it, or null when the sequence ends.
  (int, int)? next(int index, int direction) {
    final count = frames.length;
    if (count == 1) return null;
    final candidate = index + direction;
    if (candidate >= 0 && candidate < count) return (candidate, direction);
    return switch (loop) {
      LoopMode.none => null,
      LoopMode.loop ||
      LoopMode.seamless => (direction > 0 ? 0 : count - 1, direction),
      LoopMode.pingPong => (index - direction, -direction),
    };
  }

  /// A JSON representation.
  ///
  /// Motions that [MotionJson] can't store are left out, so the frame falls
  /// back to the sequence's motion, or the default spring.
  Map<String, Object?> toJson() => {
    'kind': switch (T) {
      const (DotCloud) => 'cloud',
      const (DotScene) => 'scene',
      _ => 'grid',
    },
    'motion': MotionJson.toJson(motion),
    'stagger': stagger.toJson(),
    'loop': loop.name,
    'frames': [
      for (final frame in frames)
        {
          'state': switch (frame.state) {
            final DotGrid grid => grid.toJson(),
            final DotCloud cloud => cloud.toJson(),
            final DotScene scene => scene.toJson(),
            _ => throw UnsupportedError(
              '${frame.state.runtimeType} has no JSON form.',
            ),
          },
          if (frame.hold > Duration.zero) 'hold': frame.hold.inMilliseconds,
          if (frame.motion case final motion?)
            'motion': MotionJson.toJson(motion),
          if (frame.stagger case final stagger?) 'stagger': stagger.toJson(),
        },
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is DotSequence<T> &&
      listEquals(other.frames, frames) &&
      other.motion == motion &&
      other.stagger == stagger &&
      other.loop == loop;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(frames), motion, stagger, loop);
}
