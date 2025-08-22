import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/phase_sequence.dart';

void main() {
  const motion = CurvedMotion(duration: Duration.zero);
  const motion2 = CurvedMotion(duration: Duration(seconds: 2));

  group('MapPhaseSequence', () {
    final seq1 = MapPhaseSequence(
      const {'a': 1, 'b': 2},
      motion: (_) => motion,
    );
    final seq2 = MapPhaseSequence(
      const {'a': 1, 'b': 2},
      motion: (_) => motion,
    );
    final seq3 = MapPhaseSequence(
      const {'a': 1, 'b': 3},
      motion: (_) => motion2,
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
    test('motionForPhase returns correct motion', () {
      expect(seq1.motionForPhase('a'), motion);
    });
  });

  group('ValuePhaseSequence', () {
    final seq1 = ValuePhaseSequence<int>(
      const [1, 2, 3],
      motion: (_) => motion,
    );
    final seq2 = ValuePhaseSequence<int>(
      const [1, 2, 3],
      motion: (_) => motion,
    );
    final seq3 = ValuePhaseSequence<int>(
      const [1, 2, 4],
      motion: (_) => motion2,
    );

    test('equality: identical', () {
      expect(seq1, equals(seq2));
      expect(seq1.hashCode, equals(seq2.hashCode));
    });
    test('equality: different values', () {
      expect(seq1, isNot(equals(seq3)));
    });
    test('phases and valueForPhase', () {
      expect(seq1.phases, [1, 2, 3]);
      expect(seq1.valueForPhase(2), 2);
    });
    test('motionForPhase returns correct motion', () {
      expect(seq1.motionForPhase(1), motion);
    });
  });

  group('SingleValueSequence', () {
    final seq1 = PhaseSequence.single(
      'hello',
      motion: motion,
    );
    final seq2 = PhaseSequence.single(
      'hello',
      motion: motion,
    );
    final seq3 = PhaseSequence.single(
      'world',
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
      expect(seq1.phases, [0]);
      expect(seq1.valueForPhase(12312312), 'hello');
    });
    test('motionForPhase returns correct motion', () {
      expect(seq1.motionForPhase(0), motion);
    });
    test('loopMode defaults to none', () {
      expect(seq1.loopMode, PhaseLoopMode.none);
    });
    test('has loopMode none', () {
      final customSeq = PhaseSequence.single(
        42,
        motion: motion,
      );
      expect(customSeq.loopMode, PhaseLoopMode.none);
    });
  });

  group('TimelineSequence', () {
    // Test with non-normalized values (10-50 range)
    final timeline1 = TimelineSequence<String>(
      {
        10.0: 'start',
        30.0: 'middle',
        50.0: 'end',
      },
      motion: motion,
    );

    // Test with negative values (-100 to 200 range)
    final timeline2 = TimelineSequence<int>(
      {
        -100.0: 0,
        0.0: 50,
        200.0: 100,
      },
      motion: motion2,
    );

    // Test with single value
    final timeline3 = TimelineSequence<String>(
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

    test('sortedValues accessor returns original sorted map', () {
      final values = timeline1.sortedValues;
      expect(values[10.0], equals('start'));
      expect(values[30.0], equals('middle'));
      expect(values[50.0], equals('end'));
    });

    test('motionForPhase returns trimmed motion based on timeline', () {
      // The timeline automatically trims motions for each phase
      // For the first phase, it should be a trimmed version of the original
      // motion
      final firstPhaseMotion = timeline1.motionForPhase(10);
      expect(firstPhaseMotion, isA<TrimmedMotion>());
      expect((firstPhaseMotion as TrimmedMotion).parent, equals(motion));

      final firstPhaseMotion2 = timeline2.motionForPhase(-100);
      expect(firstPhaseMotion2, isA<TrimmedMotion>());
      expect((firstPhaseMotion2 as TrimmedMotion).parent, equals(motion2));
    });

    test('sorts phases correctly regardless of input order', () {
      final unordered = TimelineSequence<String>(
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

    test('timeline trimming works correctly with normalized values internally',
        () {
      final timeline = TimelineSequence<String>(
        {
          100.0: 'first', // normalized to 0.0 internally
          200.0: 'second', // normalized to 0.25 internally
          300.0: 'third', // normalized to 0.5 internally
          500.0: 'fourth', // normalized to 1.0 internally
        },
        motion: motion2,
      );

      // Test first phase motion (should use subExtent with extent = (0.25-0)/2 = 0.125)
      final firstMotion = timeline.motionForPhase(100) as TrimmedMotion;
      expect(firstMotion.startTrim, equals(0.0));
      expect(firstMotion.endTrim, closeTo(0.875, 1e-10)); // 1 - 0.125

      final middleMotion = timeline.motionForPhase(300) as TrimmedMotion;
      expect(
        middleMotion.startTrim,
        closeTo(0.375, 1e-10),
      ); // 0.25 + (0.5-0.25)/2
      expect(
        middleMotion.endTrim,
        closeTo(0.375, 1e-10),
      ); // 1.0 - (0.375 + 0.25)

      // Test last phase motion (should trim from 0.75 to end)
      final lastMotion = timeline.motionForPhase(500) as TrimmedMotion;
      expect(lastMotion.startTrim, closeTo(0.75, 1e-10)); // 0.5 + (1-0.5)/2
      expect(lastMotion.endTrim, equals(0.0));
    });
  });
}
