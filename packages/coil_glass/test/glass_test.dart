import 'package:coil/coil.dart';
import 'package:coil_glass/coil_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

Widget _app(
  Widget child, {
  bool glass = true,
  CoilGlassMode? mode,
  bool reduceTransparency = false,
  bool highContrast = false,
}) {
  final app = Overlay(
    initialEntries: [OverlayEntry(builder: (_) => Center(child: child))],
  );
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      highContrast: highContrast,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: CoilTheme(
        data: CoilThemeData.light,
        child: glass
            ? CoilGlassScope(
                mode: mode,
                reduceTransparency: reduceTransparency,
                child: app,
              )
            : app,
      ),
    ),
  );
}

Widget _button({CoilButtonVariant variant = CoilButtonVariant.glass}) =>
    CoilButton(onPressed: () {}, variant: variant, child: const Text('Share'));

final _inButton = find.descendant(
  of: find.byType(CoilButton),
  matching: find.byType(LiquidGlass),
);

void main() {
  group('glass buttons', () {
    testWidgets('a glass variant renders on liquid glass', (tester) async {
      await tester.pumpWidget(_app(_button()));
      expect(_inButton, findsOneWidget);
    });

    testWidgets('the prominent variant is tinted with the brand', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_button(variant: CoilButtonVariant.glassProminent)),
      );
      final glass = tester.widget<LiquidGlass>(_inButton);
      expect(
        glass.appearance,
        CoilGlassStyle.fallback(CoilThemeData.light)
            .merge(const CoilGlassStyle(variant: CoilGlassVariant.tinted))
            .appearanceFor(Brightness.light),
      );
    });

    testWidgets('other variants stay coil-flat', (tester) async {
      await tester.pumpWidget(
        _app(_button(variant: CoilButtonVariant.secondary)),
      );
      expect(find.byType(LiquidGlass), findsNothing);
    });

    testWidgets('a group is one layer with a blend group', (tester) async {
      await tester.pumpWidget(
        _app(
          CoilMaterialGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_button(), _button()],
            ),
          ),
        ),
      );
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      expect(find.byType(LiquidGlassBlendGroup), findsOneWidget);
    });
  });

  group('fallbacks', () {
    for (final (name, app) in [
      ('without the scope', _app(_button(), glass: false)),
      ('Reduce Transparency', _app(_button(), reduceTransparency: true)),
      ('high contrast', _app(_button(), highContrast: true)),
    ]) {
      testWidgets('$name: coil paints its raised surface', (tester) async {
        await tester.pumpWidget(app);
        expect(find.byType(LiquidGlass), findsNothing);
        expect(
          find.descendant(
            of: find.byType(CoilButton),
            matching: find.byType(CoilSurface),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('frosted renders the fake glass path', (tester) async {
      await tester.pumpWidget(_app(_button(), mode: CoilGlassMode.frosted));
      final layer = tester.widget<LiquidGlassLayer>(
        find.byType(LiquidGlassLayer),
      );
      expect(layer.fake, isTrue);
    });
  });

  testWidgets('a popover is dense glass in a layer of its own', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CoilMaterialGroup(
          child: CoilDropdown(
            presentation: CoilPresentation.popover,
            entries: [
              CoilAction(label: const Text('Delete'), onPressed: () {}),
            ],
            builder: (context, menu) => CoilButton(
              onPressed: menu.open,
              variant: CoilButtonVariant.glass,
              child: const Text('More'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final popover = find.ancestor(
      of: find.text('Delete'),
      matching: find.byType(LiquidGlassLayer),
    );
    // The popover's own layer, inside the trigger cluster's.
    expect(popover, findsNWidgets(2));
    final layer = tester.widget<LiquidGlassLayer>(popover.first);
    expect(
      layer.settings,
      CoilGlassStyle.fallback(
        CoilThemeData.light,
      ).merge(CoilGlassStyle.dense).settingsFor(Brightness.light),
    );
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

    test('a wash tints regular glass with the solid fill', () {
      final look = CoilGlassStyle.fallback(
        CoilThemeData.dark,
      ).merge(CoilGlassStyle.dense);
      expect(
        look.appearanceFor(Brightness.dark).tint,
        look.solidFill!.withValues(alpha: 0.6),
      );
    });
  });

  testWidgets('content on glass gets the on-glass tab platter', (
    tester,
  ) async {
    late CoilTabsStyle? style;
    await tester.pumpWidget(
      _app(
        CoilGlass(
          child: Builder(
            builder: (context) {
              style = CoilTheme.styleOf<CoilTabsStyle>(context);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      ),
    );
    expect(style?.pill, CoilOnGlass.platterOf(CoilColors.light));
  });
}
