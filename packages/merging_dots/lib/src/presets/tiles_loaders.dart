import 'dart:math' as math;

import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/presets/dot_loader.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:motor/motor.dart';

/// Loading indicators drawn with [DotGridStyle.tiles]: full cells fuse into
/// rounded glyphs, like pixels melting into each other.
///
/// Every loader leaves the color unset, so it follows the ambient
/// `IconTheme` color.
abstract final class TilesLoaders {
  /// The style every loader shares.
  static const _style = DotGridStyle.tiles();

  /// A snake gliding around the rim of a 4 x 4 grid, its tail tapering off
  /// into dots.
  static DotLoader get ouroboros {
    const ring = [
      (0, 0), (1, 0), (2, 0), (3, 0), //
      (3, 1), (3, 2), (3, 3), (2, 3), //
      (1, 3), (0, 3), (0, 2), (0, 1), //
    ];
    const body = [1.0, 1.0, 1.0, 0.9, 0.6];
    DotGrid pose(int head) => DotGrid.generate(4, 4, (column, row) {
      final index = ring.indexOf((column, row));
      if (index < 0) return 0;
      final behind = (head - index) % ring.length;
      return behind < body.length ? body[behind] : 0;
    });
    return GridLoader(
      name: 'Ouroboros',
      description: 'A tapering snake glides around the rim of the grid.',
      style: _style,
      sequence: DotSequence(
        [
          for (var head = 0; head < ring.length; head++)
            DotKeyframe(pose(head)),
        ],
        motion: const CupertinoMotion(duration: Duration(milliseconds: 110)),
      ),
    );
  }

  /// A bar sweeping down a 5 x 5 grid and back up.
  static DotLoader get scanner {
    DotGrid pose(int line) => DotGrid.generate(5, 5, (column, row) {
      return row == line ? 1 : 0;
    });
    return GridLoader(
      name: 'Scanner',
      description: 'A solid bar sweeps down the grid and back up.',
      style: _style,
      sequence: DotSequence(
        [
          for (var line = 0; line < 5; line++)
            DotKeyframe(
              pose(line),
              hold: line == 0 || line == 4
                  ? const Duration(milliseconds: 80)
                  : Duration.zero,
            ),
        ],
        motion: const CupertinoMotion(
          duration: Duration(milliseconds: 190),
          bounce: 0.15,
        ),
        loop: LoopMode.pingPong,
      ),
    );
  }

  /// The cells of a 4 x 4 grid filling in a clockwise spiral, then emptying
  /// along the same path.
  static DotLoader get spiral {
    final order = _spiralOrder(4);
    DotGrid pose(int start, int end) {
      return DotGrid.generate(4, 4, (column, row) {
        final index = order.indexOf((column, row));
        return index >= start && index < end ? 1 : 0;
      });
    }

    const hold = Duration(milliseconds: 160);
    return GridLoader(
      name: 'Spiral',
      description:
          'Cells coil inward into a solid square, then unwind '
          'along the same path.',
      style: _style,
      sequence: DotSequence(
        [
          for (var end = 1; end <= order.length; end++)
            DotKeyframe(
              pose(0, end),
              hold: end == order.length ? hold : Duration.zero,
            ),
          for (var start = 1; start <= order.length; start++)
            DotKeyframe(
              pose(start, order.length),
              hold: start == order.length ? hold : Duration.zero,
            ),
        ],
        motion: const CupertinoMotion(duration: Duration(milliseconds: 70)),
      ),
    );
  }

  /// A dot blooming into a plus, a diamond and a rounded square, and back.
  static DotLoader get bloom {
    DotGrid pose(int reach) => DotGrid.generate(5, 5, (column, row) {
      final distance = (column - 2).abs() + (row - 2).abs();
      final chebyshev = math.max((column - 2).abs(), (row - 2).abs());
      final inside = reach < 3 ? distance <= reach : chebyshev <= 2;
      return inside ? 1 : 0;
    });
    return GridLoader(
      name: 'Bloom',
      description:
          'A dot blooms into a plus, a diamond and a square, '
          'then folds back.',
      style: _style,
      sequence: DotSequence(
        [
          DotKeyframe(pose(0), hold: const Duration(milliseconds: 120)),
          DotKeyframe(pose(1)),
          DotKeyframe(pose(2)),
          DotKeyframe(pose(3), hold: const Duration(milliseconds: 120)),
        ],
        motion: const CupertinoMotion(
          duration: Duration(milliseconds: 260),
          bounce: 0.2,
        ),
        stagger: const DotStagger.radial(duration: Duration(milliseconds: 80)),
        loop: LoopMode.pingPong,
      ),
    );
  }

  /// Two square blocks dropping into a well, the full rows clearing away.
  static DotLoader get stack {
    const columns = 4;
    const rows = 5;
    // A 2 x 2 block at [left], its top row at [top]. Settled blocks sit in
    // the bottom two rows.
    DotGrid pose({required List<int> settled, int? left, int top = 0}) {
      return DotGrid.generate(columns, rows, (column, row) {
        for (final block in settled) {
          if (column >= block && column < block + 2 && row >= rows - 2) {
            return 1;
          }
        }
        if (left != null &&
            column >= left &&
            column < left + 2 &&
            row >= top &&
            row < top + 2) {
          return 1;
        }
        return 0;
      });
    }

    const fall = CupertinoMotion(duration: Duration(milliseconds: 90));
    const land = CupertinoMotion(
      duration: Duration(milliseconds: 220),
      bounce: 0.35,
    );
    List<DotKeyframe<DotGrid>> drop(int left, List<int> settled) => [
      for (var top = -1; top < rows - 2; top++)
        DotKeyframe(
          pose(settled: settled, left: left, top: top),
          motion: top == rows - 3 ? land : fall,
          stagger: const DotStagger.directional(
            duration: Duration(milliseconds: 40),
            angle: -math.pi / 2,
          ),
        ),
    ];
    return GridLoader(
      name: 'Stack',
      description:
          'Two blocks drop into a well, fill the bottom rows '
          'and clear away.',
      style: _style,
      sequence: DotSequence(
        [
          ...drop(0, const []),
          ...drop(2, const [0]),
          DotKeyframe(
            pose(settled: const [0, 2]),
            hold: const Duration(milliseconds: 160),
          ),
          DotKeyframe(
            pose(settled: const []),
            hold: const Duration(milliseconds: 200),
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 260),
            ),
            stagger: const DotStagger.directional(
              duration: Duration(milliseconds: 160),
            ),
          ),
        ],
        motion: fall,
      ),
    );
  }

  /// A rounded 3 x 3 block with a notch running around its rim.
  static DotLoader get notch {
    const ring = [
      (0, 0), (1, 0), (2, 0), (2, 1), //
      (2, 2), (1, 2), (0, 2), (0, 1), //
    ];
    DotGrid pose(int hole) => DotGrid.generate(
      3,
      3,
      (column, row) => (column, row) == ring[hole] ? 0 : 1,
    );
    return GridLoader(
      name: 'Notch',
      description: 'A notch runs around the rim of a solid rounded block.',
      style: _style,
      sequence: DotSequence(
        [
          for (var hole = 0; hole < ring.length; hole++)
            DotKeyframe(pose(hole)),
        ],
        motion: const CupertinoMotion(duration: Duration(milliseconds: 150)),
      ),
    );
  }

  /// A baton of five cells turning around the center of a 5 x 5 grid, like
  /// the classic `| / - \` text spinner.
  static DotLoader get propeller {
    // One end of the baton walks along the rim, half a turn in eight steps;
    // the other end mirrors it through the center.
    const ends = [
      (2, 0), (3, 0), (4, 0), (4, 1), //
      (4, 2), (4, 3), (4, 4), (3, 4), //
    ];
    DotGrid pose(int step) {
      final (endColumn, endRow) = ends[step];
      return DotGrid.generate(5, 5, (column, row) {
        // Cells on the line from the center to the end, both ways.
        for (final sign in const [1, -1]) {
          for (var t = 1; t <= 2; t++) {
            final x = 2 + sign * ((endColumn - 2) * t / 2);
            final y = 2 + sign * ((endRow - 2) * t / 2);
            final cellX = sign > 0 ? x.ceil() : x.floor();
            final cellY = sign > 0 ? y.floor() : y.ceil();
            if (column == cellX && row == cellY) return 1;
          }
        }
        return column == 2 && row == 2 ? 1 : 0;
      });
    }

    return GridLoader(
      name: 'Propeller',
      description: 'A baton turns around the center like a text spinner.',
      style: _style,
      sequence: DotSequence(
        [
          for (var step = 0; step < ends.length; step++)
            DotKeyframe(pose(step)),
        ],
        motion: const CupertinoMotion(duration: Duration(milliseconds: 120)),
      ),
    );
  }

  /// A block bouncing off the walls, stretching as it moves.
  static DotLoader get bounce {
    const columns = 5;
    const rows = 4;
    const xs = [0, 1, 2, 3, 2, 1];
    const ys = [0, 1, 2, 1];
    final steps = xs.length * ys.length ~/ 2;
    DotGrid pose(int step) {
      final left = xs[step % xs.length];
      final top = ys[step % ys.length];
      return DotGrid.generate(columns, rows, (column, row) {
        final inside =
            column >= left && column < left + 2 && row >= top && row < top + 2;
        return inside ? 1 : 0;
      });
    }

    return GridLoader(
      name: 'Bounce',
      description: 'A square block bounces off the walls like a screensaver.',
      style: _style,
      sequence: DotSequence(
        [for (var step = 0; step < steps; step++) DotKeyframe(pose(step))],
        motion: const CupertinoMotion(
          duration: Duration(milliseconds: 150),
          bounce: 0.15,
        ),
      ),
    );
  }

  /// Four bars of an audio meter rising and falling out of step.
  static DotLoader get equalizer {
    const columns = 7;
    const rows = 5;
    const levels = [1, 2, 3, 4, 5, 4, 3, 2];
    const phases = [0, 3, 6, 1];
    DotGrid pose(int step) => DotGrid.generate(columns, rows, (column, row) {
      if (column.isOdd) return 0;
      final phase = phases[column ~/ 2];
      final height = levels[(step + phase) % levels.length];
      return rows - row <= height ? 1 : 0;
    });
    return GridLoader(
      name: 'Equalizer',
      description: 'Four bars of an audio meter rise and fall out of step.',
      style: _style,
      sequence: DotSequence(
        [
          for (var step = 0; step < levels.length; step++)
            DotKeyframe(pose(step)),
        ],
        motion: const CupertinoMotion(
          duration: Duration(milliseconds: 140),
          bounce: 0.2,
        ),
        stagger: const DotStagger.directional(
          duration: Duration(milliseconds: 50),
          angle: -math.pi / 2,
        ),
      ),
    );
  }

  /// A 5 x 5 grid filling in a clockwise spiral as progress grows, the
  /// newest cell swelling from a dot.
  static DotLoader get coil {
    final order = _spiralOrder(5);
    return GridProgressLoader(
      name: 'Coil',
      description:
          'Cells coil inward from the corner as progress grows, '
          'ending in a solid square.',
      style: _style,
      build: (progress) => DotGrid.generate(5, 5, (column, row) {
        final index = order.indexOf((column, row));
        return (progress * order.length - index).clamp(0.0, 1.0);
      }),
      motion: const CupertinoMotion(duration: Duration(milliseconds: 360)),
      stagger: const DotStagger.ordered(duration: Duration(milliseconds: 120)),
    );
  }

  /// Every tiles loader.
  static List<DotLoader> get all => [
    ouroboros,
    scanner,
    spiral,
    bloom,
    stack,
    notch,
    propeller,
    bounce,
    equalizer,
    coil,
  ];

  /// The cells of a [size] x [size] grid in a clockwise spiral, from the
  /// top left corner inward.
  static List<(int, int)> _spiralOrder(int size) {
    final order = <(int, int)>[];
    var left = 0;
    var top = 0;
    var right = size - 1;
    var bottom = size - 1;
    while (left <= right && top <= bottom) {
      for (var column = left; column <= right; column++) {
        order.add((column, top));
      }
      for (var row = top + 1; row <= bottom; row++) {
        order.add((right, row));
      }
      if (top < bottom) {
        for (var column = right - 1; column >= left; column--) {
          order.add((column, bottom));
        }
      }
      if (left < right) {
        for (var row = bottom - 1; row > top; row--) {
          order.add((left, row));
        }
      }
      left++;
      top++;
      right--;
      bottom--;
    }
    return order;
  }
}
