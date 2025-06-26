import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('SingleVelocityMotionBuilder', () {
    testWidgets('builds with initial value', (tester) async {
      double? capturedValue;
      double? capturedVelocity;
      await tester.pumpWidget(
        SingleVelocityMotionBuilder(
          value: 10,
          motion: const CupertinoMotion.smooth(),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            capturedVelocity = velocity;
            return const SizedBox();
          },
        ),
      );
      expect(capturedValue, equals(10.0));
      expect(capturedVelocity, equals(0.0));
    });

    testWidgets('animates to new value', (tester) async {
      double? capturedValue;
      double? capturedVelocity;

      final widget = SingleVelocityMotionBuilder(
        value: 0,
        motion: const CupertinoMotion.smooth(),
        builder: (context, value, velocity, child) {
          capturedValue = value;
          capturedVelocity = velocity;
          return const SizedBox();
        },
      );

      await tester.pumpWidget(widget);
      expect(capturedValue, equals(0.0));

      await tester.pumpWidget(
        SingleVelocityMotionBuilder(
          value: 100,
          motion: const CupertinoMotion.smooth(),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            capturedVelocity = velocity;
            return const SizedBox();
          },
        ),
      );

      // Value should start moving towards target
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue, greaterThan(0.0));
      expect(capturedValue, lessThan(100.0));
      expect(capturedVelocity, greaterThan(0.0));
    });
  });

  group('VelocityMotionBuilder', () {
    testWidgets('builds with initial value', (tester) async {
      (double x, double y)? capturedValue;
      (double x, double y)? capturedVelocity;
      await tester.pumpWidget(
        VelocityMotionBuilder(
          value: (10.0, 20.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            capturedVelocity = velocity;
            return const SizedBox();
          },
        ),
      );
      expect(capturedValue?.$1, equals(10.0));
      expect(capturedValue?.$2, equals(20.0));
      expect(capturedVelocity?.$1, equals(0.0));
      expect(capturedVelocity?.$2, equals(0.0));
    });

    testWidgets('animates to new value', (tester) async {
      (double x, double y)? capturedValue;
      (double x, double y)? capturedVelocity;
      await tester.pumpWidget(
        VelocityMotionBuilder(
          value: (0.0, 0.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            capturedVelocity = velocity;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        VelocityMotionBuilder(
          value: (100.0, -200.0),
          motion: const CupertinoMotion.smooth(),
          converter: MotionConverter<(double, double)>(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            capturedVelocity = velocity;
            return const SizedBox();
          },
        ),
      );

      // Values should start moving towards target
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue?.$1, greaterThan(0.0));
      expect(capturedValue?.$1, lessThan(100.0));
      expect(capturedValue?.$2, lessThan(0.0));
      expect(capturedValue?.$2, greaterThan(-200.0));

      expect(capturedVelocity?.$1, greaterThan(0.0));
      expect(capturedVelocity?.$2, lessThan(0.0));
    });

    testWidgets('respects active flag', (tester) async {
      (double x, double y)? capturedValue;
      (double x, double y)? capturedVelocity;
      await tester.pumpWidget(
        VelocityMotionBuilder(
          value: (0.0, 0.0),
          motion: const CupertinoMotion.smooth(),
          active: false,
          converter: MotionConverter<(double, double)>(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            capturedVelocity = velocity;
            return const SizedBox();
          },
        ),
      );

      expect(capturedVelocity?.$1, equals(0.0));
      expect(capturedVelocity?.$2, equals(0.0));

      await tester.pumpWidget(
        VelocityMotionBuilder(
          value: (100.0, 200.0),
          motion: const CupertinoMotion.smooth(),
          active: false,
          converter: MotionConverter<(double, double)>(
            normalize: (value) => [value.$1, value.$2],
            denormalize: (values) => (values[0], values[1]),
          ),
          builder: (context, value, velocity, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      // Values should immediately be at target
      expect(capturedValue?.$1, equals(100.0));
      expect(capturedValue?.$2, equals(200.0));
      expect(capturedVelocity?.$1, equals(0.0));
      expect(capturedVelocity?.$2, equals(0.0));
    });
  });
}
