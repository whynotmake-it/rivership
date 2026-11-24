import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/main.dart' as example;

Future<RootStackRouter> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(430, 1800),
  List<AutoRoute>? routes,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A fresh router per test; the app's top-level `router` is shared.
  final router = RootStackRouter.build(
    routes: [
      NamedRouteDef.shell(
        name: 'Home',
        path: '/',
        type: const RouteType.cupertino(),
        children: routes ?? example.motorRoutes,
      ),
    ],
  );
  await tester.pumpWidget(CupertinoApp.router(routerConfig: router.config()));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('the sidebar toggles the devtools, pages replace each other', (
    tester,
  ) async {
    addTearDown(() => example.devtoolsVisible.value = false);
    final semantics = tester.ensureSemantics();
    final router = await _pumpApp(tester);
    List<String> pages() =>
        router.topMostRouter().stackData.map((data) => data.name).toList();

    // On a phone the sidebar is a drawer behind its trigger.
    expect(example.devtoolsVisible.value, isFalse);
    await tester.tap(find.byType(CoilSidebarTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show DevTools'));
    await tester.pumpAndSettle();
    expect(example.devtoolsVisible.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // The link at the end of a demo replaces it with the next one.
    unawaited(router.navigate(const NamedRoute('Toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Next: Retarget')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retarget stage')), findsOneWidget);
    expect(pages(), ['Retarget']);

    // The sidebar's Overview row, then a card on it, each take the place
    // of the page before.
    await tester.tap(find.byType(CoilSidebarTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();
    expect(pages(), ['Motor 2.0']);
    final card = find.bySemanticsLabel(RegExp('^Phases'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(pages(), ['Phases']);
    expect(find.text('Autoplay'), findsOneWidget);
    semantics.dispose();
  });

  // On a phone the page scrolls and the sidebar is a drawer; neither may
  // take a drag that starts on something you can pick up.
  for (final (direction, step) in const [
    ('up', Offset(0, -12)),
    ('sideways', Offset(12, 0)),
  ]) {
    testWidgets('on a phone, a drag $direction moves the card, not the page', (
      tester,
    ) async {
      final router = await _pumpApp(tester, size: const Size(390, 844));
      unawaited(router.navigate(const NamedRoute('Card stack')));
      await tester.pumpAndSettle();
      final card = find.text('1 of 3');
      final lead = find.textContaining('flies clear of the stack');
      final cardAt = tester.getCenter(card);
      final leadAt = tester.getTopLeft(lead);

      final drag = await tester.startGesture(cardAt);
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(step);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // The card followed the finger the whole way.
      expect((tester.getCenter(card) - cardAt).distance, greaterThan(100));
      expect(tester.getTopLeft(lead), leadAt);
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text('Overview').hitTestable(), findsNothing);
    });
  }

  testWidgets('on a phone, a sideways swipe beside the demo opens the drawer', (
    tester,
  ) async {
    final router = await _pumpApp(tester, size: const Size(390, 844));
    unawaited(router.navigate(const NamedRoute('Card stack')));
    await tester.pumpAndSettle();
    expect(find.text('Overview').hitTestable(), findsNothing);

    // The lead above the stage is page, not demo.
    final lead = tester.getTopLeft(
      find.textContaining('flies clear of the stack'),
    );
    final swipe = await tester.startGesture(lead + const Offset(8, 8));
    for (var i = 0; i < 12; i++) {
      await swipe.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await swipe.up();
    await tester.pumpAndSettle();
    expect(find.text('Overview').hitTestable(), findsOneWidget);
  });

  testWidgets('with onHome, the logo leads back to the app around it', (
    tester,
  ) async {
    var home = 0;
    await _pumpApp(
      tester,
      size: const Size(1000, 800),
      routes: example.motorRoutesFor(onHome: () => home++),
    );
    // The sidebar's "Motor", above the overview's title of the same name.
    await tester.tap(find.text('Motor').first);
    await tester.pump();
    expect(home, 1);
  });
}
