import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/presets/dot_loader.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:merging_dots/src/rendering/render_dots.dart';
import 'package:motor/motor.dart';

/// Gooey loading indicators: small grids of round dots that melt into each
/// other like liquid, and glide off their cells with offsets.
///
/// Show one with `DotLoaderView`. Every style leaves out a color, so the
/// dots follow the ambient `IconTheme` color.
abstract final class GooLoaders {
  /// Every goo loader, endless ones first.
  static List<DotLoader> get all => [
    comet,
    lava,
    ripple,
    jelly,
    heartbeat,
    cradle,
    drip,
    beads,
    pool,
  ];

  /// A glowing blob that glides around the ring of a 3 x 3 grid, handed
  /// from dot to dot so it never pops.
  static DotLoader get comet => GridLoader(
    name: 'Comet',
    description:
        'A blob of goo glides around a ring of dots, dragging a melting '
        'tail behind it.',
    sequence: _cycle(
      steps: 32,
      period: const Duration(milliseconds: 1400),
      pose: _cometPose,
    ),
    style: const DotGridStyle(blend: 0.7),
  );

  /// Blobs in a 3 x 5 grid that rise up and down out of step, like wax in a
  /// lava lamp.
  static DotLoader get lava => GridLoader(
    name: 'Lava',
    description:
        'Blobs drift up and down out of step and melt together like wax in '
        'a lava lamp.',
    sequence: _cycle(
      steps: 40,
      period: const Duration(milliseconds: 3000),
      pose: _lavaPose,
    ),
    style: const DotGridStyle(blend: 0.8),
  );

  /// Rings rolling outward from the center of a 5 x 5 grid.
  static DotLoader get ripple => GridLoader(
    name: 'Ripple',
    description:
        'Rings of goo roll out from the center like ripples on a pond.',
    sequence: _cycle(
      steps: 24,
      period: const Duration(milliseconds: 1500),
      pose: _ripplePose,
    ),
    style: const DotGridStyle(dotSize: 0.9, blend: 0.75, offsetRange: 0.3),
  );

  /// A 3 x 3 block of jelly that squashes, hops and wobbles.
  static DotLoader get jelly => GridLoader(
    name: 'Jelly',
    description:
        'A cube of jelly squashes, hops up tall and lands with a wobble.',
    sequence: DotSequence(
      [
        DotKeyframe(
          _jellyPose(),
          hold: const Duration(milliseconds: 160),
        ),
        DotKeyframe(
          _jellyPose(width: 0.28, height: -0.3),
          motion: const CupertinoMotion(duration: Duration(milliseconds: 260)),
        ),
        DotKeyframe(
          _jellyPose(width: -0.18, height: 0.25, lift: 0.5),
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 280),
            bounce: 0.15,
          ),
        ),
        DotKeyframe(
          _jellyPose(width: 0.3, height: -0.32),
          motion: const CupertinoMotion(duration: Duration(milliseconds: 240)),
        ),
        DotKeyframe(
          _jellyPose(),
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 520),
            bounce: 0.55,
          ),
        ),
      ],
    ),
    style: const DotGridStyle(dotSize: 0.95, blend: 0.8, offsetRange: 1),
  );

  /// A gooey heart beating lub-dub.
  static DotLoader get heartbeat => GridLoader(
    name: 'Heartbeat',
    description: 'A gooey heart beats lub-dub, then rests.',
    sequence: DotSequence(
      [
        DotKeyframe(
          _heartPose(0),
          hold: const Duration(milliseconds: 420),
        ),
        DotKeyframe(
          _heartPose(1),
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 130),
          ),
        ),
        DotKeyframe(
          _heartPose(0.15),
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 150),
          ),
        ),
        DotKeyframe(
          _heartPose(0.7),
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 130),
          ),
        ),
        DotKeyframe(
          _heartPose(0),
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 460),
            bounce: 0.2,
          ),
        ),
      ],
    ),
    style: const DotGridStyle(dotSize: 0.85, blend: 1),
  );

  /// Newton's cradle: the end balls of a gooey row swing out in turn.
  static DotLoader get cradle => GridLoader(
    name: 'Cradle',
    description:
        "A Newton's cradle of goo: the end balls swing out and stretch away "
        'from the row.',
    sequence: _cycle(
      steps: 32,
      period: const Duration(milliseconds: 1500),
      pose: _cradlePose,
    ),
    style: const DotGridStyle(dotSize: 1, blend: 0.55, offsetRange: 1),
  );

  /// A drop that swells under a ceiling, falls and splashes into a puddle.
  static DotLoader get drip => GridLoader(
    name: 'Drip',
    description:
        'A drop swells under the ceiling, lets go and splashes into the '
        'puddle below.',
    sequence: _cycle(
      steps: 36,
      period: const Duration(milliseconds: 1800),
      pose: _dripPose,
    ),
    style: const DotGridStyle(blend: 0.8, offsetRange: 1),
  );

  /// A string of beads that bunch up and spread out as a wave runs along it.
  static DotLoader get beads => GridLoader(
    name: 'Beads',
    description:
        'A row of beads breathes as a squeeze runs along it, bunching them '
        'into one drop.',
    sequence: _cycle(
      steps: 28,
      period: const Duration(milliseconds: 1600),
      pose: _beadsPose,
    ),
    style: const DotGridStyle(dotSize: 0.7, blend: 0.9, offsetRange: 0.4),
  );

  /// A glass of 5 x 5 dots filling up with goo.
  static DotLoader get pool => const GridProgressLoader(
    name: 'Pool',
    description:
        'Goo fills a glass of faint dots from the bottom, the rising row '
        'hanging off the surface.',
    build: _poolPose,
    style: DotGridStyle(dotSize: 0.9),
    motion: CupertinoMotion(
      duration: Duration(milliseconds: 450),
      bounce: 0.2,
    ),
  );

  // ---------------------------------------------------------------------
  // Helpers.

  /// A loop of [steps] evenly spaced samples of [pose], one per phase from
  /// `0` up to (not including) `1`, played back linearly in [period].
  ///
  /// As [pose] is periodic, the last sample flows into the first like any
  /// other.
  static DotSequence<DotGrid> _cycle({
    required int steps,
    required Duration period,
    required DotGrid Function(double phase) pose,
  }) => DotSequence(
    [for (var step = 0; step < steps; step++) DotKeyframe(pose(step / steps))],
    motion: LinearMotion(period ~/ steps),
  );

  /// Builds a grid from a value and an offset, in cells, for every dot.
  ///
  /// Offsets are divided by [offsetRange] to the `-1` to `1` of a grid.
  static DotGrid _build(
    int columns,
    int rows,
    double offsetRange,
    (double, Offset) Function(int column, int row) dot,
  ) {
    final values = <double>[];
    final offsets = <double>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final (value, offset) = dot(column, row);
        values.add(value.clamp(0, kMaxGridValue));
        offsets
          ..add((offset.dx / offsetRange).clamp(-1, 1))
          ..add((offset.dy / offsetRange).clamp(-1, 1));
      }
    }
    return DotGrid(columns, rows, values: values, offsets: offsets);
  }

  static double _smoothstep(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// [x] wrapped into `-half` to `half` of a period of [length].
  static double _wrap(double x, double length) {
    final wrapped = x % length;
    return wrapped >= length / 2 ? wrapped - length : wrapped;
  }

  static const double _tau = 2 * math.pi;

  // ---------------------------------------------------------------------
  // Poses.

  static const List<(int, int)> _ring = [
    (0, 0),
    (1, 0),
    (2, 0),
    (2, 1),
    (2, 2),
    (1, 2),
    (0, 2),
    (0, 1),
  ];

  static DotGrid _cometPose(double phase) {
    final head = phase * _ring.length;
    return _build(3, 3, 0.5, (column, row) {
      final index = _ring.indexOf((column, row));
      if (index < 0) return (0.0, Offset.zero);
      // How far the head has passed this dot, in ring steps.
      final passed = _wrap(head - index, _ring.length.toDouble());
      final (x, y) = _ring[index];
      final (nextX, nextY) = _ring[(index + 1) % _ring.length];
      final (previousX, previousY) =
          _ring[(index - 1 + _ring.length) % _ring.length];
      final toNext = Offset((nextX - x).toDouble(), (nextY - y).toDouble());
      final toPrevious = Offset(
        (previousX - x).toDouble(),
        (previousY - y).toDouble(),
      );
      const base = 0.22;
      if (passed.abs() <= 0.5) {
        // Carrying the head.
        return (1.0, (passed >= 0 ? toNext : toPrevious) * passed.abs());
      }
      if (passed > 0) {
        // The tail: snaps back to its cell as it shrinks.
        final fade = (passed - 0.5) / 2.5;
        final value = base + (1 - base) * (1 - _smoothstep(fade));
        final pull = 0.5 * (1 - _smoothstep((passed - 0.5) / 0.9));
        return (value, toNext * pull);
      }
      // Ahead of the head: reaches back to meet it.
      final reach = 1 - _smoothstep((-passed - 0.5) / 0.6);
      return (base + (1 - base) * reach, toPrevious * 0.5 * reach);
    });
  }

  /// Phase and size of the blob in each column of [_lavaPose].
  static const List<(double, double)> _lavaBlobs = [
    (0, 0.8),
    (0.36, 0.95),
    (0.7, 0.7),
  ];

  static DotGrid _lavaPose(double phase) => _build(3, 5, 0.5, (column, row) {
    final (own, size) = _lavaBlobs[column];
    // Each column's blob rises from the pool at the bottom and sinks back.
    final blobY = 2.2 - 1.8 * math.cos((phase + own) * _tau);
    final distance = blobY - row;
    // The nearest two dots carry the blob between them, so it glides.
    final (carried, offset) = distance.abs() <= 0.5
        ? (size, distance)
        : (
            size * (1 - _smoothstep((distance.abs() - 0.5) / 0.6)),
            0.5 * distance.sign,
          );
    final sway = 0.08 * math.sin((phase * 2 + own) * _tau);
    if (row == 4) {
      // The pool of wax at the bottom.
      return (math.max(0.8, carried), Offset(0, math.min(0, offset)));
    }
    return (carried, Offset(sway, offset));
  });

  static DotGrid _ripplePose(double phase) => _build(5, 5, 0.3, (
    column,
    row,
  ) {
    final dx = column - 2.0;
    final dy = row - 2.0;
    final distance = math.sqrt(dx * dx + dy * dy);
    final wave = math.cos((distance / 2.4 - phase) * _tau);
    final crest = math.pow(math.max(0, wave), 2).toDouble();
    final value = 0.28 + 0.72 * crest;
    // The crest pushes dots outward a little as it passes.
    final push = distance == 0
        ? Offset.zero
        : Offset(dx, dy) /
              distance *
              0.25 *
              math.sin(
                (distance / 2.4 - phase) * _tau,
              );
    return (value, push);
  });

  static DotGrid _jellyPose({
    double width = 0,
    double height = 0,
    double lift = 0,
  }) => _build(5, 4, 1, (column, row) {
    // A 3 x 3 cube in the bottom middle, with room around it to squash
    // and hop.
    if (column == 0 || column == 4 || row < 1) return (0.0, Offset.zero);
    final x = column - 2.0;
    // Anchored at the bottom, so squashing keeps it on the floor.
    final y = row - 3.0;
    return (1.0, Offset(x * width, y * height - lift));
  });

  static final DotGrid _heart = DotGrid.parse('''
    .#.#.
    #####
    #####
    .###.
    ..#..
  ''');

  static DotGrid _heartPose(double beat) => _build(7, 7, 0.5, (column, row) {
    // The heart sits in the middle, with a margin to swell into.
    if (column == 0 || column == 6 || row == 0 || row == 6) {
      return (0.0, Offset.zero);
    }
    final filled = _heart.valueAt(column - 1, row - 1);
    if (filled == 0) return (0.0, Offset.zero);
    // Huddled in at rest, swelling out from the heart's middle on a beat.
    final out = Offset(column - 3.0, row - 2.8) * (0.3 * beat - 0.1);
    return (0.8 + 0.35 * beat, out);
  });

  static DotGrid _cradlePose(double phase) {
    const maxAngle = 0.95;
    const length = 1.25;
    final left = phase < 0.5 ? -maxAngle * math.sin(phase * _tau) : 0.0;
    final right = phase >= 0.5
        ? maxAngle * math.sin((phase - 0.5) * _tau)
        : 0.0;
    // A little shudder runs through the row on every hit.
    final hit = math.cos(phase * 2 * _tau);
    // Five balls hang in the middle of the bottom row, with room to swing.
    return _build(7, 2, 1, (column, row) {
      if (row == 0 || column == 0 || column == 6) return (0.0, Offset.zero);
      final angle = switch (column) {
        1 => left,
        5 => right,
        _ => 0.0,
      };
      final swing = Offset(
        length * math.sin(angle),
        -length * (1 - math.cos(angle)),
      );
      final value = column == 1 || column == 5
          ? 1.0
          : 0.92 + 0.06 * math.pow(math.max(0, hit), 8);
      return (value, swing);
    });
  }

  static DotGrid _dripPose(double phase) {
    // The drop's position in rows, from just under the ceiling to the
    // puddle, and its size.
    double dropY;
    double dropValue;
    if (phase < 0.5) {
      final swell = _smoothstep(phase / 0.5);
      dropY = 0.2 + 0.55 * swell;
      dropValue = 0.85 * math.sqrt(swell);
    } else if (phase < 0.75) {
      final fall = (phase - 0.5) / 0.25;
      dropY = 0.75 + 2.25 * fall * fall;
      dropValue = 0.85;
    } else {
      dropY = 3;
      dropValue = 0;
    }
    // A splash that swells the puddle and rings out.
    final sinceSplash = phase >= 0.75 ? (phase - 0.75) / 0.25 : 1.5;
    final splash = sinceSplash > 1.2
        ? 0.0
        : math.sin(sinceSplash * math.pi * 2.2) * math.exp(-sinceSplash * 3.2);

    // Two dots carry the drop and hand it over between rows 1.6 and 2.
    final handOver = ((dropY - 1.6) / 0.4).clamp(0.0, 1.0);
    final upper = dropValue * math.min(1, 2 * (1 - handOver));
    final lower = dropValue * math.min(1, 2 * handOver);

    return _build(3, 4, 1, (column, row) {
      switch ((column, row)) {
        case (_, 0):
          // The ceiling sags a little where the drop forms.
          final sag = column == 1 ? 0.1 * dropValue : 0.0;
          return (0.9, Offset(0, sag));
        case (1, 1):
          return (upper, Offset(0, math.min(dropY, 2) - 1));
        case (1, 2):
          return (lower, Offset(0, math.max(dropY, 1) - 2));
        case (_, 3):
          final middle = column == 1;
          final value = middle ? 0.95 + 0.3 * splash : 0.85 + 0.1 * splash;
          final spread = (column - 1) * 0.25 * splash.abs();
          return (value, Offset(spread, middle ? -0.25 * splash : 0));
        default:
          return (0.0, Offset.zero);
      }
    });
  }

  static DotGrid _beadsPose(double phase) => _build(5, 1, 0.6, (column, _) {
    final angle = (phase - column / 5) * _tau;
    // Longitudinal wave: beads bunch up where the squeeze passes.
    final wave = 0.35 * math.sin(angle);
    // The end beads only move inward, so the row keeps its length.
    final shift = switch (column) {
      0 => math.max(0, wave),
      4 => math.min(0, wave),
      _ => wave,
    }.toDouble();
    final squeeze = math.max(0, math.cos(angle));
    return (0.75 + 0.35 * squeeze * squeeze, Offset(shift, 0));
  });

  static DotGrid _poolPose(double progress) {
    final level = progress * 5;
    return _build(5, 5, 0.5, (column, row) {
      final fromBottom = 4 - row;
      final fill = (level - fromBottom).clamp(0.0, 1.0);
      if (fill == 0) return (0.2, Offset.zero);
      if (fill == 1) return (1.0, Offset.zero);
      // A filling row hangs low, so it melts into the goo below.
      final sink = 0.45 * math.sin(fill * math.pi);
      return (0.2 + 0.8 * _smoothstep(fill), Offset(0, sink));
    });
  }
}
