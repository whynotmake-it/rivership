import 'dart:convert';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

void main() {
  group('DotGrid', () {
    test('parses patterns', () {
      final grid = DotGrid.parse('''
        #.5
        9
      ''');
      expect(grid.columns, 3);
      expect(grid.rows, 2);
      expect(grid.valueAt(0, 0), 1);
      expect(grid.valueAt(1, 0), 0);
      expect(grid.valueAt(2, 0), closeTo(5 / 9, 1e-6));
      expect(grid.valueAt(0, 1), 1);
      expect(grid.valueAt(2, 1), 0);
      expect(grid.toPattern(), '#.5\n#..');
    });

    test('round trips through JSON, with and without offsets', () {
      final grid = DotGrid.parse('#.5\n.#.');
      expect(grid.toJson().containsKey('pattern'), isTrue);
      expect(DotGrid.fromJson(grid.toJson()), grid);

      final moved = grid
          .withValue(1, 1, 0.123)
          .withOffset(0, 0, const Offset(0.5, -1));
      final json =
          jsonDecode(jsonEncode(moved.toJson())) as Map<String, Object?>;
      expect(json.containsKey('values'), isTrue);
      final read = DotGrid.fromJson(json);
      expect(read.valueAt(1, 1), closeTo(0.123, 1e-3));
      expect(read.offsetAt(0, 0), const Offset(0.5, -1));
    });

    test('resizes around its center', () {
      final grid = DotGrid.parse('#');
      final bigger = grid.resized(3, 3);
      expect(bigger.toPattern(), '...\n.#.\n...');
      expect(bigger.resized(1, 1), grid);
    });

    test('compares by value', () {
      expect(DotGrid.parse('#.'), DotGrid.parse('#.'));
      expect(DotGrid.parse('#.'), isNot(DotGrid.parse('.#')));
      expect(
        DotGrid.parse('#.').hashCode,
        DotGrid.parse('#.').hashCode,
      );
    });
  });

  group('DotSequence', () {
    test('grid sequences round trip through JSON', () {
      final sequence = DotSequence(
        [
          DotKeyframe(
            DotGrid.parse('#.'),
            hold: const Duration(milliseconds: 100),
          ),
          DotKeyframe(
            DotGrid.parse('.#'),
            motion: const Motion.curved(
              Duration(milliseconds: 300),
              Curves.easeOutBack,
            ),
            stagger: const DotStagger.radial(
              duration: Duration(milliseconds: 80),
              center: Alignment.topLeft,
              inward: true,
            ),
          ),
        ],
        motion: const Motion.cupertino(bounce: 0.3),
        stagger: const DotStagger.directional(
          duration: Duration(milliseconds: 200),
          angle: 1,
        ),
        loop: LoopMode.pingPong,
      );
      final json =
          jsonDecode(jsonEncode(sequence.toJson())) as Map<String, Object?>;
      expect(json['kind'], 'grid');
      expect(DotSequence.gridFromJson(json), sequence);
    });

    test('cloud sequences round trip through JSON', () {
      final sequence = DotPresets.gooeyBounce();
      final json =
          jsonDecode(jsonEncode(sequence.toJson())) as Map<String, Object?>;
      expect(json['kind'], 'cloud');
      expect(DotSequence.cloudFromJson(json), sequence);
    });
  });

  group('DotStagger', () {
    test('directional delays go from 0 to 1 along the angle', () {
      final delays = List<double>.filled(3, 0);
      const DotStagger.directional(
        duration: Duration(seconds: 1),
      ).computeDelays(delays, 3, (i) => Offset(i / 2, 0));
      expect(delays, [0, 0.5, 1]);
    });

    test('radial delays grow away from the center', () {
      final delays = List<double>.filled(3, 0);
      const DotStagger.radial(
        duration: Duration(seconds: 1),
      ).computeDelays(delays, 3, (i) => Offset(i / 2, 0.5));
      expect(delays, [1, 0, 1]);
    });

    test('round trip through JSON', () {
      for (final stagger in const [
        DotStagger.none(),
        DotStagger.ordered(duration: Duration(milliseconds: 5), reverse: true),
        DotStagger.random(duration: Duration(milliseconds: 5), seed: 3),
      ]) {
        expect(DotStagger.fromJson(stagger.toJson()), stagger);
      }
    });
  });
}
