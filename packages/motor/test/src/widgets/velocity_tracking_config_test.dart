import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

/// One animation frame. The fake test clock advances with `pump`, so feeding
/// values this far apart yields a deterministic tracked velocity.
const _frame = Duration(milliseconds: 16);

/// Builds a builder for the scalar `value` that reports each dimension of
/// what it built to `capture`. Offset variants move twice as fast on x as on y.
typedef _BuildTracked = Widget Function(double value, _Config config);

typedef _Config = ({
  bool active,
  VelocityTracking tracking,
  Key key,
  ValueSetter<List<double>> capture,
});

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

    /// Feeds [fed] while inactive, then re-activates toward a far target and
    /// returns what [build] reported after [after] elapsed.
    Future<List<double>> runScenario(
      WidgetTester tester,
      _BuildTracked build, {
      required VelocityTracking tracking,
      Duration after = _frame,
    }) async {
      var captured = <double>[];
      final key = ValueKey(tracking);
      Widget buildAt(double value, {required bool active}) => build(
            value,
            (
              active: active,
              tracking: tracking,
              key: key,
              capture: (values) => captured = values,
            ),
          );

      await tester.pumpWidget(buildAt(0, active: false));
      for (final v in fed) {
        await tester.pump(_frame);
        await tester.pumpWidget(buildAt(v, active: false));
      }

      // animateTo adopts the tracked velocity, so progress right after
      // re-activating reflects the momentum.
      await tester.pump(_frame);
      await tester.pumpWidget(buildAt(200, active: true));
      await tester.pump(after);
      final result = captured;
      await tester.pumpAndSettle();
      return result;
    }

    for (final (name, _BuildTracked build) in [
      (
        'SingleMotionBuilder',
        (value, c) => SingleMotionBuilder(
              key: c.key,
              value: value,
              active: c.active,
              motion: const CupertinoMotion.smooth(),
              velocityTracking: c.tracking,
              builder: (context, value, child) {
                c.capture([value]);
                return const SizedBox();
              },
            ),
      ),
      (
        'MotionBuilder with Offset values',
        (value, c) => MotionBuilder<Offset>(
              key: c.key,
              value: Offset(value, value / 2),
              active: c.active,
              motion: const CupertinoMotion.smooth(),
              converter: const OffsetMotionConverter(),
              velocityTracking: c.tracking,
              builder: (context, value, child) {
                c.capture([value.dx, value.dy]);
                return const SizedBox();
              },
            ),
      ),
      (
        'MotionBuilder.motionPerDimension',
        (value, c) => MotionBuilder<Offset>.motionPerDimension(
              key: c.key,
              value: Offset(value, value / 2),
              active: c.active,
              motionPerDimension: const [
                CupertinoMotion.smooth(),
                CupertinoMotion.smooth(),
              ],
              converter: const OffsetMotionConverter(),
              velocityTracking: c.tracking,
              builder: (context, value, child) {
                c.capture([value.dx, value.dy]);
                return const SizedBox();
              },
            ),
      ),
    ]) {
      testWidgets('$name carries tracked momentum when active is restored',
          (tester) async {
        final withTracking = await runScenario(
          tester,
          build,
          tracking: const VelocityTracking.on(),
        );
        final withoutTracking = await runScenario(
          tester,
          build,
          tracking: const VelocityTracking.off(),
        );

        for (var i = 0; i < withTracking.length; i++) {
          expect(
            withTracking[i],
            greaterThan(withoutTracking[i]),
            reason:
                'Dimension $i: with velocity tracking the animation carries '
                'momentum from the rapid value changes, progressing further '
                'after one frame.',
          );
        }
      });
    }

    testWidgets(
        'SingleVelocityMotionBuilder starts with the tracked velocity '
        'only when tracking is on', (tester) async {
      Widget build(double value, _Config c) => SingleVelocityMotionBuilder(
            key: c.key,
            value: value,
            active: c.active,
            motion: const CupertinoMotion.smooth(),
            velocityTracking: c.tracking,
            builder: (context, value, velocity, child) {
              c.capture([velocity]);
              return const SizedBox();
            },
          );

      // Zero-duration frame: the simulation's initial velocity equals the
      // tracked velocity exactly before any time elapses.
      final [withTracking] = await runScenario(
        tester,
        build,
        tracking: const VelocityTracking.on(),
        after: Duration.zero,
      );
      final [withoutTracking] = await runScenario(
        tester,
        build,
        tracking: const VelocityTracking.off(),
        after: Duration.zero,
      );

      expect(withoutTracking, moreOrLessEquals(0, epsilon: error));
      expect(withTracking, greaterThan(withoutTracking));
      expect(withTracking, closeTo(expectedVelocity, 1));
    });

    testWidgets(
        'a rebuild can turn tracking on for a SingleVelocityMotionBuilder',
        (tester) async {
      var velocity = 0.0;
      Widget build(double value, VelocityTracking tracking) =>
          SingleVelocityMotionBuilder(
            value: value,
            active: false,
            motion: const CupertinoMotion.smooth(),
            velocityTracking: tracking,
            builder: (context, value, v, child) {
              velocity = v;
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(0, const VelocityTracking.off()));
      for (final v in fed) {
        await tester.pump(_frame);
        await tester.pumpWidget(build(v, const VelocityTracking.on()));
      }

      expect(velocity, closeTo(expectedVelocity, error));
    });
  });
}
