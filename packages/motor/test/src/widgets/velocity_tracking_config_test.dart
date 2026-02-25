import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/widgets/base_motion_builder.dart';

void main() {
  group('velocity tracking through widget layer', () {
    group('SingleMotionBuilder', () {
      testWidgets('tracked velocity carries momentum when active is restored',
          (tester) async {
        double capturedValue = 0;

        // --- Scenario 1: tracking ON ---
        await tester.pumpWidget(
          SingleMotionBuilder(
            key: const ValueKey('on'),
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );

        // Get controller and rapidly set values synchronously, same as the
        // controller-level tests. This avoids the 40ms real-time timeout
        // inside the velocity tracker.
        final stateOn = tester.state<BaseMotionBuilderState<double>>(
          find.byType(SingleMotionBuilder),
        );
        stateOn.controller
          ..value = 0.0
          ..value = 20.0
          ..value = 40.0
          ..value = 60.0
          ..value = 80.0
          ..value = 100.0;

        // Verify velocity is actually tracked
        final estimate = stateOn.controller.trackedVelocityEstimate;
        expect(estimate, isNotNull);
        expect(estimate!.perSecond, greaterThan(0));

        // Restore active with a higher target — animateTo uses tracked velocity
        await tester.pumpWidget(
          SingleMotionBuilder(
            key: const ValueKey('on'),
            value: 200,
            motion: const CupertinoMotion.smooth(),
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final valueWithTracking = capturedValue;

        await tester.pumpAndSettle();

        // --- Scenario 2: tracking OFF (fresh widget via different key) ---
        await tester.pumpWidget(
          SingleMotionBuilder(
            key: const ValueKey('off'),
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );

        final stateOff = tester.state<BaseMotionBuilderState<double>>(
          find.byType(SingleMotionBuilder),
        );
        stateOff.controller
          ..value = 0.0
          ..value = 20.0
          ..value = 40.0
          ..value = 60.0
          ..value = 80.0
          ..value = 100.0;

        // Verify no velocity is tracked
        expect(stateOff.controller.trackedVelocityEstimate, isNull);
        expect(stateOff.controller.velocity, 0.0);

        // Restore active with the same target
        await tester.pumpWidget(
          SingleMotionBuilder(
            key: const ValueKey('off'),
            value: 200,
            motion: const CupertinoMotion.smooth(),
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final valueWithoutTracking = capturedValue;

        // With tracked positive velocity the value should have progressed
        // further after one frame than without tracking.
        expect(
          valueWithTracking,
          greaterThan(valueWithoutTracking),
          reason: 'With velocity tracking, the animation should carry momentum '
              'from the rapid value changes, progressing further after one '
              'frame than without tracking.',
        );

        await tester.pumpAndSettle();
      });

      testWidgets(
          'controller exposes non-zero tracked velocity after rapid changes',
          (tester) async {
        await tester.pumpWidget(
          SingleMotionBuilder(
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            builder: (context, value, child) => const SizedBox(),
          ),
        );

        final state = tester.state<BaseMotionBuilderState<double>>(
          find.byType(SingleMotionBuilder),
        );

        // Rapidly increase values synchronously
        state.controller
          ..value = 0.0
          ..value = 10.0
          ..value = 20.0
          ..value = 30.0;

        final estimate = state.controller.trackedVelocityEstimate;
        expect(estimate, isNotNull);
        expect(estimate!.perSecond, greaterThan(0));
      });

      testWidgets('controller has no tracked velocity when tracking is off',
          (tester) async {
        await tester.pumpWidget(
          SingleMotionBuilder(
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, child) => const SizedBox(),
          ),
        );

        final state = tester.state<BaseMotionBuilderState<double>>(
          find.byType(SingleMotionBuilder),
        );

        state.controller
          ..value = 0.0
          ..value = 10.0
          ..value = 20.0
          ..value = 30.0;

        expect(state.controller.trackedVelocityEstimate, isNull);
        expect(state.controller.velocity, 0.0);
      });
    });

    group('MotionBuilder (multi-dimensional)', () {
      testWidgets('tracked velocity carries momentum for Offset values',
          (tester) async {
        Offset capturedValue = Offset.zero;

        // --- Tracking ON ---
        await tester.pumpWidget(
          MotionBuilder<Offset>(
            key: const ValueKey('on'),
            value: Offset.zero,
            motion: const CupertinoMotion.smooth(),
            converter: const OffsetMotionConverter(),
            active: false,
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );

        final stateOn = tester.state<BaseMotionBuilderState<Offset>>(
          find.byType(MotionBuilder<Offset>),
        );
        stateOn.controller
          ..value = Offset.zero
          ..value = const Offset(20, 10)
          ..value = const Offset(40, 20)
          ..value = const Offset(60, 30)
          ..value = const Offset(80, 40)
          ..value = const Offset(100, 50);

        await tester.pumpWidget(
          MotionBuilder<Offset>(
            key: const ValueKey('on'),
            value: const Offset(200, 100),
            motion: const CupertinoMotion.smooth(),
            converter: const OffsetMotionConverter(),
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final withTracking = capturedValue;

        await tester.pumpAndSettle();

        // --- Tracking OFF ---
        await tester.pumpWidget(
          MotionBuilder<Offset>(
            key: const ValueKey('off'),
            value: Offset.zero,
            motion: const CupertinoMotion.smooth(),
            converter: const OffsetMotionConverter(),
            active: false,
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );

        final stateOff = tester.state<BaseMotionBuilderState<Offset>>(
          find.byType(MotionBuilder<Offset>),
        );
        stateOff.controller
          ..value = Offset.zero
          ..value = const Offset(20, 10)
          ..value = const Offset(40, 20)
          ..value = const Offset(60, 30)
          ..value = const Offset(80, 40)
          ..value = const Offset(100, 50);

        await tester.pumpWidget(
          MotionBuilder<Offset>(
            key: const ValueKey('off'),
            value: const Offset(200, 100),
            motion: const CupertinoMotion.smooth(),
            converter: const OffsetMotionConverter(),
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final withoutTracking = capturedValue;

        expect(
          withTracking.dx,
          greaterThan(withoutTracking.dx),
          reason: 'dx should progress further with tracked positive velocity.',
        );
        expect(
          withTracking.dy,
          greaterThan(withoutTracking.dy),
          reason: 'dy should progress further with tracked positive velocity.',
        );

        await tester.pumpAndSettle();
      });

      testWidgets(
          'motionPerDimension constructor also forwards velocity tracking',
          (tester) async {
        await tester.pumpWidget(
          MotionBuilder<Offset>.motionPerDimension(
            value: Offset.zero,
            motionPerDimension: const [
              CupertinoMotion.smooth(),
              CupertinoMotion.smooth(),
            ],
            converter: const OffsetMotionConverter(),
            active: false,
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, child) => const SizedBox(),
          ),
        );

        final state = tester.state<BaseMotionBuilderState<Offset>>(
          find.byType(MotionBuilder<Offset>),
        );
        state.controller
          ..value = Offset.zero
          ..value = const Offset(10, 10)
          ..value = const Offset(20, 20);

        expect(state.controller.trackedVelocityEstimate, isNull);
      });
    });

    group('VelocityMotionBuilder', () {
      testWidgets('tracked velocity is reflected in builder velocity argument',
          (tester) async {
        double capturedVelocity = 0;

        await tester.pumpWidget(
          SingleVelocityMotionBuilder(
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            builder: (context, value, velocity, child) {
              capturedVelocity = velocity;
              return const SizedBox();
            },
          ),
        );

        final state = tester.state<BaseMotionBuilderState<double>>(
          find.byType(SingleVelocityMotionBuilder),
        );
        state.controller
          ..value = 0.0
          ..value = 20.0
          ..value = 40.0
          ..value = 60.0
          ..value = 80.0
          ..value = 100.0;

        // Restore active — animateTo should pick up tracked velocity
        await tester.pumpWidget(
          SingleVelocityMotionBuilder(
            value: 200,
            motion: const CupertinoMotion.smooth(),
            builder: (context, value, velocity, child) {
              capturedVelocity = velocity;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));

        // Velocity should be positive (moving toward 200 with momentum)
        expect(capturedVelocity, greaterThan(0));

        await tester.pumpAndSettle();
      });

      testWidgets('animation velocity is higher with tracking than without',
          (tester) async {
        double capturedVelocity = 0;

        // --- With tracking ---
        await tester.pumpWidget(
          SingleVelocityMotionBuilder(
            key: const ValueKey('on'),
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            builder: (context, value, velocity, child) {
              capturedVelocity = velocity;
              return const SizedBox();
            },
          ),
        );

        tester
            .state<BaseMotionBuilderState<double>>(
              find.byType(SingleVelocityMotionBuilder),
            )
            .controller
          ..value = 0.0
          ..value = 20.0
          ..value = 40.0
          ..value = 60.0
          ..value = 80.0
          ..value = 100.0;

        await tester.pumpWidget(
          SingleVelocityMotionBuilder(
            key: const ValueKey('on'),
            value: 200,
            motion: const CupertinoMotion.smooth(),
            builder: (context, value, velocity, child) {
              capturedVelocity = velocity;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final velocityWithTracking = capturedVelocity;

        await tester.pumpAndSettle();

        // --- Without tracking ---
        await tester.pumpWidget(
          SingleVelocityMotionBuilder(
            key: const ValueKey('off'),
            value: 0,
            motion: const CupertinoMotion.smooth(),
            active: false,
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, velocity, child) {
              capturedVelocity = velocity;
              return const SizedBox();
            },
          ),
        );

        tester
            .state<BaseMotionBuilderState<double>>(
              find.byType(SingleVelocityMotionBuilder),
            )
            .controller
          ..value = 0.0
          ..value = 20.0
          ..value = 40.0
          ..value = 60.0
          ..value = 80.0
          ..value = 100.0;

        await tester.pumpWidget(
          SingleVelocityMotionBuilder(
            key: const ValueKey('off'),
            value: 200,
            motion: const CupertinoMotion.smooth(),
            velocityTracking: const VelocityTracking.off(),
            builder: (context, value, velocity, child) {
              capturedVelocity = velocity;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final velocityWithoutTracking = capturedVelocity;

        expect(
          velocityWithTracking,
          greaterThan(velocityWithoutTracking),
          reason:
              'Animation velocity should be higher when tracked momentum is '
              'carried over from rapid value changes.',
        );

        await tester.pumpAndSettle();
      });
    });
  });
}
