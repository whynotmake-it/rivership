import 'package:flutter/physics.dart';
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

  group('motion equality', () {
    test('NoMotion compares by duration', () {
      // ignore: prefer_const_constructors
      expectSame(NoMotion(ms100), NoMotion(ms100));
      expectDifferent(const NoMotion(ms100), const NoMotion(ms200));
    });

    test('FrictionMotion compares drag, deceleration and tolerance', () {
      // ignore: prefer_const_constructors
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
}
