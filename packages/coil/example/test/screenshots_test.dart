// Screenshots of the catalog for reviews, written to `.snaptest/`.
// Off by default; run with:
//   flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=true
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil_example/src/app.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  final devices = {
    'phone': (Devices.ios.iPhone16Pro, CatalogTier.touch),
    'desktop': (Devices.macOS.macBookPro, CatalogTier.pointer),
  };
  final pages = [null, 'button', 'select', 'tabs'];

  for (final MapEntry(key: name, value: (device, tier)) in devices.entries) {
    for (final mode in [CatalogThemeMode.light, CatalogThemeMode.dark]) {
      testWidgets('catalog $name ${mode.name}', skip: !_enabled, (
        tester,
      ) async {
        final settings = CatalogSettings()
          ..tier = tier
          ..themeMode = mode;
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          CoilCatalogApp(settings: settings, devTools: false),
        );
        await tester.pumpAndSettle();
        final router = AutoRouter.of(tester.element(find.byType(HomePage)));
        for (final slug in pages) {
          if (slug != null) {
            final entry = catalogEntries.firstWhere((e) => e.slug == slug);
            unawaited(router.push(NamedRoute(catalogRouteName(entry))));
            await tester.pumpAndSettle();
          }
          await snap(
            name: '${name}_${mode.name}_${slug ?? 'home'}',
            device: device,
          );
          if (slug != null) {
            unawaited(router.maybePop());
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}
