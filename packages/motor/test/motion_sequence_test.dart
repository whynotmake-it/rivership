// ignore_for_file: prefer_const_constructors,
// ignore_for_file: prefer_const_literals_to_create_immutables
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/util.dart';

void main() {
  const motion = CurvedMotion(Duration.zero);
  const motion2 = CurvedMotion(Duration(seconds: 2));

  test('sequences are equal when their values and motions are', () {
    final cases = <(String, Object, Object, bool)>[
      (
        'identical states',
        StateSequence({'a': 1, 'b': 2}, motion: motion),
        StateSequence({'a': 1, 'b': 2}, motion: motion),
        true,
      ),
      (
        'different states',
        StateSequence({'a': 1, 'b': 2}, motion: motion),
        StateSequence({'a': 1, 'b': 3}, motion: motion2),
        false,
      ),
      (
        'identical steps',
        StepSequence<int>([1, 2, 3], motion: motion),
        StepSequence<int>([1, 2, 3], motion: motion),
        true,
      ),
      (
        'different steps',
        StepSequence<int>([1, 2, 3], motion: motion),
        StepSequence<int>([1, 2, 4], motion: motion2),
        false,
      ),
      (
        'different trimmed motions',
        StepSequence<int>([1, 2, 4], motion: motion2.trimmed(fromStart: .1)),
        StepSequence<int>([1, 2, 4], motion: motion2.trimmed(fromStart: .2)),
        false,
      ),
    ];
    for (final (name, a, b, equal) in cases) {
      expect(a == b, equal, reason: name);
      if (equal) expect(a.hashCode, b.hashCode, reason: name);
    }
  });

  test('phases are ordered and map to their values', () {
    final cases =
        <(String, MotionSequence<Object, Object>, List<Object>, List<Object>)>[
      (
        'states',
        StateSequence({'a': 1, 'b': 2}, motion: motion),
        ['a', 'b'],
        [1, 2],
      ),
      (
        'steps',
        StepSequence<int>([1, 2, 3], motion: motion),
        [0, 1, 2],
        [1, 2, 3],
      ),
      (
        'spanning 10-50',
        SpanningSequence<String>(
          {10.0: 'start', 30.0: 'middle', 50.0: 'end'},
          motion: motion,
        ),
        [10.0, 30.0, 50.0],
        ['start', 'middle', 'end'],
      ),
      (
        'spanning -100 to 200',
        SpanningSequence<int>(
          {-100.0: 0, 0.0: 50, 200.0: 100},
          motion: motion2,
        ),
        [-100.0, 0.0, 200.0],
        [0, 50, 100],
      ),
      (
        'spanning single value',
        SpanningSequence<String>({42.0: 'single'}, motion: motion),
        [42.0],
        ['single'],
      ),
      (
        'spanning unordered input',
        SpanningSequence<String>(
          {50.0: 'end', 10.0: 'start', 30.0: 'middle'},
          motion: motion,
        ),
        [10.0, 30.0, 50.0],
        ['start', 'middle', 'end'],
      ),
    ];
    for (final (name, sequence, phases, values) in cases) {
      expect(sequence.phases, phases, reason: name);
      for (final (i, phase) in phases.indexed) {
        expect(sequence.valueForPhase(phase), values[i], reason: name);
      }
    }
  });

  group('SpanningSequence', () {
    const linear1s = Motion.linear(Duration(seconds: 1));

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

    test('two-keyframe seamless sequence uses a non-zero motion slice', () {
      final sequence = MotionSequence.spanning(
        {0.0: 'a', 1.0: 'b'},
        motion: linear1s,
        loop: LoopMode.seamless,
      );

      final motion = sequence.motionForPhase(toPhase: 0);

      expect(motion, isA<TrimmedMotion>());
      final trimmed = motion as TrimmedMotion;
      expect(trimmed.fromStart + trimmed.fromEnd, lessThan(1));
    });

    test('three-keyframe seamless sequence uses the penultimate slice', () {
      final sequence = MotionSequence.spanning(
        {0.0: 'a', 0.5: 'b', 1.0: 'c'},
        motion: linear1s,
        loop: LoopMode.seamless,
      );

      final motion = sequence.motionForPhase(toPhase: 0);

      expect(motion, isA<TrimmedMotion>());
      final trimmed = motion as TrimmedMotion;
      expect(trimmed.fromStart, 0);
      expect(trimmed.fromEnd, 0.5);
    });
  });
}
