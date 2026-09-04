import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

/// One animation frame. The fake test clock advances with `pump`, so feeding
/// values this far apart yields a deterministic tracked velocity.
const _frame = Duration(milliseconds: 16);

void main() {
  group('velocity tracking through widget layer', () {
    // These tests drive everything through the public widget API: rebuilding a
    // builder with `active: false` and a new `value` records a velocity sample
    // (see BaseMotionBuilderState.didUpdateWidget), and pumping between
    // rebuilds advances the (fake) clock so the tracked velocity is exact.
    //
    // Feeding 0 -> 20 -> 40 -> 60 -> 80 -> 100 one frame apart is a constant
    // 20px / 16ms = 1250px/s, which the tracker reports with full confidence.
    const fed = [20.0, 40.0, 60.0, 80.0, 100.0];
    const expectedVelocity = 1250.0;

    group('SingleMotionBuilder', () {
      Future<double> runScenario(
        WidgetTester tester, {
        required VelocityTracking tracking,
        required Key key,
      }) async {
        var captured = 0.0;
        Widget build(double value, {required bool active}) =>
            SingleMotionBuilder(
              key: key,
              value: value,
              active: active,
              motion: const CupertinoMotion.smooth(),
              velocityTracking: tracking,
              builder: (context, value, child) {
                captured = value;
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(0, active: false));
        for (final v in fed) {
          await tester.pump(_frame);
          await tester.pumpWidget(build(v, active: false));
        }

        // Re-activate toward a far target: animateTo adopts the tracked
        // velocity, so a single frame of progress reflects the momentum.
        await tester.pump(_frame);
        await tester.pumpWidget(build(200, active: true));
        await tester.pump(_frame);
        return captured;
      }

      testWidgets('tracked velocity carries momentum when active is restored',
          (tester) async {
        final withTracking = await runScenario(
          tester,
          tracking: const VelocityTracking.on(),
          key: const ValueKey('on'),
        );
        await tester.pumpAndSettle();

        final withoutTracking = await runScenario(
          tester,
          tracking: const VelocityTracking.off(),
          key: const ValueKey('off'),
        );
        await tester.pumpAndSettle();

        expect(
          withTracking,
          greaterThan(withoutTracking),
          reason: 'With velocity tracking the animation carries momentum from '
              'the rapid value changes, progressing further after one frame.',
        );
      });
    });

    group('MotionBuilder (multi-dimensional)', () {
      testWidgets('tracked velocity carries momentum for Offset values',
          (tester) async {
        Future<Offset> runScenario({
          required VelocityTracking tracking,
          required Key key,
        }) async {
          var captured = Offset.zero;
          Widget build(Offset value, {required bool active}) =>
              MotionBuilder<Offset>(
                key: key,
                value: value,
                active: active,
                motion: const CupertinoMotion.smooth(),
                converter: const OffsetMotionConverter(),
                velocityTracking: tracking,
                builder: (context, value, child) {
                  captured = value;
                  return const SizedBox();
                },
              );

          await tester.pumpWidget(build(Offset.zero, active: false));
          for (final v in fed) {
            await tester.pump(_frame);
            // Move twice as fast on x as on y.
            await tester.pumpWidget(build(Offset(v, v / 2), active: false));
          }
          await tester.pump(_frame);
          await tester.pumpWidget(build(const Offset(200, 100), active: true));
          await tester.pump(_frame);
          return captured;
        }

        final withTracking = await runScenario(
          tracking: const VelocityTracking.on(),
          key: const ValueKey('on'),
        );
        await tester.pumpAndSettle();
        final withoutTracking = await runScenario(
          tracking: const VelocityTracking.off(),
          key: const ValueKey('off'),
        );
        await tester.pumpAndSettle();

        expect(withTracking.dx, greaterThan(withoutTracking.dx));
        expect(withTracking.dy, greaterThan(withoutTracking.dy));
      });

      testWidgets(
          'motionPerDimension constructor forwards velocity tracking',
          (tester) async {
        // Feed identical samples for both configs (so they start the activated
        // animation from the same position) and compare progress. Only the
        // tracking-on run should carry momentum, proving the flag is forwarded
        // through the motionPerDimension constructor.
        Future<Offset> runScenario({
          required VelocityTracking tracking,
          required Key key,
        }) async {
          var captured = Offset.zero;
          Widget build(Offset value, {required bool active}) =>
              MotionBuilder<Offset>.motionPerDimension(
                key: key,
                value: value,
                active: active,
                motionPerDimension: const [
                  CupertinoMotion.smooth(),
                  CupertinoMotion.smooth(),
                ],
                converter: const OffsetMotionConverter(),
                velocityTracking: tracking,
                builder: (context, value, child) {
                  captured = value;
                  return const SizedBox();
                },
              );

          await tester.pumpWidget(build(Offset.zero, active: false));
          for (final v in fed) {
            await tester.pump(_frame);
            await tester.pumpWidget(build(Offset(v, v / 2), active: false));
          }
          await tester.pump(_frame);
          await tester.pumpWidget(build(const Offset(200, 100), active: true));
          await tester.pump(_frame);
          return captured;
        }

        final withTracking = await runScenario(
          tracking: const VelocityTracking.on(),
          key: const ValueKey('on'),
        );
        await tester.pumpAndSettle();
        final withoutTracking = await runScenario(
          tracking: const VelocityTracking.off(),
          key: const ValueKey('off'),
        );
        await tester.pumpAndSettle();

        expect(
          withTracking.dx,
          greaterThan(withoutTracking.dx),
          reason: 'Tracking on must carry momentum through motionPerDimension.',
        );
        expect(withTracking.dy, greaterThan(withoutTracking.dy));
      });
    });

    group('SingleVelocityMotionBuilder', () {
      Future<double> velocityAfterActivation(
        WidgetTester tester, {
        required VelocityTracking tracking,
        required Key key,
      }) async {
        var capturedVelocity = 0.0;
        Widget build(double value, {required bool active}) =>
            SingleVelocityMotionBuilder(
              key: key,
              value: value,
              active: active,
              motion: const CupertinoMotion.smooth(),
              velocityTracking: tracking,
              builder: (context, value, velocity, child) {
                capturedVelocity = velocity;
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(0, active: false));
        for (final v in fed) {
          await tester.pump(_frame);
          await tester.pumpWidget(build(v, active: false));
        }
        await tester.pump(_frame);
        await tester.pumpWidget(build(200, active: true));
        // Zero-duration frame: the simulation's initial velocity equals the
        // tracked velocity exactly before any time elapses.
        await tester.pump();
        return capturedVelocity;
      }

      testWidgets(
          'tracked velocity is reflected in the builder velocity argument',
          (tester) async {
        final velocity = await velocityAfterActivation(
          tester,
          tracking: const VelocityTracking.on(),
          key: const ValueKey('on'),
        );

        expect(velocity, closeTo(expectedVelocity, 1));

        await tester.pumpAndSettle();
      });

      testWidgets('animation velocity is higher with tracking than without',
          (tester) async {
        final withTracking = await velocityAfterActivation(
          tester,
          tracking: const VelocityTracking.on(),
          key: const ValueKey('on'),
        );
        await tester.pumpAndSettle();

        final withoutTracking = await velocityAfterActivation(
          tester,
          tracking: const VelocityTracking.off(),
          key: const ValueKey('off'),
        );
        await tester.pumpAndSettle();

        expect(withoutTracking, moreOrLessEquals(0, epsilon: error));
        expect(withTracking, greaterThan(withoutTracking));
        expect(withTracking, closeTo(expectedVelocity, 1));
      });
    });
  });
}
