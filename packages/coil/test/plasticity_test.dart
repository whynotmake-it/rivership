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
}
