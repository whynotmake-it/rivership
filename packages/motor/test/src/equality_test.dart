// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// Expects [a] and [b] to be equal, with equal hash codes.
void expectSame(Object a, Object b) {
  expect(a, equals(b));
  expect(b, equals(a));
  expect(a.hashCode, b.hashCode);
}

/// Expects [a] and [b] to differ in both directions.
void expectDifferent(Object a, Object b) {
  expect(a, isNot(equals(b)));
  expect(b, isNot(equals(a)));
}

void main() {
  const ms100 = Duration(milliseconds: 100);
  const ms200 = Duration(milliseconds: 200);

  group('movement-based equality', () {
    const linear = Motion.linear(ms100);
    const curved = Motion.curved(ms100);
    const cupertino = CupertinoMotion();
    final spring = SpringMotion(cupertino.description);
    final track = Track<double>(MotionConverter.single, initial: 0);

    test('motions that move the same are equal whatever their class', () {
      expectSame(linear, curved);
      expectSame(cupertino, spring);
      expectSame(cupertino.scaleTo(ms100), spring.scaleTo(ms100));
      expectSame(cupertino.trimmed(fromEnd: .5), spring.trimmed(fromEnd: .5));
    });

    test('motions that move differently are unequal', () {
      expectDifferent(linear, const Motion.curved(ms100, Curves.easeIn));
      expectDifferent(linear, const Motion.linear(ms200));
      expectDifferent(linear, const NoMotion(ms100));
      expectDifferent(cupertino, const CupertinoMotion(snapToEnd: false));
      expectDifferent(cupertino, const CupertinoMotion.bouncy());
      expectDifferent(cupertino.scaleTo(ms100), cupertino.scaleTo(ms200));
      expectDifferent(cupertino.scaleTo(ms100), cupertino);
      expectDifferent(
        const FrictionMotion().scaleTo(ms100),
        const FrictionMotion(drag: .2).scaleTo(ms100),
      );
    });

    test('steps, animations and timelines compare motions the same way', () {
      expectSame(
        TrackStep<double>.to(1, motion: linear),
        TrackStep<double>.to(1, motion: curved),
      );
      expectSame(
        TrackStep<double>.at(ms100, 1, motionPerDimension: [linear]),
        TrackStep<double>.at(ms100, 1, motionPerDimension: [curved]),
      );
      expectSame(
        track.to(1, motion: cupertino),
        track.to(1, motion: spring),
      );
      expectSame(
        TrackTimeline([track.to(1, motion: linear)]),
        TrackTimeline([track.to(1, motion: curved)]),
      );
      expectSame(
        TrackPhaseTimeline({
          #only: [track.to(1, motion: linear)],
        }),
        TrackPhaseTimeline({
          #only: [track.to(1, motion: curved)],
        }),
      );
      expectDifferent(
        TrackStep<double>.to(1, motion: linear),
        const TrackStep<double>.to(1, motion: NoMotion(ms100)),
      );
    });

    test('sequences compare motions the same way', () {
      // ignore: deprecated_member_use_from_same_package
      MotionSequence<int, double> steps(Motion motion) =>
          // ignore: deprecated_member_use_from_same_package
          MotionSequence.steps([0.0, 1.0], motion: motion);
      expectSame(steps(linear), steps(curved));
      expectDifferent(steps(linear), steps(const NoMotion(ms100)));
      // ignore: deprecated_member_use_from_same_package
      MotionSequence<String, double> states(Motion motion) =>
          // ignore: deprecated_member_use_from_same_package
          MotionSequence.statesWithMotions({'a': (1.0, motion)});
      expectSame(states(cupertino), states(spring));
    });
  });

  group('motion equality', () {
    test('NoMotion compares by duration', () {
      expectSame(NoMotion(ms100), NoMotion(ms100));
      expectDifferent(const NoMotion(ms100), const NoMotion(ms200));
    });

    test('FrictionMotion compares drag, deceleration and tolerance', () {
      expectSame(FrictionMotion(drag: 0.2), FrictionMotion(drag: 0.2));
      expectDifferent(
        const FrictionMotion(),
        const FrictionMotion(tolerance: Tolerance(distance: 0.1)),
      );
      expectDifferent(
        const FrictionMotion(),
        const FrictionMotion(constantDeceleration: 1),
      );
    });
  });

  group('converter equality', () {
    test('built-in converters compare by type', () {
      expectSame(SingleMotionConverter(), MotionConverter.single);
      expectSame(OffsetMotionConverter(), MotionConverter.offset);
      expectDifferent(MotionConverter.size, MotionConverter.offset);
      expectDifferent(const _AreaSizeConverter(), MotionConverter.size);
    });

    test('custom converters compare by their functions', () {
      MotionConverter<double> custom() => MotionConverter<double>.custom(
            normalize: _normalize,
            denormalize: _denormalize,
          );
      expectSame(custom(), custom());
      expectDifferent(
        custom(),
        MotionConverter<double>.custom(
          normalize: _normalize,
          denormalize: (values) => values.first,
        ),
      );
      expectDifferent(
        custom(),
        MotionConverter<double>.customDirectional(
          normalize: _normalize,
          denormalize: _denormalize,
          compare: _compare,
        ),
      );
      MotionConverter<double> directional() =>
          MotionConverter<double>.customDirectional(
            normalize: _normalize,
            denormalize: _denormalize,
            compare: _compare,
          );
      expectSame(directional(), directional());
    });
  });
}

List<double> _normalize(double value) => [value];

double _denormalize(List<double> values) => values[0];

int _compare(double a, double b) => a.compareTo(b);

class _AreaSizeConverter extends SizeMotionConverter
    with DirectionalMotionConverter<Size> {
  const _AreaSizeConverter();

  @override
  int compare(Size a, Size b) =>
      (a.width * a.height).compareTo(b.width * b.height);
}
