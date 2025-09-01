import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_sequence.dart';

import 'src/util.dart';

void main() {
  const motion = CurvedMotion(Duration.zero);
  const motion2 = CurvedMotion(Duration(seconds: 2));

  group('StateSequence', () {
    const seq1 = StateSequence(
      {'a': 1, 'b': 2},
      motion: motion,
    );
    const seq2 = StateSequence(
      {'a': 1, 'b': 2},
      motion: motion,
    );
    const seq3 = StateSequence(
      {'a': 1, 'b': 3},
      motion: motion2,
    );

    test('equality: identical', () {
      expect(seq1, equals(seq2));
      expect(seq1.hashCode, equals(seq2.hashCode));
    });
    test('equality: different values', () {
      expect(seq1, isNot(equals(seq3)));
    });
    test('phases and valueForPhase', () {
      expect(seq1.phases, ['a', 'b']);
      expect(seq1.valueForPhase('a'), 1);
      expect(seq1.valueForPhase('b'), 2);
    });
  });

  group('StepSequence', () {
    const seq1 = StepSequence<int>(
      [1, 2, 3],
      motion: motion,
    );
    const seq2 = StepSequence<int>(
      [1, 2, 3],
      motion: motion,
    );
    const seq3 = StepSequence<int>(
      [1, 2, 4],
      motion: motion2,
    );

    test('equality: identical', () {
      expect(seq1, equals(seq2));
      expect(seq1.hashCode, equals(seq2.hashCode));
    });
    test('equality: different values', () {
      expect(seq1, isNot(equals(seq3)));
    });
    test('phases and valueForPhase', () {
      expect(seq1.phases, [0, 1, 2]);
      expect(seq1.valueForPhase(2), 3);
    });
  });

  group('SpanningSequence', () {
    // Test with non-normalized values (10-50 range)
    final timeline1 = SpanningSequence<String>(
      {
        10.0: 'start',
        30.0: 'middle',
        50.0: 'end',
      },
      motion: motion,
    );

    // Test with negative values (-100 to 200 range)
    final timeline2 = SpanningSequence<int>(
      {
        -100.0: 0,
        0.0: 50,
        200.0: 100,
      },
      motion: motion2,
    );

    // Test with single value
    final timeline3 = SpanningSequence<String>(
      {
        42.0: 'single',
      },
      motion: motion,
    );

    test('returns original sorted values for 10-50 range', () {
      final phases = timeline1.phases;
      expect(phases.length, equals(3));
      expect(phases[0], equals(10.0)); // Original value
      expect(phases[1], equals(30.0)); // Original value
      expect(phases[2], equals(50.0)); // Original value

      expect(timeline1.valueForPhase(10), equals('start'));
      expect(timeline1.valueForPhase(30), equals('middle'));
      expect(timeline1.valueForPhase(50), equals('end'));
    });

    test('returns original sorted values for -100 to 200 range', () {
      final phases = timeline2.phases;
      expect(phases.length, equals(3));
      expect(phases[0], equals(-100.0)); // Original value
      expect(phases[1], equals(0.0)); // Original value
      expect(phases[2], equals(200.0)); // Original value

      expect(timeline2.valueForPhase(-100), equals(0));
      expect(timeline2.valueForPhase(0), equals(50));
      expect(timeline2.valueForPhase(200), equals(100));
    });

    test('handles single value correctly', () {
      final phases = timeline3.phases;
      expect(phases.length, equals(1));
      expect(phases[0], equals(42.0)); // Original value

      expect(timeline3.valueForPhase(42), equals('single'));
    });

    test('sorts phases correctly regardless of input order', () {
      final unordered = SpanningSequence<String>(
        {
          50.0: 'end',
          10.0: 'start',
          30.0: 'middle',
        },
        motion: motion,
      );

      final phases = unordered.phases;
      expect(phases[0], equals(10.0)); // start (original value)
      expect(phases[1], equals(30.0)); // middle (original value)
      expect(phases[2], equals(50.0)); // end (original value)
    });

    test('linear trimmed timeline stays linear', () {
      final timeline = SpanningSequence<double>(
        const {
          1: 0.0,
          2: 0.25,
          3: 0.5,
          4: 0.75,
          5: 1.0,
        },
        motion: const CurvedMotion(Duration(seconds: 1)),
      );

      final curvedSimulation = timeline.motion.createSimulation();
      for (var t = 0.0; t <= 1; t += .01) {
        expect(curvedSimulation.x(t), equals(t));
      }

      void verifySim(Simulation sim, double from, double to) {
        for (var t = from; t <= to; t += .01) {
          expect(sim.x(t), closeTo(t, error));
        }
      }

      final sim = timeline
          .motionForPhase(toPhase: 2, fromPhase: 1)
          .createSimulation(end: 0.25);

      verifySim(sim, 0, 0.25);
    });
  });
}
