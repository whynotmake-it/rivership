import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/main.dart' as example;

Future<RootStackRouter> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(430, 1800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A fresh router per test; the app's top-level `router` is shared.
  final router = RootStackRouter.build(
    routes: [
      NamedRouteDef.shell(
        name: 'Home',
        path: '/',
        type: const RouteType.cupertino(),
        children: example.motorRoutes,
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
}
