// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('TrackController.animate targets the correct value', () {
    late TrackController controller;
    final offset = Track<Offset>(MotionConverter.offset, zero: Offset.zero);

    const spring = Motion.interactiveSpring();

    tearDown(() {
      controller.dispose();
    });

    testWidgets(
      'single animate call targets the correct offset',
      (tester) async {
        controller = TrackController(
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        );

        // Set to a known position first
        const draggedTo = Offset(100, 50);
        controller.set([offset.value(draggedTo)]);
        expect(controller.value(offset), equals(draggedTo));

        // Now animate to the same position (simulating what happens when
        // set is replaced with animate in _onPanUpdate)
        controller.animate([offset.to(draggedTo, motion: spring)]);

        // The animation target is the current value, so it should already
        // be there (or very close) and settle at exactly that value.
        await tester.pumpAndSettle();

        expect(controller.value(offset).dx, closeTo(draggedTo.dx, error));
        expect(controller.value(offset).dy, closeTo(draggedTo.dy, error));
      },
    );

    testWidgets(
      'animate after set targets the value passed to animate, not zero',
      (tester) async {
        controller = TrackController(
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        );

        // Simulate one pan update with set, then next one with animate
        const firstDelta = Offset(30, 15);
        const secondDelta = Offset(20, 10);

        // First update with set (like _onPanUpdate before the change)
        final afterFirst = controller.value(offset) + firstDelta;
        controller.set([offset.value(afterFirst)]);
        expect(controller.value(offset), equals(firstDelta));

        // Second update with animate (the changed code)
        final target = controller.value(offset) + secondDelta;
        controller.animate([offset.to(target, motion: spring)]);

        await tester.pumpAndSettle();

        // Should settle at firstDelta + secondDelta
        final expected = firstDelta + secondDelta;
        expect(controller.value(offset).dx, closeTo(expected.dx, error));
        expect(controller.value(offset).dy, closeTo(expected.dy, error));
      },
    );

    testWidgets(
      'animate from non-zero position targets the correct offset',
      (tester) async {
        controller = TrackController(
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        );

        // Move to a non-zero position via set
        const position = Offset(80, 40);
        controller.set([offset.value(position)]);

        // Now animate to a new position (simulating the next pan update
        // being animate instead of set)
        const target = Offset(100, 50);
        controller.animate([offset.to(target, motion: spring)]);

        await tester.pumpAndSettle();

        expect(controller.value(offset).dx, closeTo(target.dx, error));
        expect(controller.value(offset).dy, closeTo(target.dy, error));
      },
    );
  });
}
