import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
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
  testWidgets('next replaces the current chapter instead of pushing', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    unawaited(router.navigate(const NamedRoute('Retarget')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Throw'));
    await tester.pumpAndSettle();
    expect(find.text('Throw it anywhere'), findsOneWidget);
    expect(router.topMostRouter().stackData.map((data) => data.name).toList(), [
      'Motor 2.0',
      'Throw',
    ]);
  });

  testWidgets('home toggles the devtools', (tester) async {
    addTearDown(() => example.devtoolsEnabled.value = true);
    await _pumpApp(tester);
    expect(example.devtoolsEnabled.value, isTrue);
    await tester.tap(find.text('DevTools'));
    await tester.pumpAndSettle();
    expect(example.devtoolsEnabled.value, isFalse);
  });

  testWidgets('a chapter card opens its chapter', (tester) async {
    await _pumpApp(tester);
    await tester.ensureVisible(find.text('Phases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phases'));
    await tester.pumpAndSettle();
    expect(find.text('Autoplay'), findsOneWidget);
  });
}
