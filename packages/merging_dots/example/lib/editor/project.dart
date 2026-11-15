import 'package:flutter/foundation.dart';
import 'package:merging_dots/merging_dots.dart';

/// Whether a project animates a grid or a freeform cloud.
enum DotMode { grid, cloud }

/// Everything the editor saves: both kinds of animation and their styles.
///
/// Only the sequence of the current [mode] is exported, but keeping both
/// means switching modes loses nothing.
@immutable
class Project {
  const Project({
    required this.name,
    required this.mode,
    required this.grid,
    required this.cloud,
    this.gridStyle = const DotGridStyle.tiles(),
    this.cloudStyle = const DotCloudStyle(),
  });

  factory Project.blank({String name = 'Untitled'}) => Project(
    name: name,
    mode: DotMode.grid,
    grid: DotSequence([DotKeyframe(DotGrid(7, 7))]),
    cloud: const DotSequence([
      DotKeyframe(DotCloud([Dot(50, 50, 14)])),
    ]),
  );

  factory Project.fromJson(Map<String, Object?> json) => Project(
    name: json['name'] as String? ?? 'Untitled',
    mode: DotMode.values.asNameMap()[json['mode']] ?? DotMode.grid,
    grid: DotSequence.gridFromJson(json['grid']! as Map<String, Object?>),
    cloud: DotSequence.cloudFromJson(json['cloud']! as Map<String, Object?>),
    gridStyle: DotGridStyle.fromJson(
      json['gridStyle'] as Map<String, Object?>? ?? const {},
    ),
    cloudStyle: DotCloudStyle.fromJson(
      json['cloudStyle'] as Map<String, Object?>? ?? const {},
    ),
  );

  final String name;
  final DotMode mode;
  final DotSequence<DotGrid> grid;
  final DotSequence<DotCloud> cloud;
  final DotGridStyle gridStyle;
  final DotCloudStyle cloudStyle;

  /// The number of frames of the current mode.
  int get frameCount =>
      mode == DotMode.grid ? grid.frames.length : cloud.frames.length;

  /// The motion of the current mode.
  Motion get motion => mode == DotMode.grid ? grid.motion : cloud.motion;

  /// The stagger of the current mode.
  DotStagger get stagger => mode == DotMode.grid ? grid.stagger : cloud.stagger;

  /// The loop mode of the current mode.
  LoopMode get loop => mode == DotMode.grid ? grid.loop : cloud.loop;

  /// The hold of [frame] in the current mode.
  Duration holdOf(int frame) =>
      mode == DotMode.grid ? grid.frames[frame].hold : cloud.frames[frame].hold;

  Project copyWith({
    String? name,
    DotMode? mode,
    DotSequence<DotGrid>? grid,
    DotSequence<DotCloud>? cloud,
    DotGridStyle? gridStyle,
    DotCloudStyle? cloudStyle,
  }) => Project(
    name: name ?? this.name,
    mode: mode ?? this.mode,
    grid: grid ?? this.grid,
    cloud: cloud ?? this.cloud,
    gridStyle: gridStyle ?? this.gridStyle,
    cloudStyle: cloudStyle ?? this.cloudStyle,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'mode': mode.name,
    'grid': grid.toJson(),
    'cloud': cloud.toJson(),
    'gridStyle': gridStyle.toJson(),
    'cloudStyle': cloudStyle.toJson(),
  };
}

/// Replaces the frames of [sequence], keeping its settings.
DotSequence<T> withFrames<T extends DotState>(
  DotSequence<T> sequence,
  List<DotKeyframe<T>> frames,
) => DotSequence(
  frames,
  motion: sequence.motion,
  stagger: sequence.stagger,
  loop: sequence.loop,
);

/// Replaces the settings of [sequence], keeping its frames.
DotSequence<T> withSettings<T extends DotState>(
  DotSequence<T> sequence, {
  Motion? motion,
  DotStagger? stagger,
  LoopMode? loop,
}) => DotSequence(
  sequence.frames,
  motion: motion ?? sequence.motion,
  stagger: stagger ?? sequence.stagger,
  loop: loop ?? sequence.loop,
);
