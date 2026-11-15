import 'package:merging_dots/src/presets/cloud_loaders.dart';
import 'package:merging_dots/src/presets/cloud_progress_loaders.dart';
import 'package:merging_dots/src/presets/dot_loader.dart';
import 'package:merging_dots/src/presets/dot_presets.dart';
import 'package:merging_dots/src/presets/grid_progress_loaders.dart';
import 'package:merging_dots/src/presets/tiles_loaders.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';

/// Every ready-made loader, by family.
///
/// Each family is also its own class, for picking one by name:
/// [TilesLoaders], [CloudLoaders], [GridProgressLoaders] and
/// [CloudProgressLoaders]. Show any loader with `DotLoaderView`.
abstract final class DotLoaders {
  /// The original [DotPresets], as loaders.
  static List<DotLoader> get classics => [
    CloudLoader(
      name: 'Gooey bounce',
      description:
          'The middle of three dots swings over to melt into each '
          'neighbor in turn.',
      sequence: DotPresets.gooeyBounce(),
      style: const DotCloudStyle(blend: 18),
    ),
    CloudLoader(
      name: 'Orbit',
      description: 'A gooey comet chases around a ring of dots.',
      sequence: DotPresets.orbit(),
      style: const DotCloudStyle(blend: 20),
    ),
    CloudLoader(
      name: 'Binary',
      description: 'Two dots circle each other, merging every half turn.',
      sequence: DotPresets.binary(),
      style: const DotCloudStyle(blend: 22),
    ),
    GridLoader(
      name: 'Wave',
      description: 'A wave rolls back and forth through the columns.',
      sequence: DotPresets.wave(),
      style: const DotGridStyle(blend: 1.1),
    ),
    GridLoader(
      name: 'Pulse',
      description: 'A small grid breathes out from its center and back.',
      sequence: DotPresets.pulse(),
      style: const DotGridStyle(blend: 1.1),
    ),
    GridLoader(
      name: 'Snake',
      description: 'A snake chases its tail around a 3 x 3 grid.',
      sequence: DotPresets.snake(),
      style: const DotGridStyle.tiles(),
    ),
  ];

  /// Every family with its loaders, in a sensible order to browse.
  static List<(String, List<DotLoader>)> get families => [
    ('Tiles', TilesLoaders.all),
    ('Freeform', CloudLoaders.all),
    ('Progress on a grid', GridProgressLoaders.all),
    ('Freeform progress', CloudProgressLoaders.all),
    ('Classics', classics),
  ];

  /// Every loader.
  static List<DotLoader> get all => [
    for (final (_, loaders) in families) ...loaders,
  ];
}
