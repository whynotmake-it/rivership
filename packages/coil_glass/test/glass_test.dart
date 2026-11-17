import 'package:coil/coil.dart';
import 'package:coil_glass/coil_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

Widget _app(
  Widget child, {
  CoilGlassMode? mode,
  bool reduceTransparency = false,
  bool highContrast = false,
  bool disableAnimations = false,
}) => MediaQuery(
  data: MediaQueryData(
    highContrast: highContrast,
    disableAnimations: disableAnimations,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CoilTheme(
      data: CoilThemeData.light,
      child: CoilGlassScope(
        mode: mode,
        reduceTransparency: reduceTransparency,
        child: Center(child: child),
      ),
    ),
  ),
);

const _glass = CoilGlassLayer(
  child: CoilGlass(child: SizedBox(width: 100, height: 40)),
);

const _tabs = [
  CoilGlassTab(value: 'a', label: Text('A')),
  CoilGlassTab(value: 'b', label: Text('B')),
  CoilGlassTab(value: 'c', label: Text('C')),
];

void main() {
  group('CoilGlassScope', () {
    testWidgets('renders glass by default', (tester) async {
      await tester.pumpWidget(_app(_glass));
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    testWidgets('Reduce Transparency makes glass a solid coil surface', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_glass, reduceTransparency: true));
      expect(find.byType(LiquidGlassLayer), findsNothing);
      expect(find.byType(LiquidGlass), findsNothing);
      // The painted surface, and the level scope its content sits in.
      expect(find.byType(CoilSurface), findsNWidgets(2));
    });

    testWidgets('high contrast makes glass solid', (tester) async {
      await tester.pumpWidget(_app(_glass, highContrast: true));
      expect(find.byType(LiquidGlassLayer), findsNothing);
      expect(find.byType(LiquidGlass), findsNothing);
      // The painted surface, and the level scope its content sits in.
      expect(find.byType(CoilSurface), findsNWidgets(2));
    });

    testWidgets('frosted renders the fake glass path', (tester) async {
      await tester.pumpWidget(_app(_glass, mode: CoilGlassMode.frosted));
      final layer = tester.widget<LiquidGlassLayer>(
        find.byType(LiquidGlassLayer),
      );
      expect(layer.fake, isTrue);
    });
  });

  group('CoilGlassStyle', () {
    test('merge keeps unset fields', () {
      final merged = const CoilGlassStyle(
        variant: CoilGlassVariant.clear,
        tintAmount: 0.2,
      ).merge(const CoilGlassStyle(tintAmount: 0.8));
      expect(merged.variant, CoilGlassVariant.clear);
      expect(merged.tintAmount, 0.8);
    });

    testWidgets('a theme-level style reaches the layer', (tester) async {
      await tester.pumpWidget(
        _app(
          CoilTheme.override(
            transform: (t) => t.withComponentStyle(
              const CoilGlassStyle(variant: CoilGlassVariant.clear),
            ),
            child: _glass,
          ),
        ),
      );
      final layer = tester.widget<LiquidGlassLayer>(
        find.byType(LiquidGlassLayer),
      );
      expect(
        layer.settings,
        CoilGlassStyle.fallback(
              CoilThemeData.light,
            )
            .merge(const CoilGlassStyle(variant: CoilGlassVariant.clear))
            .settingsFor(Brightness.light),
      );
    });
  });

  testWidgets('content on glass gets the on-glass tab platter', (
    tester,
  ) async {
    late CoilTabsStyle? style;
    await tester.pumpWidget(
      _app(
        CoilGlassLayer(
          child: CoilGlass(
            child: Builder(
              builder: (context) {
                style = CoilTheme.styleOf<CoilTabsStyle>(context);
                return const SizedBox(width: 10, height: 10);
              },
            ),
          ),
        ),
      ),
    );
    expect(style?.pill, CoilOnGlass.platterOf(CoilColors.light));
  });

  group('CoilGlassTabBar', () {
    Widget bar(
      String value,
      ValueChanged<String> onChanged, {
      bool disableAnimations = false,
    }) => _app(
      SizedBox(
        width: 300,
        child: CoilGlassLayer(
          child: CoilGlassTabBar<String>(
            tabs: _tabs,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
      disableAnimations: disableAnimations,
    );

    testWidgets('a tap reports the tab value', (tester) async {
      String? changed;
      await tester.pumpWidget(bar('a', (v) => changed = v));
      await tester.tap(find.text('C'));
      expect(changed, 'c');
    });

    testWidgets('scrubbing lands on the tab under the finger', (tester) async {
      String? changed;
      await tester.pumpWidget(bar('a', (v) => changed = v));
      final start = tester.getCenter(find.text('A'));
      final end = tester.getCenter(find.text('B'));
      await tester.dragFrom(start, end - start);
      await tester.pump();
      expect(changed, 'b');
    });

    testWidgets('the lens lifts off while the selection travels', (
      tester,
    ) async {
      await tester.pumpWidget(bar('a', (_) {}));
      expect(find.byType(LiquidGlassVisibility), findsNothing);
      await tester.pumpWidget(bar('c', (_) {}));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(LiquidGlassVisibility), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassVisibility), findsNothing);
    });

    testWidgets('reduced motion never shows the lens', (tester) async {
      await tester.pumpWidget(bar('a', (_) {}, disableAnimations: true));
      await tester.pumpWidget(bar('c', (_) {}, disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(LiquidGlassVisibility), findsNothing);
    });
  });
}
