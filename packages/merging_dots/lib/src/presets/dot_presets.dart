import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/animation/dot_stagger.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:motor/motor.dart';

/// Ready-made dot animations, mostly loading indicators.
///
/// Play one with `DotGridView.sequence` or `DotCloudView.sequence`.
abstract final class DotPresets {
  /// Three dots in a row, the middle one swinging over to melt into each
  /// neighbor in turn.
  static DotSequence<DotCloud> gooeyBounce() {
    const size = Size(100, 40);
    DotCloud pose(double middle) => DotCloud(
      [const Dot(20, 20, 9), Dot(middle, 20, 9), const Dot(80, 20, 9)],
      size: size,
    );
    return DotSequence(
      [
        DotKeyframe(pose(34), hold: const Duration(milliseconds: 80)),
        DotKeyframe(pose(66), hold: const Duration(milliseconds: 80)),
      ],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 650),
        bounce: 0.2,
      ),
    );
  }

  /// A ring of dots with a gooey comet chasing around it.
  static DotSequence<DotCloud> orbit({int dots = 8}) {
    DotCloud pose(int head) => DotCloud(
      [
        for (var i = 0; i < dots; i++)
          () {
            final angle = i / dots * 2 * math.pi - math.pi / 2;
            final behind = (head - i) % dots;
            final radius = switch (behind) {
              0 => 12.0,
              1 => 9.0,
              2 => 6.5,
              _ => 4.0,
            };
            return Dot(
              50 + math.cos(angle) * 34,
              50 + math.sin(angle) * 34,
              radius,
            );
          }(),
      ],
    );
    return DotSequence(
      [for (var head = 0; head < dots; head++) DotKeyframe(pose(head))],
      motion: const CupertinoMotion(duration: Duration(milliseconds: 420)),
    );
  }

  /// Two dots circling each other, merging every half turn.
  static DotSequence<DotCloud> binary({int steps = 12}) {
    DotCloud pose(int step) {
      final angle = step / steps * 2 * math.pi;
      final distance = 22 + 12 * math.cos(angle * 2);
      final offset = Offset(math.cos(angle), math.sin(angle)) * distance;
      return DotCloud(
        [
          Dot(50 + offset.dx, 50 + offset.dy, 13),
          Dot(50 - offset.dx, 50 - offset.dy, 13),
        ],
      );
    }

    return DotSequence(
      [for (var step = 0; step < steps; step++) DotKeyframe(pose(step))],
      motion: const Motion.linear(Duration(milliseconds: 110)),
    );
  }

  /// A wave rolling through the columns of a small grid.
  static DotSequence<DotGrid> wave({int columns = 5, int rows = 3}) {
    DotGrid pose(int crest) => DotGrid.generate(columns, rows, (column, row) {
      final distance = (column - crest).abs();
      return switch (distance) {
        0 => 1.0,
        1 => 0.6,
        _ => 0.3,
      };
    });
    return DotSequence(
      [for (var crest = 0; crest < columns; crest++) DotKeyframe(pose(crest))],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 380),
        bounce: 0.25,
      ),
      loop: LoopMode.pingPong,
    );
  }

  /// A 3 x 3 grid breathing out from its center and back.
  static DotSequence<DotGrid> pulse() {
    return DotSequence(
      [
        DotKeyframe(
          DotGrid.parse('''
            ...
            .#.
            ...
          '''),
          hold: const Duration(milliseconds: 120),
        ),
        DotKeyframe(
          DotGrid.parse('''
            555
            5#5
            555
          '''),
          hold: const Duration(milliseconds: 60),
        ),
      ],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 520),
        bounce: 0.3,
      ),
      stagger: const DotStagger.radial(duration: Duration(milliseconds: 120)),
    );
  }

  /// A 3 x 3 snake chasing its tail around the edge of the grid.
  static DotSequence<DotGrid> snake() {
    const ring = [
      (0, 0),
      (1, 0),
      (2, 0),
      (2, 1),
      (2, 2),
      (1, 2),
      (0, 2),
      (0, 1),
    ];
    DotGrid pose(int head) => DotGrid.generate(3, 3, (column, row) {
      final index = ring.indexOf((column, row));
      if (index < 0) return 0;
      final behind = (head - index) % ring.length;
      return switch (behind) {
        0 => 1.0,
        1 => 0.8,
        2 => 0.55,
        _ => 0.0,
      };
    });
    return DotSequence(
      [for (var head = 0; head < ring.length; head++) DotKeyframe(pose(head))],
      motion: const CupertinoMotion(duration: Duration(milliseconds: 300)),
    );
  }
}
