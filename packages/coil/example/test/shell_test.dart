import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/app.dart';
import 'package:coil_example/src/pages/components/calendar_page.dart';
import 'package:coil_example/src/pages/components/data_table_page.dart';
import 'package:coil_example/src/pages/components/slider_page.dart';
import 'package:coil_example/src/pages/components/tabs_page.dart';
import 'package:coil_example/src/pages/home/bento.dart';
import 'package:coil_example/src/pages/home/tiles.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';
import 'package:coil_example/src/shell/navigation.dart';
import 'package:coil_example/src/shell/phone_frame.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CatalogSettings> _pump(
  WidgetTester tester, {
  required Size size,
  CatalogViewport viewport = CatalogViewport.desktop,
  CatalogThemeMode themeMode = CatalogThemeMode.light,
  CatalogTextScale textScale = CatalogTextScale.x1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = CatalogSettings()
    ..viewport = viewport
    ..themeMode = themeMode
    ..textScale = textScale;
  addTearDown(settings.dispose);
  await tester.pumpWidget(CoilCatalogApp(settings: settings, devTools: false));
  // Let the home page's agent think, reply and send its queue. Not
  // pumpAndSettle: the thinking indicator loops while it waits.
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  return settings;
}

BuildContext _home(WidgetTester tester) =>
    tester.element(find.byType(HomePage));

StackRouter _router(WidgetTester tester) => AutoRouter.of(_home(tester));

Finder _sidebarItem(String title) => find.descendant(
  of: find.byType(CoilSidebar),
  matching: find.text(title),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  const widths = [320.0, 375.0, 600.0, 768.0, 1024.0, 1440.0, 2560.0];

  for (final scale in [CatalogTextScale.x1, CatalogTextScale.x2]) {
    for (final width in widths) {
      final mode = width == 1440
          ? CatalogThemeMode.dark
          : CatalogThemeMode.light;
      testWidgets('the home page lays out at $width px, '
          'text ${scale.label}, ${mode.name}', (tester) async {
        await _pump(
          tester,
          size: Size(width, 900),
          textScale: scale,
          themeMode: mode,
        );
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(BentoTile), findsNWidgets(homeTiles.length));
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('the home page lays out in the iPhone frame, '
        'text ${scale.label}', (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        viewport: CatalogViewport.mobile,
        textScale: scale,
      );
      expect(find.byType(PhoneFrame), findsOneWidget);
      expect(find.byType(BentoTile), findsNWidgets(homeTiles.length));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the toggle frames the catalog as a phone on the touch tier', (
    tester,
  ) async {
    final settings = await _pump(tester, size: const Size(1440, 900));
    expect(find.byType(PhoneFrame), findsNothing);
    expect(CoilTheme.tierOf(_home(tester)), CoilTier.pointer);
    final agent = tester.state(find.byType(AgentTile));

    await tester.tap(find.text('Mobile').first);
    await _settle(tester);

    expect(find.byType(PhoneFrame), findsOneWidget);
    final home = _home(tester);
    expect(CoilTheme.tierOf(home), CoilTier.touch);
    expect(CoilTheme.platformOf(home), TargetPlatform.iOS);
    expect(MediaQuery.sizeOf(home), CatalogDevice.iPhone.screenSize);
    expect(MediaQuery.paddingOf(home), CatalogDevice.iPhone.safeArea);
    // The pages moved into the frame without losing their state.
    expect(tester.state(find.byType(AgentTile)), same(agent));
    // On a phone the sidebar is the drawer, hidden behind the page.
    expect(_sidebarItem('Button').hitTestable(), findsNothing);
    expect(
      find.text('iPhone 16 Pro · iOS · touch tier · 402 × 874'),
      findsOneWidget,
    );

    settings.device = CatalogDevice.pixel;
    await _settle(tester);
    expect(CoilTheme.platformOf(_home(tester)), TargetPlatform.android);
    expect(
      MediaQuery.sizeOf(_home(tester)),
      CatalogDevice.pixel.screenSize,
    );

    await tester.tap(find.bySemanticsLabel('Rotate device'));
    await _settle(tester);
    expect(settings.orientation, Orientation.landscape);
    final landscape = MediaQuery.sizeOf(_home(tester));
    expect(landscape, CatalogDevice.pixel.screenSize.flipped);
    expect(
      MediaQuery.paddingOf(_home(tester)),
      CatalogDevice.pixel.landscapeSafeArea,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Desktop').first);
    await _settle(tester);
    expect(find.byType(PhoneFrame), findsNothing);
    expect(CoilTheme.tierOf(_home(tester)), CoilTier.pointer);
    expect(CoilTheme.platformOf(_home(tester)), defaultTargetPlatform);
    expect(tester.state(find.byType(AgentTile)), same(agent));
  });

  testWidgets('the device picker frames an iPad', (tester) async {
    final settings = await _pump(
      tester,
      size: const Size(1440, 900),
      viewport: CatalogViewport.mobile,
    );
    await tester.tap(find.byType(CoilSelect<CatalogDevice>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('iPad Air').last);
    await _settle(tester);
    expect(settings.device, CatalogDevice.iPad);
    expect(MediaQuery.sizeOf(_home(tester)), CatalogDevice.iPad.screenSize);
    // A tablet is wide enough for the sidebar beside the page.
    expect(_sidebarItem('Button').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The frame's screen sets its own scroll behavior (any pointer drags),
  // which coil's drawer and sheets have to hand drags through.
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('drags and flings in the frame end cleanly (${kind.name})', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        viewport: CatalogViewport.mobile,
      );
      final home = find.byType(HomePage);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: home, matching: find.byType(Scrollable)).first,
      );

      // Scroll the page by dragging and by flinging, ending on the screen.
      await tester.drag(home, const Offset(0, -200), kind: kind);
      await tester.pumpAndSettle();
      final scrolled = scrollable.position.pixels;
      expect(scrolled, greaterThan(0));
      // From the top of the screen, clear of the tiles' own scrollers.
      await tester.flingFrom(
        tester.getTopLeft(home) + const Offset(150, 140),
        const Offset(0, 400),
        1500,
        deviceKind: kind,
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, lessThan(scrolled));

      // Open the drawer by dragging the page, close it by dragging back.
      final center = tester.getCenter(home);
      await tester.dragFrom(center, const Offset(260, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(_sidebarItem('Button').hitTestable(), findsOneWidget);
      await tester.dragFrom(
        tester.getCenter(find.byType(PhoneFrame)) + const Offset(120, 0),
        const Offset(-260, 0),
        kind: kind,
      );
      await tester.pumpAndSettle();
      expect(_sidebarItem('Button').hitTestable(), findsNothing);

      // A sheet in the frame: the date and time picker. Drag and fling in
      // it, then drag it away.
      final picker = find.byType(CoilDatePicker);
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      final sheet = find.byType(CoilCalendar).last;
      expect(sheet, findsOneWidget);
      await tester.drag(sheet, const Offset(-200, 0), kind: kind);
      await tester.pumpAndSettle();
      await tester.fling(sheet, const Offset(0, -200), 1200, deviceKind: kind);
      await tester.pumpAndSettle();
      await tester.fling(sheet, const Offset(0, 500), 2000, deviceKind: kind);
      await tester.pumpAndSettle();
      expect(find.byType(CoilCalendar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  /// The [CoilBlurFade] a page's header sits in, while its route moves.
  CoilBlurFade pageTransition(WidgetTester tester, String title) =>
      tester.widget<CoilBlurFade>(
        find
            .ancestor(
              of: find.descendant(
                of: find.byType(CatalogHeader),
                matching: find.text(title),
              ),
              matching: find.byType(CoilBlurFade),
            )
            .first,
      );

  for (final reduced in [false, true]) {
    testWidgets('pages blur-fade in place, without sliding'
        '${reduced ? ', only fading under reduced motion' : ''}', (
      tester,
    ) async {
      final settings = await _pump(tester, size: const Size(1440, 900));
      settings.reducedMotion = reduced;
      await tester.pump();
      final item = _sidebarItem('Slider');
      await tester.tap(item);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Midway: half there, at its final place.
      final header = find.descendant(
        of: find.byType(CatalogHeader),
        matching: find.text('Slider'),
      );
      final transition = pageTransition(tester, 'Slider');
      expect(transition.presence.value, inExclusiveRange(0, 1));
      final midway = tester.getTopLeft(header);
      final blur = tester.widget<ImageFiltered>(
        find
            .descendant(
              of: find.byWidget(transition),
              matching: find.byType(ImageFiltered),
            )
            .first,
      );
      expect(blur.enabled, !reduced);
      expect(
        ModalRoute.of(tester.element(header))!.transitionDuration,
        const Duration(milliseconds: 180),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(pageTransition(tester, 'Slider').presence.value, 1);
      expect(tester.getTopLeft(header), midway);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('in the iPhone frame a drag opens the drawer on any page', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(1440, 900),
      viewport: CatalogViewport.mobile,
    );
    unawaited(openCatalogPage(_router(tester), sliderEntry));
    await tester.pumpAndSettle();
    final page = find.byType(CatalogHeader).last;
    expect(find.text('Slider'), findsWidgets);

    await tester.dragFrom(
      tester.getCenter(find.byType(PhoneFrame)),
      const Offset(260, 0),
    );
    await tester.pumpAndSettle();
    expect(_sidebarItem('Button').hitTestable(), findsOneWidget);
    expect(page, findsOneWidget);
  });

  testWidgets('a narrow window shows the catalog full screen on touch', (
    tester,
  ) async {
    final settings = await _pump(
      tester,
      size: const Size(390, 844),
      viewport: CatalogViewport.mobile,
    );
    expect(find.byType(CatalogTopBar), findsNothing);
    expect(find.byType(PhoneFrame), findsNothing);
    expect(CoilTheme.tierOf(_home(tester)), CoilTier.touch);
    expect(settings.viewport, CatalogViewport.mobile);
    // Without the top bar, the page header has the settings.
    expect(find.bySemanticsLabel('Preview settings'), findsOneWidget);
  });

  testWidgets('the sidebar reaches every page and home', (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    for (final entry in catalogEntries) {
      final item = _sidebarItem(entry.title);
      await tester.ensureVisible(item);
      await tester.pump();
      await tester.tap(item);
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(CatalogHeader),
          matching: find.text(entry.title),
        ),
        findsOneWidget,
        reason: entry.title,
      );
      expect(currentCatalogEntry(_routerOf(tester)), entry);
      expect(tester.takeException(), isNull, reason: entry.title);
    }
    // Pages replace each other: home is always one step back.
    expect(_routerOf(tester).stackData, hasLength(2));

    final home = _sidebarItem('Home');
    await tester.ensureVisible(home);
    await tester.tap(home);
    await _settle(tester);
    expect(find.byType(HomePage).hitTestable(), findsOneWidget);
  });

  testWidgets('on a phone the drawer opens a page and back returns home', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844));
    await tester.tap(find.bySemanticsLabel('Expand sidebar'));
    await _settle(tester);
    final item = _sidebarItem('Slider');
    await tester.ensureVisible(item);
    await tester.pump();
    await tester.tap(item);
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(CatalogHeader),
        matching: find.text('Slider'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.byType(HomePage).hitTestable(), findsOneWidget);
  });

  testWidgets('a tile links to the components it is built from', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1440, 900));
    final link = find.descendant(
      of: find.byType(BentoTile),
      matching: find.text('DataTable'),
    );
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(link);
    await _settle(tester);
    expect(currentCatalogEntry(_routerOf(tester)), dataTableEntry);
  });

  testWidgets('search jumps to a page from the keyboard', (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final modifier = apple
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Calendar');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(currentCatalogEntry(_routerOf(tester)), calendarEntry);
  });

  testWidgets('a deep link to a page gets home below it', (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    final router = _router(tester);
    unawaited(
      router.replaceAll([NamedRoute(catalogRouteName(tabsEntry))]),
    );
    await _settle(tester);
    expect(router.stackData, hasLength(1));

    unawaited(openCatalogPage(router, sliderEntry));
    await _settle(tester);
    expect(
      router.stackData.map((r) => r.name),
      ['coil:home', catalogRouteName(sliderEntry)],
    );
  });
}

/// The catalog's router, found from whatever page is showing.
StackRouter _routerOf(WidgetTester tester) =>
    AutoRouter.of(tester.element(find.byType(CatalogHeader).last));
