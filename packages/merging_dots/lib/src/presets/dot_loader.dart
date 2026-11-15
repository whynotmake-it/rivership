import 'package:flutter/widgets.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:merging_dots/src/widgets/dot_views.dart';
import 'package:motor/motor.dart';

/// A ready-made loading indicator: an endless animation, or a pose for each
/// amount of progress.
///
/// Show any of them with [DotLoaderView]. The catalogs in `DotLoaders` list
/// them all.
@immutable
sealed class DotLoader {
  const DotLoader({required this.name, required this.description});

  /// A short name, like "Orbit".
  final String name;

  /// One sentence on what it looks like.
  final String description;

  /// Whether it shows an amount of progress rather than looping.
  bool get isDeterminate;
}

/// An endless grid animation.
final class GridLoader extends DotLoader {
  /// Creates a looping grid loader.
  const GridLoader({
    required super.name,
    required super.description,
    required this.sequence,
    this.style = const DotGridStyle(),
  });

  /// The animation, usually looping.
  final DotSequence<DotGrid> sequence;

  /// How the dots are drawn.
  final DotGridStyle style;

  @override
  bool get isDeterminate => false;
}

/// An endless freeform animation.
final class CloudLoader extends DotLoader {
  /// Creates a looping cloud loader.
  const CloudLoader({
    required super.name,
    required super.description,
    required this.sequence,
    this.style = const DotCloudStyle(),
  });

  /// The animation, usually looping.
  final DotSequence<DotCloud> sequence;

  /// How the dots are drawn.
  final DotCloudStyle style;

  @override
  bool get isDeterminate => false;
}

/// A grid that shows an amount of progress.
///
/// [build] turns progress, from 0 to 1, into a grid. Whenever the progress
/// changes, the dots animate to the new grid with [motion] and [stagger].
final class GridProgressLoader extends DotLoader {
  /// Creates a determinate grid loader.
  const GridProgressLoader({
    required super.name,
    required super.description,
    required this.build,
    this.style = const DotGridStyle(),
    this.motion = const CupertinoMotion(duration: Duration(milliseconds: 400)),
    this.stagger = const DotStagger.none(),
  });

  /// The grid for a progress from 0 to 1. Every grid has the same size.
  final DotGrid Function(double progress) build;

  /// How the dots are drawn.
  final DotGridStyle style;

  /// How the dots move when the progress changes.
  final Motion motion;

  /// The stagger when the progress changes.
  final DotStagger stagger;

  @override
  bool get isDeterminate => true;
}

/// Freeform dots that show an amount of progress.
///
/// [build] turns progress, from 0 to 1, into a cloud. Every cloud has the
/// same number of dots in the same order, so dots glide between poses.
final class CloudProgressLoader extends DotLoader {
  /// Creates a determinate cloud loader.
  const CloudProgressLoader({
    required super.name,
    required super.description,
    required this.build,
    this.style = const DotCloudStyle(),
    this.motion = const CupertinoMotion(duration: Duration(milliseconds: 400)),
    this.stagger = const DotStagger.none(),
  });

  /// The cloud for a progress from 0 to 1.
  final DotCloud Function(double progress) build;

  /// How the dots are drawn.
  final DotCloudStyle style;

  /// How the dots move when the progress changes.
  final Motion motion;

  /// The stagger when the progress changes.
  final DotStagger stagger;

  @override
  bool get isDeterminate => true;
}

/// Shows any [DotLoader]: plays an endless one, and poses a determinate one
/// at [progress].
///
/// Without a color in the loader's style, dots take the ambient `IconTheme`
/// color.
class DotLoaderView extends StatelessWidget {
  /// Shows [loader].
  const DotLoaderView({
    required this.loader,
    super.key,
    this.progress = 0,
    this.playing = true,
  });

  /// The loader to show.
  final DotLoader loader;

  /// The progress of a determinate loader, from 0 to 1. Ignored otherwise.
  final double progress;

  /// Whether an endless loader plays.
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress.clamp(0.0, 1.0);
    return switch (loader) {
      GridLoader(:final sequence, :final style) => DotGridView.sequence(
        sequence: sequence,
        style: style,
        playing: playing,
      ),
      CloudLoader(:final sequence, :final style) => DotCloudView.sequence(
        sequence: sequence,
        style: style,
        playing: playing,
      ),
      GridProgressLoader(
        :final build,
        :final style,
        :final motion,
        :final stagger,
      ) =>
        DotGridView(
          grid: build(progress),
          style: style,
          motion: motion,
          stagger: stagger,
        ),
      CloudProgressLoader(
        :final build,
        :final style,
        :final motion,
        :final stagger,
      ) =>
        DotCloudView(
          cloud: build(progress),
          style: style,
          motion: motion,
          stagger: stagger,
        ),
    };
  }
}
