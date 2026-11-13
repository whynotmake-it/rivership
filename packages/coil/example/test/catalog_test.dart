import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/app.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/shell/settings.dart';
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
            await tester.pumpAndSettle();
            expect(
              find.text(entry.title),
              findsWidgets,
              reason: '${entry.title} should show its header',
            );
            expect(tester.takeException(), isNull, reason: entry.title);
            unawaited(router.maybePop());
            await tester.pumpAndSettle();
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

  testWidgets('planned components are listed but do not open', (tester) async {
    await _pumpCatalog(tester, tier: CatalogTier.pointer);
    final planned = find.text('Dialog');
    await tester.scrollUntilVisible(planned, 200);
    await tester.tap(planned);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('the settings sheet changes the page live', (tester) async {
    await _pumpCatalog(tester, tier: CatalogTier.touch);
    final home = tester.element(find.byType(HomePage));
    expect(Directionality.of(home), TextDirection.ltr);
    expect(CoilTheme.of(home).brightness, Brightness.light);

    await tester.tap(find.bySemanticsLabel('Preview settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Right to left'));
    await tester.pumpAndSettle();

    expect(Directionality.of(home), TextDirection.rtl);
    // The sheet itself follows too: it isn't a frozen snapshot.
    expect(
      Directionality.of(tester.element(find.text('Right to left'))),
      TextDirection.rtl,
    );
  });

  testWidgets('pinning a tier resizes controls', (tester) async {
    final settings = await _pumpCatalog(tester, tier: CatalogTier.pointer);
    final home = tester.element(find.byType(HomePage));
    expect(CoilTheme.tierOf(home), CoilTier.pointer);

    settings.tier = CatalogTier.touch;
    await tester.pumpAndSettle();
    expect(CoilTheme.tierOf(home), CoilTier.touch);
    expect(CoilTheme.metricsOf(home).controlHeight, 44);
  });
}
