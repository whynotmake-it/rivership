// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';
import 'package:springster/springster.dart';

void main() {
  group('useSingleMotion', () {
    testWidgets('builds with initial value', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useSingleMotion(
              value: 10,
              motion: const SpringMotion(Spring()),
            );

            return SizedBox(
              width: capturedValue,
              child: const FlutterLogo(),
            );
          },
        ),
      );
      expect(capturedValue, equals(10.0));
    });

    testWidgets('animates to new value', (tester) async {
      double? capturedValue;
      final widget = HookBuilder(
        builder: (context) {
          capturedValue = useSingleMotion(
            value: 0,
            motion: const SpringMotion(Spring()),
          );
          return const SizedBox();
        },
      );

      await tester.pumpWidget(widget);
      expect(capturedValue, equals(0.0));

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useSingleMotion(
              value: 100,
              motion: const SpringMotion(Spring()),
            );
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
        HookBuilder(
          builder: (context) {
            capturedValue = useSingleMotion(
              value: 100,
              from: 0,
              motion: const SpringMotion(Spring()),
            );
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
        HookBuilder(
          builder: (context) {
            capturedValue = useSingleMotion(
              value: 100,
              from: 0,
              motion: const SpringMotion(Spring()),
              active: false,
            );
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
        HookBuilder(
          builder: (context) {
            capturedValue = useSingleMotion(
              value: 0,
              motion: const SpringMotion(Spring()),
              active: false,
            );
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useSingleMotion(
              value: 100,
              motion: const SpringMotion(Spring()),
              active: false,
            );
            return const SizedBox();
          },
        ),
      );

      // Value should immediately be at target
      expect(capturedValue, equals(100.0));
    });
  });

  group('useMotion', () {
    testWidgets('builds with initial value', (tester) async {
      Offset? capturedValue;
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: const Offset(10, 20),
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
            );
            return const SizedBox();
          },
        ),
      );
      expect(capturedValue, equals(const Offset(10, 20)));
    });

    testWidgets('animates to new value', (tester) async {
      Offset? capturedValue;
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: Offset.zero,
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
            );
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: const Offset(100, 200),
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
            );
            return const SizedBox();
          },
        ),
      );

      // Values should start moving towards target
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue?.dx, greaterThan(0.0));
      expect(capturedValue?.dx, lessThan(100.0));
      expect(capturedValue?.dy, greaterThan(0.0));
      expect(capturedValue?.dy, lessThan(200.0));
    });

    testWidgets('starts at from value', (tester) async {
      Offset? capturedValue;
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: const Offset(100, 200),
              from: Offset.zero,
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
            );
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue?.dx, closeTo(0.0, 0.001));
      expect(capturedValue?.dy, closeTo(0.0, 0.001));

      await tester.pumpAndSettle();
      expect(capturedValue?.dx, closeTo(100.0, 0.001));
      expect(capturedValue?.dy, closeTo(200.0, 0.001));
    });

    testWidgets('animates 1d from in y direction', (tester) async {
      Offset? capturedValue;
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: Offset.zero,
              from: const Offset(0, 100),
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
            );
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue?.dx, equals(0.0));
      expect(capturedValue?.dy, equals(100.0));

      await tester.pumpAndSettle();
      expect(capturedValue?.dx, closeTo(0.0, 0.001));
      expect(capturedValue?.dy, closeTo(0.0, 0.001));
    });

    testWidgets('stays at from value if simulate is false', (tester) async {
      Offset? capturedValue;
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: const Offset(100, 200),
              from: Offset.zero,
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
              active: false,
            );
            return const SizedBox();
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(capturedValue?.dx, equals(0.0));
      expect(capturedValue?.dy, equals(0.0));
    });

    testWidgets('respects simulate flag', (tester) async {
      Offset? capturedValue;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: Offset.zero,
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
              active: false,
            );
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            capturedValue = useMotion(
              value: const Offset(100, 200),
              motion: const SpringMotion(Spring()),
              converter: const OffsetMotionConverter(),
              active: false,
            );
            return const SizedBox();
          },
        ),
      );

      // Values should immediately be at target
      expect(capturedValue?.dx, equals(100.0));
      expect(capturedValue?.dy, equals(200.0));
    });
  });
}
