import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/app.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/preview_settings.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone for the touch tier, a desktop window for the pointer tier.
const _sizes = {
  CatalogTier.touch: Size(390, 844),
  CatalogTier.pointer: Size(1280, 800),
};

Future<CatalogSettings> _pumpCatalog(
  WidgetTester tester, {
  required CatalogTier tier,
  CatalogThemeMode themeMode = CatalogThemeMode.light,
}) async {
  tester.view
    ..physicalSize = _sizes[tier]!
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = CatalogSettings()
    ..tier = tier
    ..themeMode = themeMode;
  addTearDown(settings.dispose);
  await tester.pumpWidget(CoilCatalogApp(settings: settings, devTools: false));
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  test('every page has a unique slug and title', () {
    expect(
      catalogEntries.map((e) => e.slug).toSet(),
      hasLength(
        catalogEntries.length,
      ),
    );
    expect(
      catalogEntries.map((e) => e.title).toSet(),
      hasLength(
        catalogEntries.length,
      ),
    );
  });

  for (final tier in [CatalogTier.pointer, CatalogTier.touch]) {
    for (final mode in [CatalogThemeMode.light, CatalogThemeMode.dark]) {
      testWidgets(
        'every page builds without overflow or exceptions '
        '(${tier.name}, ${mode.name})',
        (tester) async {
          await _pumpCatalog(tester, tier: tier, themeMode: mode);
          final router = AutoRouter.of(tester.element(find.byType(HomePage)));
          for (final entry in catalogEntries) {
            unawaited(router.push(NamedRoute(catalogRouteName(entry))));
            // Not pumpAndSettle: the Skeleton pulse loops by design.
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            expect(
              find.descendant(
                of: find.byType(CatalogHeader),
                matching: find.text(entry.title),
              ),
              findsOneWidget,
              reason: '${entry.title} should show its header',
            );
            expect(tester.takeException(), isNull, reason: entry.title);
            unawaited(router.maybePop());
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
          }
        },
      );
    }
  }

  testWidgets('a home row opens its page and Back returns', (tester) async {
    await _pumpCatalog(tester, tier: CatalogTier.touch);
    final row = find.text('Button');
    await tester.scrollUntilVisible(row, 200);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsNothing);
    expect(find.text('Variants'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  test('every component DESIGN.md specifies has a page', () {
    final built = {for (final entry in catalogEntries) entry.title};
    final missing = [
      for (final name in designComponents.values.expand((names) => names))
        if (!built.contains(name)) name,
    ];
    expect(missing, isEmpty);
  });

  testWidgets('the settings dialog changes the page live', (tester) async {
    await _pumpCatalog(tester, tier: CatalogTier.touch);
    final home = tester.element(find.byType(HomePage));
    expect(Directionality.of(home), TextDirection.ltr);
    expect(CoilTheme.of(home).brightness, Brightness.light);

    await tester.tap(find.bySemanticsLabel('Preview settings'));
    await tester.pumpAndSettle();
    // A phone: a select picks the section.
    await tester.tap(find.byType(CoilSelect<PreviewSection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accessibility').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(CoilSettingRow, 'Right to left'),
        matching: find.byType(CoilSwitch),
      ),
    );
    await tester.pumpAndSettle();

    expect(Directionality.of(home), TextDirection.rtl);
    // The sheet itself follows too: it isn't a frozen snapshot.
    expect(
      Directionality.of(tester.element(find.text('Right to left'))),
      TextDirection.rtl,
    );
  });

  testWidgets('on a desktop the sidebar picks the section', (tester) async {
    final settings = await _pumpCatalog(tester, tier: CatalogTier.pointer);
    await tester.tap(find.bySemanticsLabel('Preview settings'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSelect<PreviewSection>), findsNothing);

    await tester.tap(find.text('Device'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(CoilSettingRow, 'Haptics'),
        matching: find.byType(CoilSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.hapticsOff, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pinning a tier resizes controls',
    (tester) async {
      final settings = await _pumpCatalog(tester, tier: CatalogTier.pointer);
      final home = tester.element(find.byType(HomePage));
      expect(CoilTheme.tierOf(home), CoilTier.pointer);

      settings.tier = CatalogTier.touch;
      await tester.pumpAndSettle();
      expect(CoilTheme.tierOf(home), CoilTier.touch);
      expect(CoilTheme.metricsOf(home).controlHeight, 44);
    },
  );

  testWidgets('the theme settings reach every component through the theme', (
    tester,
  ) async {
    final settings = await _pumpCatalog(tester, tier: CatalogTier.pointer);
    final home = tester.element(find.byType(HomePage));

    settings
      ..brand = CatalogBrand.violet
      ..neutralHue = 60
      ..neutralChroma = 0.02
      ..font = CatalogFont.system
      ..shape = CatalogShape.custom
      ..customRadius = 4
      ..spacing = CatalogSpacing.roomy
      ..motion = CatalogMotion.bouncy
      ..boldFocusRing = true
      ..hapticsOff = true;
    await tester.pumpAndSettle();

    final theme = CoilTheme.of(home);
    expect(theme.colors.brand, CatalogBrand.violet.color);
    expect(theme.colors.focusRing, CatalogBrand.violet.color);
    expect(
      theme.colors,
      CoilColors.fromSeed(
        brightness: Brightness.light,
        brand: CatalogBrand.violet.color,
        neutralHue: 60,
        neutralChroma: 0.02,
      ),
    );
    expect(DefaultTextStyle.of(home).style.fontFamily, isNull);
    expect(CoilTheme.radiiOf(home).item, 4);
    expect(CoilTheme.radiiOf(home).container, 8);
    expect(CoilTheme.metricsOf(home).controlHeight, 40);
    expect(theme.motion, CatalogMotion.bouncy.motion);
    expect(theme.focusRingWidth, 2);
    expect(theme.haptics, CoilHaptics.none);
  });

  testWidgets('a custom shape shows a radius slider in the settings', (
    tester,
  ) async {
    final settings = await _pumpCatalog(tester, tier: CatalogTier.touch);
    await tester.tap(find.bySemanticsLabel('Preview settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CoilSelect<PreviewSection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shape and spacing').last);
    await tester.pumpAndSettle();
    expect(find.text('Corner radius'), findsNothing);

    settings.shape = CatalogShape.custom;
    await tester.pumpAndSettle();
    expect(find.text('Corner radius'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a demo stage outlines itself while keyboard focus is inside', (
    tester,
  ) async {
    CoilInputModality.debugReset();
    tester.view
      ..physicalSize = const Size(600, 400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => CoilTheme(
          data: CoilThemeData.light,
          child: FocusScope(
            autofocus: true,
            child: Align(
              alignment: Alignment.topLeft,
              child: DemoStage(
                child: CoilButton(onPressed: () {}, child: const Text('Save')),
              ),
            ),
          ),
        ),
      ),
    );
    Color border() {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DemoStage),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return ((box.decoration as ShapeDecoration).shape
              as RoundedSuperellipseBorder)
          .side
          .color;
    }

    final rest = border();
    expect(rest, CoilThemeData.light.colors.border);

    // A click on the button is pointer input: no outline.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(border(), rest);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(border(), isNot(rest));
  });
}
