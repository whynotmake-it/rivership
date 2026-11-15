import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/presets/dot_loader.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:motor/motor.dart';

/// Determinate loaders on a grid: each one shows an amount of progress from
/// `0` to `1`.
///
/// Progress maps to fractional fills, so the cell at the leading edge gets
/// the remainder and small changes move smoothly instead of stepping a
/// whole cell at a time.
///
/// Show one with `DotLoaderView` and its `progress`.
abstract final class GridProgressLoaders {
  /// Every loader in this catalog.
  static List<DotLoader> get all => [
    liquidBar,
    pill,
    ring,
    pie,
    battery,
    signal,
    spiral,
    tank,
    heart,
    waffle,
    hourglass,
  ];

  /// A single row of gooey dots that fills from left to right, its leading
  /// edge swelling like a drop about to fall.
  static DotLoader get liquidBar => GridProgressLoader(
    name: 'Liquid bar',
    description:
        'A row of gooey dots that fills from left to right with a '
        'swelling, liquid leading edge.',
    build: (progress) {
      const length = 7;
      return _fillAlong(
        columns: length,
        rows: 1,
        path: [for (var column = 0; column < length; column++) (column, 0)],
        progress: progress,
        softness: 1.6,
        track: _track,
      );
    },
    style: const DotGridStyle(blend: 1.1, dotSize: 0.85),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 520),
      bounce: 0.3,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 160),
    ),
  );

  /// A pill-shaped track of small dots that a solid bar grows along.
  static DotLoader get pill => GridProgressLoader(
    name: 'Pill',
    description:
        'A track of small dots that a solid, rounded bar grows along from '
        'left to right.',
    build: (progress) {
      const length = 8;
      return _fillAlong(
        columns: length,
        rows: 1,
        path: [for (var column = 0; column < length; column++) (column, 0)],
        progress: progress,
        track: _track,
      );
    },
    style: const DotGridStyle.tiles(),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 420),
      bounce: 0.15,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 120),
    ),
  );

  /// The border of a square fills clockwise from the top, like a progress
  /// ring.
  static DotLoader get ring => GridProgressLoader(
    name: 'Ring',
    description:
        'The border of a square fuses into a ring, clockwise from the top '
        'center.',
    build: (progress) => _fillAlong(
      columns: 5,
      rows: 5,
      path: _ringPath,
      progress: progress,
      track: _track,
    ),
    style: const DotGridStyle.tiles(),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 420),
      bounce: 0.15,
    ),
  );

  /// A disc of small dots that fuses into a pie chart, sweeping clockwise
  /// from twelve o'clock.
  static DotLoader get pie => GridProgressLoader(
    name: 'Pie',
    description:
        'A disc of small dots that fuses into a pie chart, sweeping '
        "clockwise from twelve o'clock.",
    build: (progress) {
      const size = 7;
      const center = (size - 1) / 2;
      const radius = 3.3;
      // How many radians of sweep it takes to fill one cell, so the edge of
      // the slice is soft and moves smoothly.
      const ramp = math.pi / 3;
      final sweep = progress * (2 * math.pi + ramp);
      return DotGrid.generate(size, size, (column, row) {
        final dx = column - center;
        final dy = row - center;
        if (math.sqrt(dx * dx + dy * dy) > radius) return 0;
        // Clockwise from the top. The center joins first.
        final angle = dx == 0 && dy == 0
            ? 0.0
            : (math.atan2(dx, -dy) + 2 * math.pi) % (2 * math.pi);
        final fill = ((sweep - angle) / ramp).clamp(0.0, 1.0);
        return _track + (1 - _track) * fill;
      });
    },
    style: const DotGridStyle.tiles(),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 480),
      bounce: 0.2,
    ),
    stagger: const DotStagger.radial(duration: Duration(milliseconds: 100)),
  );

  /// A battery whose charge rises in fused columns.
  static DotLoader get battery => GridProgressLoader(
    name: 'Battery',
    description:
        'A battery outline whose charge grows in columns from left to '
        'right.',
    build: (progress) {
      const columns = 11;
      const rows = 7;
      const cellColumns = 6;
      final level = progress * cellColumns;
      return DotGrid.generate(columns, rows, (column, row) {
        final frame =
            (column <= 9 && (row == 0 || row == rows - 1)) ||
            ((column == 0 || column == 9) && row < rows) ||
            (column == 10 && row >= 2 && row <= 4);
        if (frame) return 1;
        final inside = column >= 2 && column <= 7 && row >= 2 && row <= 4;
        if (!inside) return 0;
        return (level - (column - 2)).clamp(0, 1);
      });
    },
    style: const DotGridStyle.tiles(dotSize: 0.9),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 420),
      bounce: 0.2,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 120),
    ),
  );

  /// Signal-strength bars that rise one after another.
  static DotLoader get signal => GridProgressLoader(
    name: 'Signal',
    description:
        'Four signal bars of rising height, each growing up from the '
        'bottom after the one before.',
    build: (progress) => _fillAlong(
      columns: 7,
      rows: 5,
      path: _signalPath,
      progress: progress,
      softness: 1.5,
      track: _track,
    ),
    style: const DotGridStyle.tiles(),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 440),
      bounce: 0.2,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 120),
      angle: -math.pi / 2,
    ),
  );

  /// A square spiral that winds in from the outside.
  static DotLoader get spiral => GridProgressLoader(
    name: 'Spiral',
    description:
        'A square spiral of dots that fuses into a solid line as it winds '
        'in from the outside.',
    build: (progress) => _fillAlong(
      columns: 7,
      rows: 7,
      path: _spiralPath,
      progress: progress,
      track: _track,
    ),
    style: const DotGridStyle.tiles(),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 420),
      bounce: 0.15,
    ),
  );

  /// A square tank of liquid whose sloshing surface rises.
  static DotLoader get tank => GridProgressLoader(
    name: 'Tank',
    description:
        'A tank of gooey liquid that rises from the bottom with a gently '
        'tilted, sloshing surface.',
    build: (progress) {
      const size = 5;
      // The surface tilts by up to this many cells, so the level has to
      // overshoot by as much to fill the tank.
      const tilt = 0.6;
      final level = progress * (size + tilt);
      return DotGrid.generate(size, size, (column, row) {
        final height = size - row - 1;
        final slope = tilt * (1 - column / (size - 1));
        return (level - height - slope).clamp(0, 1);
      });
    },
    style: const DotGridStyle(blend: 0.8),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 560),
      bounce: 0.3,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 140),
      angle: -math.pi / 2,
    ),
  );

  /// A heart of small dots that fills solid from the bottom up.
  static DotLoader get heart => GridProgressLoader(
    name: 'Heart',
    description:
        'A heart outlined by small dots that fills solid from the bottom '
        'up.',
    build: (progress) => _fillLevels(_heart, progress: progress, track: _track),
    style: const DotGridStyle.tiles(),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 480),
      bounce: 0.2,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 160),
      angle: -math.pi / 2,
    ),
  );

  /// A ten by ten matrix where every dot is one percent.
  static DotLoader get waffle => GridProgressLoader(
    name: 'Waffle',
    description:
        'A ten by ten matrix of faint dots where each one that lights up '
        'is one percent.',
    build: (progress) {
      const size = 10;
      return _fillAlong(
        columns: size,
        rows: size,
        path: [
          for (var row = size - 1; row >= 0; row--)
            for (var column = 0; column < size; column++) (column, row),
        ],
        progress: progress,
        track: 0.3,
      );
    },
    style: const DotGridStyle(blend: 0, dotSize: 0.7),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 360),
      bounce: 0.25,
    ),
    stagger: const DotStagger.directional(
      duration: Duration(milliseconds: 200),
      angle: -math.pi / 2,
    ),
  );

  /// An hourglass whose sand runs from the top chamber into the bottom.
  ///
  /// Unlike the others, its ink doesn't grow: sand only moves from one
  /// chamber to the other, so the total stays the same, apart from the
  /// thin stream through the neck while it runs.
  static DotLoader get hourglass => GridProgressLoader(
    name: 'Hourglass',
    description:
        'An hourglass whose gooey sand drains from the top chamber and '
        'piles up in the bottom one.',
    build: (progress) {
      // Both chambers hold the same amount of sand, so what drains from
      // the top piles up in the bottom.
      final top = _fillLevels(
        _hourglassTop,
        progress: 1 - progress,
        track: _track,
      );
      final bottom = _fillLevels(
        _hourglassBottom,
        progress: progress,
        track: _track,
      );
      final stream = (math.min(progress, 1 - progress) * 12).clamp(0.0, 0.7);
      return DotGrid.generate(
        top.columns,
        top.rows,
        (column, row) => column == 3 && row == 4
            ? stream
            : top.valueAt(column, row) + bottom.valueAt(column, row),
      );
    },
    style: const DotGridStyle(dotSize: 0.85),
    motion: const CurvedMotion(
      Duration(milliseconds: 500),
      Curves.easeInOutCubic,
    ),
  );
}

/// The value of a dot on a path that progress hasn't reached yet, so the
/// path shows as a faint track.
const _track = 0.2;

/// A grid where the cells of [path] fill one after another as [progress]
/// grows from `0` to `1`.
///
/// The cell at the leading edge gets the remainder. With a [softness]
/// above `1`, the leading edge ramps over that many cells, so neighbors
/// overlap and the fill flows. Cells not reached yet show at [track].
DotGrid _fillAlong({
  required int columns,
  required int rows,
  required List<(int, int)> path,
  required double progress,
  double softness = 1,
  double track = 0,
}) {
  final values = List<double>.filled(columns * rows, 0);
  final reach = progress * (path.length - 1 + softness);
  for (var i = 0; i < path.length; i++) {
    final (column, row) = path[i];
    final fill = ((reach - i) / softness).clamp(0.0, 1.0);
    values[row * columns + column] = track + (1 - track) * fill;
  }
  return DotGrid(columns, rows, values: values);
}

/// The filled cells of [shape], filled from the bottom up like a liquid
/// as [progress] grows from `0` to `1`.
///
/// Every row fills evenly, so the surface stays level, and the level
/// rises by area: a narrow row fills faster than a wide one. Cells the
/// liquid hasn't reached show at [track].
DotGrid _fillLevels(
  DotGrid shape, {
  required double progress,
  double track = 0,
}) {
  final cellsPerRow = [
    for (var row = 0; row < shape.rows; row++)
      [
        for (var column = 0; column < shape.columns; column++)
          if (shape.valueAt(column, row) > 0) column,
      ].length,
  ];
  final total = cellsPerRow.fold(0, (sum, count) => sum + count);
  var remaining = progress.clamp(0.0, 1.0) * total;
  final rowFill = List<double>.filled(shape.rows, 0);
  for (var row = shape.rows - 1; row >= 0; row--) {
    final count = cellsPerRow[row];
    if (count == 0) continue;
    final filled = math.min(remaining, count.toDouble());
    rowFill[row] = filled / count;
    remaining -= filled;
  }
  return shape.map(
    (column, row, value) => value > 0 ? track + (1 - track) * rowFill[row] : 0,
  );
}

/// The border of a 5 x 5 grid, clockwise from the top center.
const _ringPath = [
  (2, 0), (3, 0), (4, 0), //
  (4, 1), (4, 2), (4, 3), (4, 4),
  (3, 4), (2, 4), (1, 4), (0, 4),
  (0, 3), (0, 2), (0, 1), (0, 0),
  (1, 0),
];

/// Four bars of rising height on a 7 x 5 grid, each bottom to top.
const _signalPath = [
  (0, 4), (0, 3), //
  (2, 4), (2, 3), (2, 2),
  (4, 4), (4, 3), (4, 2), (4, 1),
  (6, 4), (6, 3), (6, 2), (6, 1), (6, 0),
];

/// A square spiral on a 7 x 7 grid, winding in from the top left.
const _spiralPath = [
  (0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), //
  (6, 1), (6, 2), (6, 3), (6, 4), (6, 5), (6, 6),
  (5, 6), (4, 6), (3, 6), (2, 6), (1, 6),
  (1, 5), (1, 4), (1, 3), (1, 2),
  (2, 2), (3, 2), (4, 2),
  (4, 3), (4, 4),
  (3, 4),
];

/// A heart on a 7 x 6 grid.
final _heart = DotGrid.parse('''
  .##.##.
  #######
  #######
  .#####.
  ..###..
  ...#...
''');

/// The top chamber of a 7 x 9 hourglass.
final _hourglassTop = DotGrid.parse('''
  #######
  .#####.
  ..###..
  ...#...
  .......
  .......
  .......
  .......
  .......
''');

/// The bottom chamber of a 7 x 9 hourglass.
final _hourglassBottom = DotGrid.parse('''
  .......
  .......
  .......
  .......
  .......
  ...#...
  ..###..
  .#####.
  #######
''');
