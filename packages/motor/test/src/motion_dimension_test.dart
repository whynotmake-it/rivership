// ignore_for_file: cascade_invocations, unawaited_futures

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

double _radians(double degrees) => degrees * math.pi / 180;

void main() {
  const linear = Motion.linear(Duration(milliseconds: 100));
  const bouncy = Motion.bouncySpring();

  group('MotionDimension', () {
    test('compares by value', () {
      expect(const MotionDimension.linear(), const MotionDimension.linear());
      expect(
        const MotionDimension.periodic(2),
        isNot(const MotionDimension.periodic(3)),
      );
      expect(
        const MotionDimension.bounded(0, 1),
        const MotionDimension.bounded(0, 1),
      );
      expect(MotionConverter.angle.dimensions, [
        const MotionDimension.periodic(2 * math.pi),
      ]);
    });
  });

  group('periodic dimensions', () {
    testWidgets('angle takes the short way round', (tester) async {
      final controller = MotionController(
        motion: linear,
        vsync: tester,
        converter: MotionConverter.angle,
        initialValue: _radians(350),
      );
      addTearDown(controller.dispose);

      controller.animateTo(_radians(10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value, closeTo(_radians(360), 0.2));
      await tester.pumpAndSettle();
      expect(controller.value, closeTo(_radians(370), 1e-6));
    });

    testWidgets('each step unwraps relative to the previous one',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final angle = Track<double>(
        MotionConverter.angle,
        initial: _radians(350),
        motion: linear,
      );

      controller.animate([
        angle([
          TrackStep.to(_radians(10)),
          TrackStep.to(_radians(350)),
          TrackStep.to(_radians(20)),
        ]),
      ]);
      await tester.pumpAndSettle();
      // +20, -20 (back to 350), +30.
      expect(controller.value(angle), closeTo(_radians(380), 1e-6));
    });
  });

  group('bounded dimensions', () {
    testWidgets('clamp the shown color, not velocity or overshoot',
        (tester) async {
      final controller = MotionController(
        motion: bouncy,
        vsync: tester,
        converter: MotionConverter.colorRgb,
        initialValue: const Color(0xFF000000),
      );
      addTearDown(controller.dispose);

      controller.animateTo(const Color(0xFFFFFFFF));
      var sawNegativeVelocity = false;
      var sawOvershoot = false;
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final color = controller.value;
        expect(color.r, inInclusiveRange(0, 1));
        sawNegativeVelocity |= controller.velocity.r < 0;
        sawOvershoot |= color.r == 1 && controller.velocity.r > 0;
      }
      expect(sawNegativeVelocity, isTrue);
      expect(sawOvershoot, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('retargeting mid-overshoot stays continuous', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final channel = Track<Color>(
        MotionConverter.colorRgb,
        initial: const Color(0xFF000000),
        motion: bouncy,
      );

      controller.animate([
        channel([const TrackStep.to(Color(0xFFFFFFFF))]),
      ]);
      await tester.pump();
      // Run until the red channel overshoots: shown clamped at 1 while its
      // velocity is already negative.
      do {
        await tester.pump(const Duration(milliseconds: 8));
      } while (controller.velocity(channel).r >= 0);
      expect(controller.value(channel).r, 1);
      final velocity = controller.velocity(channel).r;

      controller.animate([
        channel([const TrackStep.to(Color(0xFF000000))]),
      ]);
      await tester.pump();
      expect(controller.value(channel).r, 1);
      expect(controller.velocity(channel).r, closeTo(velocity, 0.5));
      await tester.pumpAndSettle();
    });

    testWidgets('does not change where the spring settles', (tester) async {
      final controller = MotionController(
        motion: bouncy,
        vsync: tester,
        converter: MotionConverter.colorRgb,
        initialValue: const Color(0xFF000000),
      );
      addTearDown(controller.dispose);

      controller.animateTo(const Color(0xFF336699));
      await tester.pumpAndSettle();
      expect(controller.value, const Color(0xFF336699));
    });
  });

  group('declared dimensions', () {
    test('built-ins declare their dimension counts', () {
      expect(MotionConverter.single.dimensions, hasLength(1));
      expect(MotionConverter.offset.dimensions, hasLength(2));
      expect(MotionConverter.size.dimensions, hasLength(2));
      expect(MotionConverter.alignment.dimensions, hasLength(2));
      expect(MotionConverter.rect.dimensions, hasLength(4));
      expect(MotionConverter.edgeInsets.dimensions, hasLength(4));
      expect(MotionConverter.edgeInsetsDirectional.dimensions, hasLength(4));
      expect(MotionConverter.colorRgb.dimensions, hasLength(4));
    });

    test('a wrong motionPerDimension length asserts early', () {
      expect(
        () => Track<Offset>.motionPerDimension(
          MotionConverter.offset,
          motionPerDimension: const [linear],
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => '${e.message}',
            'message',
            allOf(contains('OffsetMotionConverter'), contains('2')),
          ),
        ),
      );
    });

    testWidgets('a custom converter with dimensions behaves the same',
        (tester) async {
      const converter = MotionConverter<double>.custom(
        normalize: _normalizeAngle,
        denormalize: _denormalizeAngle,
        dimensions: [MotionDimension.periodic(360)],
      );
      expect(
        converter,
        const MotionConverter<double>.custom(
          normalize: _normalizeAngle,
          denormalize: _denormalizeAngle,
          dimensions: [MotionDimension.periodic(360)],
        ),
      );
      final controller = MotionController(
        motion: linear,
        vsync: tester,
        converter: converter,
        initialValue: 350.0,
      );
      addTearDown(controller.dispose);

      controller.animateTo(10.0);
      await tester.pumpAndSettle();
      expect(controller.value, closeTo(370, 1e-6));
      expect(
        () => MotionController.motionPerDimension(
          motionPerDimension: const [linear, linear],
          vsync: tester,
          converter: converter,
          initialValue: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

List<double> _normalizeAngle(double value) => [value];
double _denormalizeAngle(List<double> values) => values[0];
