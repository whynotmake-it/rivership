import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

import 'util.dart';

void main() {
  group('SpringSimulationController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late SpringSimulationController controller;

    const spring = SimpleSpring();

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with default bounds', (tester) async {
      controller = SpringSimulationController(
        spring: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(0.0));
      expect(controller.upperBound, equals(1.0));
      expect(controller.value, equals(0.0));
      expect(controller.velocity, equals(0.0));
    });

    testWidgets('creates unbounded', (tester) async {
      controller = SpringSimulationController.unbounded(
        spring: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(double.negativeInfinity));
      expect(controller.upperBound, equals(double.infinity));
      expect(controller.isBounded, isFalse);
    });

    testWidgets('updates spring description', (tester) async {
      controller = SpringSimulationController(
        spring: spring,
        vsync: tester,
      );
      const newSpring = SimpleSpring(durationSeconds: 0.1);
      controller.spring = newSpring;
      expect(controller.spring, equals(newSpring));
    });

    testWidgets('clamps value within bounds', (tester) async {
      controller = SpringSimulationController(
        spring: spring,
        vsync: tester,
      );
      expect(controller.value, equals(0.0));
      controller.value = 2.0;
      expect(controller.value, equals(1.0));

      controller.value = -1.0;
      expect(controller.value, equals(0.0));
    });

    group('.forward', () {
      testWidgets('animates to upper bound', (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        );
        final future = controller.forward();

        await tester.pump();

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(0.0));

        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value, greaterThan(0.0));
        expect(controller.value, lessThan(0.4));

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(1, epsilon: error));
      });
      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = SpringSimulationController(
          spring: SimpleSpring.bouncy,
          vsync: tester,
        );

        controller
          ..addListener(() {
            if (controller.value > 1.0) {
              overshot = true;
            }
          })
          ..forward();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value, closeTo(1.0, 0.01));
      });
    });
  });
}
