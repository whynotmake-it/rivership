import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [input]'s field is drawn with a lit edge.
bool _lit(WidgetTester tester, Finder input) => find
    .descendant(
      of: input,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is CoilReliefBorder,
      ),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    CoilTheme(
      data: CoilThemeData.light.copyWith(plasticity: CoilPlasticity.subtle),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );

  group('plasticity on surfaces', () {
    testWidgets('controls on the page are lit', (tester) async {
      await pump(tester, const CoilInput(key: Key('field')));
      expect(_lit(tester, find.byKey(const Key('field'))), isTrue);
    });

    testWidgets('controls on an elevated surface are flat', (tester) async {
      late CoilPlasticity inside;
      await pump(
        tester,
        CoilSurface(
          offset: CoilSurface.popoverOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoilInput(key: Key('field')),
              Builder(
                builder: (context) {
                  inside = CoilTheme.of(context).plasticity;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      expect(inside, CoilPlasticity.flat);
      expect(_lit(tester, find.byKey(const Key('field'))), isFalse);
    });

    testWidgets('a card scope flattens its content too', (tester) async {
      await pump(
        tester,
        const CoilSurface.scope(
          offset: 1,
          child: CoilInput(key: Key('field')),
        ),
      );
      expect(_lit(tester, find.byKey(const Key('field'))), isFalse);
    });

    testWidgets('a style override still lights a control on a surface', (
      tester,
    ) async {
      await pump(
        tester,
        const CoilSurface(
          offset: CoilSurface.popoverOffset,
          child: CoilInput(
            key: Key('field'),
            style: CoilInputStyle(plasticity: CoilPlasticity.subtle),
          ),
        ),
      );
      expect(_lit(tester, find.byKey(const Key('field'))), isTrue);
    });

    testWidgets("a surface's own edge doesn't depend on where it opens", (
      tester,
    ) async {
      /// The relief on [surface]'s own fill.
      CoilRelief? edgeOf(Finder surface) {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(of: surface, matching: find.byType(DecoratedBox))
              .first,
        );
        final shape = (box.decoration as ShapeDecoration).shape;
        return shape is CoilReliefBorder ? shape.relief : null;
      }

      await tester.pumpWidget(
        CoilTheme(
          data: CoilThemeData.light.copyWith(plasticity: CoilPlasticity.soft),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                CoilSurface(
                  key: Key('page'),
                  offset: CoilSurface.popoverOffset,
                  child: SizedBox(height: 20),
                ),
                // Opened from inside a card: an elevated scope.
                CoilSurface.scope(
                  offset: 1,
                  child: CoilSurface(
                    key: Key('card'),
                    offset: CoilSurface.popoverOffset,
                    child: SizedBox(height: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final onPage = edgeOf(find.byKey(const Key('page')));
      expect(onPage, isNotNull);
      expect(edgeOf(find.byKey(const Key('card'))), onPage);
    });

    testWidgets('an unelevated scope lights a subtree again', (tester) async {
      await pump(
        tester,
        const CoilSurface(
          offset: CoilSurface.popoverOffset,
          child: CoilPlasticityScope(
            elevated: false,
            child: CoilInput(key: Key('field')),
          ),
        ),
      );
      expect(_lit(tester, find.byKey(const Key('field'))), isTrue);
    });
  });

  test('roles scale and switch off lighting per role', () {
    const p = CoilPlasticity.subtle;
    expect(p.resolve(CoilReliefRole.track, Brightness.light), isNull);
    expect(p.resolve(CoilReliefRole.quiet, Brightness.dark), isNull);
    expect(p.resolve(CoilReliefRole.raised, Brightness.light), isNotNull);
    expect(CoilPlasticity.flat.resolve(.raised, Brightness.light), isNull);
    expect(
      p.resolve(CoilReliefRole.raised, Brightness.light, enabled: false),
      isNull,
    );
  });

  group('CoilRelief.decorate', () {
    final relief = CoilPlasticity.tactile.resolve(.raised, Brightness.light)!;
    const plain = ShapeDecoration(
      color: Color(0xFFFFFFFF),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );

    test('is idempotent: a lit shape is lit once', () {
      final once = CoilRelief.decorate(plain, relief);
      final twice = CoilRelief.decorate(once, relief);
      expect(twice.shape, once.shape);
      final border = twice.shape as CoilReliefBorder;
      expect(border.shape, plain.shape);
    });

    test('a second relief replaces the first', () {
      final other = CoilPlasticity.subtle.resolve(.raised, Brightness.dark)!;
      final lit = CoilRelief.decorate(
        CoilRelief.decorate(plain, relief),
        other,
      );
      expect((lit.shape as CoilReliefBorder).relief, other);
    });

    test('asserts on shapes that are not superellipses', () {
      expect(
        () => CoilRelief.decorate(
          const ShapeDecoration(shape: StadiumBorder()),
          relief,
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('RoundedSuperellipseBorder'),
          ),
        ),
      );
    });

    test('tweens keep their corners and fade the light', () {
      final lit = CoilRelief.decorate(plain, relief);
      const wide = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      );
      for (final (from, to) in [
        (plain.shape, lit.shape),
        (lit.shape, plain.shape),
        (
          lit.shape,
          CoilRelief.decorate(const ShapeDecoration(shape: wide), relief).shape,
        ),
      ]) {
        final mid = ShapeBorder.lerp(from, to, 0.5);
        expect(mid, isA<CoilReliefBorder>(), reason: '$from -> $to');
        final shape = (mid! as CoilReliefBorder).shape;
        // No collapse through a scaled-down shape: the radius stays in
        // between the ends.
        final radius = (shape.borderRadius as BorderRadius).topLeft.x;
        expect(radius, inInclusiveRange(8, 12));
      }
      // Half way from unlit, the light is half on.
      final half =
          (ShapeBorder.lerp(plain.shape, lit.shape, 0.5)! as CoilReliefBorder)
              .relief;
      expect(half.edgeTop.a, closeTo(relief.edgeTop.a / 2, 0.01));
    });
  });
}
