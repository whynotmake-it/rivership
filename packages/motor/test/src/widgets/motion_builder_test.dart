import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('SingleMotionBuilder', () {
    testWidgets('builds with initial value', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SingleMotionBuilder(
          value: 10,
          motion: const CupertinoMotion.smooth(),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );
      expect(capturedValue, equals(10.0));
    });

    testWidgets('animates to new value', (tester) async {
      double? capturedValue;
      final widget = SingleMotionBuilder(
        value: 0,
        motion: const CupertinoMotion.smooth(),
        builder: (context, value, child) {
          capturedValue = value;
          return const SizedBox();
        },
      );

      await tester.pumpWidget(widget);
      expect(capturedValue, equals(0.0));

      await tester.pumpWidget(
        SingleMotionBuilder(
          value: 100,
          motion: const CupertinoMotion.smooth(),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      // Value should start moving towards target
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue, greaterThan(0.0));
      expect(capturedValue, lessThan(100.0));
    });

    testWidgets('starts at from value', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SingleMotionBuilder(
          value: 100,
          from: 0,
          motion: const CupertinoMotion.smooth(),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));

      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(100.0, 0.001));
    });

    testWidgets('stays at from value if active is false', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SingleMotionBuilder(
          value: 100,
          from: 0,
          motion: const CupertinoMotion.smooth(),
          active: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(capturedValue, equals(0.0));
    });

    testWidgets('respects active flag', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SingleMotionBuilder(
          value: 0,
          motion: const CupertinoMotion.smooth(),
          active: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        SingleMotionBuilder(
          value: 100,
          motion: const CupertinoMotion.smooth(),
          active: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      // Value should immediately be at target
      expect(capturedValue, equals(100.0));
    });
  });

  group('MotionBuilder', () {
    testWidgets('builds with initial value', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        MotionBuilder(
          value: (10.0, 20.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );
      expect(capturedValue?.$1, equals(10.0));
      expect(capturedValue?.$2, equals(20.0));
    });

    testWidgets('animates to new value', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        MotionBuilder(
          value: (0.0, 0.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        MotionBuilder(
          value: (100.0, 200.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      // Values should start moving towards target
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue?.$1, greaterThan(0.0));
      expect(capturedValue?.$1, lessThan(100.0));
      expect(capturedValue?.$2, greaterThan(0.0));
      expect(capturedValue?.$2, lessThan(200.0));
    });

    testWidgets('starts at from value', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        MotionBuilder(
          value: (100.0, 200.0),
          from: (0.0, 0.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );
      expect(capturedValue?.$1, closeTo(0.0, 0.001));
      expect(capturedValue?.$2, closeTo(0.0, 0.001));

      await tester.pumpAndSettle();
      expect(capturedValue?.$1, closeTo(100.0, 0.001));
      expect(capturedValue?.$2, closeTo(200.0, 0.001));
    });

    testWidgets('animates 1d from in y direction', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        MotionBuilder(
          value: (0.0, 0.0),
          from: (0.0, 100.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue?.$1, equals(0.0));
      expect(capturedValue?.$2, equals(100.0));

      await tester.pumpAndSettle();
      expect(capturedValue?.$1, equals(0.0));
      expect(capturedValue?.$2, closeTo(0.0, 0.001));
    });

    testWidgets('stays at from value if active is false', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        MotionBuilder(
          value: (100.0, 200.0),
          from: (0.0, 0.0),
          motion: const CupertinoMotion.smooth(),
          active: false,
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(capturedValue?.$1, equals(0.0));
      expect(capturedValue?.$2, equals(0.0));
    });

    testWidgets('respects active flag', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        MotionBuilder(
          value: (0.0, 0.0),
          motion: const CupertinoMotion.smooth(),
          active: false,
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        MotionBuilder(
          value: (100.0, 200.0),
          motion: const CupertinoMotion.smooth(),
          active: false,
          converter: MotionConverter<(double, double)>.custom(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      // Values should immediately be at target
      expect(capturedValue?.$1, equals(100.0));
      expect(capturedValue?.$2, equals(200.0));
    });
  });
}
