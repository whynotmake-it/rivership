import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/paint_probe.dart';
import 'src/select_harness.dart';

/// Shows the level a [CoilSurface] gave it.
class _Level extends StatelessWidget {
  const _Level();

  @override
  Widget build(BuildContext context) => Text(
    'level ${CoilSurface.levelOf(context)}',
    style: const CoilTypography().style(
      CoilMetrics.pointer.caption,
      color: CoilTheme.of(context).colors.foreground,
    ),
  );
}

Widget _panel(int offset, Widget child, {int? shadowLevel}) => CoilSurface(
  offset: offset,
  shadowLevel: shadowLevel,
  borderRadius: BorderRadius.circular(14),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

void main() {
  group('components follow the surface scope', _surfaceScopeTests);

  group('shadow recipes', () {
    for (final colors in [CoilColors.light, CoilColors.dark]) {
      test('${colors.brightness.name}: drops blur like their CSS recipes', () {
        for (var level = 1; level <= 8; level++) {
          for (final shadow in colors.shadow(level)) {
            final cssBlur = shadow.offset.dy;
            // The ring has no blur; a 1 px drop (sigma 0.5) is a hard edge.
            if (cssBlur <= 1) continue;
            expect(
              shadow.blurSigma,
              closeTo(cssBlur / 2, 1e-6),
              reason: 'level $level, drop ${cssBlur}px',
            );
          }
        }
      });
    }

    test('each level adds one drop; the ring is outside in light mode', () {
      expect(CoilColors.light.shadow(1), hasLength(1));
      expect(CoilColors.light.shadow(8), hasLength(8));
      expect(CoilColors.light.insetRing(5), BorderSide.none);
      expect(CoilColors.dark.shadow(2), hasLength(1));
      expect(CoilColors.dark.shadow(3), hasLength(3));
    });

    test('dark highlight strengthens with the level; light has none', () {
      final alphas = [
        for (var n = 1; n <= 8; n++) CoilColors.dark.topHighlight(n)?.a,
      ];
      expect(alphas.first, isNull);
      final shown = alphas.whereType<double>().toList();
      expect(shown, orderedEquals([...shown]..sort()));
      expect(shown.first, closeTo(0.01, 0.002));
      expect(shown.last, closeTo(0.06, 0.002));
      for (var n = 1; n <= 8; n++) {
        expect(CoilColors.light.topHighlight(n), isNull);
      }
    });
  });

  group('CoilSurface', () {
    Future<int> levelAt(WidgetTester tester, Widget tree) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) =>
              CoilTheme(data: CoilThemeData.light, child: tree),
        ),
      );
      final text = tester.widget<Text>(find.textContaining('level').last);
      return int.parse(text.data!.split(' ').last);
    }

    testWidgets('the page is level 1; a popover is two above, a dialog four', (
      tester,
    ) async {
      expect(
        await levelAt(
          tester,
          _panel(CoilSurface.popoverOffset, const _Level()),
        ),
        3,
      );
      expect(
        await levelAt(tester, _panel(CoilSurface.dialogOffset, const _Level())),
        5,
      );
    });

    testWidgets('a popover inside a dialog is level 7; levels stop at 8', (
      tester,
    ) async {
      final inDialog = _panel(
        CoilSurface.dialogOffset,
        _panel(CoilSurface.popoverOffset, const _Level()),
      );
      expect(await levelAt(tester, inDialog), 7);
      expect(
        await levelAt(tester, _panel(CoilSurface.popoverOffset, inDialog)),
        8,
      );
    });
  });

  group('opened from a dialog', () {
    for (final presentation in CoilPresentation.values) {
      testWidgets('a select ${presentation.name} sits two levels above it', (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        await tester.pumpWidget(
          testApp(
            home: CoilSurface(
              offset: CoilSurface.dialogOffset,
              child: SelectDemo(presentation: presentation),
            ),
          ),
        );
        await tester.tap(find.byType(CoilSelect<String>));
        await tester.pumpAndSettle();

        expect(CoilSurface.levelOf(tester.element(find.text('Apple'))), 7);
      });
    }
  });

  group('painting', () {
    /// The brightness (0..1) of pixel (x, y) of the surface in [key].
    Future<double> brightness(WidgetTester tester, int x, int y) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('surface')),
      );
      final image = (await tester.runAsync(boundary.toImage))!;
      final data = (await tester.runAsync(image.toByteData))!;
      final r = data.getUint8((y * image.width + x) * 4);
      image.dispose();
      return r / 255;
    }

    Future<void> pump(WidgetTester tester, CoilThemeData theme, int offset) {
      return tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => CoilTheme(
            data: theme,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: const ValueKey('surface'),
                  child: SizedBox(
                    width: 120,
                    height: 80,
                    child: _panel(offset, const SizedBox()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('dark: the top edge is lighter than the surface below it', (
      tester,
    ) async {
      await pump(tester, CoilThemeData.dark, 7);
      // The surface fills the boundary; look at its top row and below it.
      final top = await brightness(tester, 60, 0);
      final below = await brightness(tester, 60, 4);
      expect(top, greaterThan(below));
    });

    testWidgets('light: the top edge is not lighter', (tester) async {
      await pump(tester, CoilThemeData.light, 7);
      expect(
        await brightness(tester, 60, 0),
        lessThanOrEqualTo(await brightness(tester, 60, 4)),
      );
    });
  });

  testWidgets('goldens: the surface ladder and a popover over a dialog', (
    tester,
  ) async {
    Widget ladder(CoilThemeData theme) => SheetPanel(
      title: theme.brightness.name,
      theme: theme,
      child: Padding(
        // Room for the tall shadows.
        padding: const EdgeInsets.only(bottom: 130, right: 40),
        child: SizedBox(
          width: 700,
          child: Wrap(
            spacing: 28,
            runSpacing: 28,
            children: [
              for (var level = 1; level <= 8; level++)
                SizedBox(
                  width: 92,
                  height: 72,
                  child: CoilSurface(
                    offset: level - 1,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Text(
                        '$level',
                        style: const CoilTypography().style(
                          CoilMetrics.pointer.body,
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget stack(CoilThemeData theme) => SheetPanel(
      title: 'dialog and popover · ${theme.brightness.name}',
      theme: theme,
      child: SizedBox(
        width: 340,
        height: 260,
        child: CoilSurface(
          offset: CoilSurface.dialogOffset,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const _Level(),
                SizedBox(
                  width: 200,
                  height: 120,
                  child: CoilSurface(
                    offset: CoilSurface.popoverOffset,
                    shadowLevel: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: const Center(child: _Level()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final sheet = await pumpSheet(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ladder(CoilThemeData.light), ladder(CoilThemeData.dark)],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [stack(CoilThemeData.light), stack(CoilThemeData.dark)],
          ),
        ],
      ),
      surface: const Size(1700, 1100),
    );
    await expectSheetGolden(tester, sheet, 'goldens/surface.png');
  });
}

/// What sits on a stage two levels up, or on the page.
Widget _on({required bool stage, required Widget child}) {
  final padded = Padding(padding: const EdgeInsets.all(40), child: child);
  return Align(
    alignment: Alignment.topLeft,
    child: stage
        ? CoilSurface(offset: CoilSurface.popoverOffset, child: padded)
        : padded,
  );
}

void _surfaceScopeTests() {
  const card = CoilCard(title: Text('Deploy preview'));

  Future<Rect> pumpCard(
    WidgetTester tester, {
    required CoilColors colors,
    required bool stage,
  }) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      // A fresh app per pump: the route would keep the first home.
      KeyedSubtree(
        key: ValueKey(stage),
        child: testApp(
          colors: colors,
          home: _on(
            stage: stage,
            child: const SizedBox(width: 240, child: card),
          ),
        ),
      ),
    );
    return tester.getRect(find.byType(CoilCard));
  }

  Future<Color> fillOf(WidgetTester tester, Rect card) => colorAt(
    tester,
    find.byKey(appBoundary),
    card.centerRight - const Offset(6, 0),
  );

  testWidgets('dark: a card on a raised surface is lighter than the surface', (
    tester,
  ) async {
    const colors = CoilColors.dark;
    final onPage = await fillOf(
      tester,
      await pumpCard(tester, colors: colors, stage: false),
    );
    final onStage = await fillOf(
      tester,
      await pumpCard(tester, colors: colors, stage: true),
    );
    // On the page it keeps its look; on surface 3 it is surface 4, not 2.
    expect(isNear(onPage, colors.surface(2), tolerance: 1), isTrue);
    expect(isNear(onStage, colors.surface(4), tolerance: 1), isTrue);
    expect(
      onStage.computeLuminance(),
      greaterThan(colors.surface(3).computeLuminance()),
    );
  });

  testWidgets("light: a card on a raised surface casts its level's shadow", (
    tester,
  ) async {
    const colors = CoilColors.light;
    Future<Color> below({required bool stage}) async {
      final rect = await pumpCard(tester, colors: colors, stage: stage);
      return colorAt(
        tester,
        find.byKey(appBoundary),
        rect.bottomCenter + const Offset(0, 4),
      );
    }

    // Shadow 3 ends within 4 px of the card; shadow 5 still darkens there.
    expect(
      isNear(await below(stage: false), colors.background, tolerance: 1),
      isTrue,
    );
    final stageShadow = await below(stage: true);
    expect(
      stageShadow.computeLuminance(),
      lessThan(colors.surface(3).computeLuminance() - 0.05),
    );
  });

  for (final (name, host) in <(String, Widget Function(Widget))>[
    ('a card', (child) => CoilCard(child: child)),
    (
      'a dialog',
      (child) => CoilSurface(
        offset: CoilSurface.dialogOffset,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  ]) {
    testWidgets('a dropdown opened from $name opens above it, and its list '
        'fades into its surface', (tester) async {
      const colors = CoilColors.dark;
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          colors: colors,
          home: Align(
            alignment: Alignment.topCenter,
            child: host(
              CoilDropdown(
                entries: [
                  for (var i = 0; i < 30; i++)
                    CoilAction(label: Text('Row $i'), onPressed: () {}),
                ],
                builder: (context, menu) => CoilButton(
                  onPressed: menu.open,
                  child: const Text('Actions'),
                ),
              ),
            ),
          ),
        ),
      );
      final hostLevel = CoilSurface.levelOf(
        tester.element(find.text('Actions')),
      );
      expect(hostLevel, greaterThan(1));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();

      final level = CoilSurface.levelOf(tester.element(find.text('Row 0')));
      expect(level, hostLevel + CoilSurface.popoverOffset);
      // The rows scroll, so the bottom edge fades: into the menu's own fill.
      final list = tester.getRect(find.byType(CoilActionList));
      final edge = await colorAt(
        tester,
        find.byKey(appBoundary),
        list.bottomCenter - const Offset(0, 2),
      );
      expect(isNear(edge, colors.surface(level), tolerance: 1), isTrue);
    });
  }
}
