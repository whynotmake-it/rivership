import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/phase_sequence.dart';

void main() {
  const motion = CurvedMotion(duration: Duration.zero);
  const motion2 = CurvedMotion(duration: Duration(seconds: 2));

  group('MapPhaseSequence', () {
    final seq1 = MapPhaseSequence<int, String>(
      phaseMap: const {'a': 1, 'b': 2},
      motion: (_) => motion,
    );
    final seq2 = MapPhaseSequence<int, String>(
      phaseMap: const {'a': 1, 'b': 2},
      motion: (_) => motion,
    );
    final seq3 = MapPhaseSequence<int, String>(
      phaseMap: const {'a': 1, 'b': 3},
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
      values: const [1, 2, 3],
      motion: (_) => motion,
    );
    final seq2 = ValuePhaseSequence<int>(
      values: const [1, 2, 3],
      motion: (_) => motion,
    );
    final seq3 = ValuePhaseSequence<int>(
      values: const [1, 2, 4],
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

  group('MotionMapSequence', () {
    final parent = ValuePhaseSequence<int>(
      values: const [1, 2],
      motion: (_) => const CurvedMotion(duration: Duration.zero),
    );
    const customMotion = CurvedMotion(duration: Duration(seconds: 2));
    final seq = MotionMapSequence<int, int>(
      parent: parent,
      motionByPhase: const {2: customMotion},
    );

    test('delegates phases and valueForPhase', () {
      expect(seq.phases, [1, 2]);
      expect(seq.valueForPhase(1), 1);
    });
    test('motionForPhase uses custom motion if present', () {
      expect(seq.motionForPhase(2), customMotion);
    });
    test('motionForPhase falls back to parent', () {
      expect(seq.motionForPhase(1), isA<CurvedMotion>());
    });
    test('equality: identical', () {
      final seq2 = MotionMapSequence<int, int>(
        parent: parent,
        motionByPhase: const {2: customMotion},
      );
      expect(seq, equals(seq2));
    });
    test('equality: different motionByPhase', () {
      final seq3 = MotionMapSequence<int, int>(
        parent: parent,
        motionByPhase: const {1: customMotion},
      );
      expect(seq, isNot(equals(seq3)));
    });
  });

  group('MotionByPhaseExtension', () {
    final parent = ValuePhaseSequence<int>(
      values: const [1, 2],
      motion: (_) => const CurvedMotion(duration: Duration.zero),
    );
    const customMotion = CurvedMotion(duration: Duration(seconds: 2));
    final wrapped = parent.withMotionPerPhase({2: customMotion});

    test('withMotionPerPhase returns MotionMapSequence', () {
      expect(wrapped, isA<MotionMapSequence<int, int>>());
      expect(wrapped.motionForPhase(2), customMotion);
    });
  });
}
