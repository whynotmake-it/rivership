import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_widgets/motor_widgets.dart';

const _child = SizedBox(width: 20, height: 20);

Future<Widget> _built(
  WidgetTester tester,
  MotionTransition transition,
  double presence,
) async {
  late Widget built;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) =>
            built = transition.build(context, presence, _child),
      ),
    ),
  );
  return built;
}

void main() {
  group('MotionTransition', () {
    test('compares by value', () {
      expect(MotionTransition.fade, MotionTransition.fade);
      expect(
        const MotionTransition.scale(0.8),
        const MotionTransition.scale(0.8),
      );
      expect(
        const MotionTransition.scale(0.8),
        isNot(const MotionTransition.scale(0.9)),
      );
      expect(
        const MotionTransition.blurFade(blur: 2),
        const MotionTransition.blurFade(blur: 2),
      );
      expect(
        const MotionTransition.blurFade().hashCode,
        const MotionTransition.blurFade().hashCode,
      );
      expect(
        MotionTransition.fade + const MotionTransition.slide(Offset(0, 1)),
        MotionTransition.fade + const MotionTransition.slide(Offset(0, 1)),
      );
      expect(
        MotionTransition.fade + const MotionTransition.scale(0.5),
        isNot(const MotionTransition.scale(0.5) + MotionTransition.fade),
      );
    });

    test('composition flattens and drops none', () {
      const a = MotionTransition.translate(Offset(1, 0));
      const b = MotionTransition.blur(2);
      expect(
        MotionTransition.fade + MotionTransition.none,
        MotionTransition.fade,
      );
      expect(MotionTransition.none + a, a);
      expect((MotionTransition.fade + a) + b, MotionTransition.fade + (a + b));
    });

    testWidgets('a + b wraps the child in b, then in a', (tester) async {
      final built = await _built(
        tester,
        MotionTransition.fade + const MotionTransition.scale(0.5),
        0.5,
      );
      expect(built, isA<Opacity>());
      expect((built as Opacity).child, isA<Transform>());
    });

    testWidgets('fade clamps opacity', (tester) async {
      Future<double> opacity(double presence) async =>
          (await _built(tester, MotionTransition.fade, presence) as Opacity)
              .opacity;
      expect(await opacity(-0.2), 0);
      expect(await opacity(0.3), 0.3);
      expect(await opacity(1.2), 1);
    });

    testWidgets('scale extrapolates when presence overshoots', (tester) async {
      Future<double> scale(double presence) async =>
          (await _built(tester, const MotionTransition.scale(0.5), presence)
                  as Transform)
              .transform
              .storage[0];
      expect(await scale(0), 0.5);
      expect(await scale(0.5), 0.75);
      expect(await scale(1), 1);
      expect(await scale(1.1), closeTo(1.05, 1e-12));
    });

    testWidgets('blur is turned off once sharp, keeping the tree', (
      tester,
    ) async {
      Future<ImageFiltered> filter(double presence) async => tester.widget(
        find.byType(ImageFiltered),
      );
      await _built(tester, const MotionTransition.blurFade(), 0.5);
      expect((await filter(0.5)).enabled, isTrue);
      await _built(tester, const MotionTransition.blurFade(), 1);
      expect((await filter(1)).enabled, isFalse);
      await _built(tester, const MotionTransition.blurFade(), 1.1);
      expect((await filter(1.1)).enabled, isFalse);
      await _built(tester, const MotionTransition.blur(0), 0);
      expect((await filter(0)).enabled, isFalse);
    });
  });
}
