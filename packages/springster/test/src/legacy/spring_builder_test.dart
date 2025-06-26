// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

void main() {
  group('SpringBuilder', () {
    testWidgets('builds with initial value', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SpringBuilder(
          value: 10,
          spring: const Spring(),
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
      final widget = SpringBuilder(
        value: 0,
        spring: const Spring(),
        builder: (context, value, child) {
          capturedValue = value;
          return const SizedBox();
        },
      );

      await tester.pumpWidget(widget);
      expect(capturedValue, equals(0.0));

      await tester.pumpWidget(
        SpringBuilder(
          value: 100,
          spring: const Spring(),
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
        SpringBuilder(
          value: 100,
          from: 0,
          spring: const Spring(),
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

    testWidgets('stays at from value if simulate is false', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SpringBuilder(
          value: 100,
          from: 0,
          spring: const Spring(),
          simulate: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(capturedValue, equals(0.0));
    });

    testWidgets('respects simulate flag', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        SpringBuilder(
          value: 0,
          spring: const Spring(),
          simulate: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        SpringBuilder(
          value: 100,
          spring: const Spring(),
          simulate: false,
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

  group('SpringBuilder2D', () {
    testWidgets('builds with initial value', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        SpringBuilder2D(
          value: (10.0, 20.0),
          spring: const Spring(),
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
        SpringBuilder2D(
          value: (0.0, 0.0),
          spring: const Spring(),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        SpringBuilder2D(
          value: (100.0, 200.0),
          spring: const Spring(),
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
        SpringBuilder2D(
          value: (100.0, 200.0),
          from: (0.0, 0.0),
          spring: const Spring(),
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
        SpringBuilder2D(
          value: (0.0, 0.0),
          from: (0.0, 100.0),
          spring: const Spring(),
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

    testWidgets('stays at from value if simulate is false', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        SpringBuilder2D(
          value: (100.0, 200.0),
          from: (0.0, 0.0),
          spring: const Spring(),
          simulate: false,
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

    testWidgets('respects simulate flag', (tester) async {
      (double x, double y)? capturedValue;
      await tester.pumpWidget(
        SpringBuilder2D(
          value: (0.0, 0.0),
          spring: const Spring(),
          simulate: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        SpringBuilder2D(
          value: (100.0, 200.0),
          spring: const Spring(),
          simulate: false,
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
