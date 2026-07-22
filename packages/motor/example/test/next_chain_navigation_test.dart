import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/main.dart' as example;

void main() {
  testWidgets('next footer replaces the current route instead of pushing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A fresh router per test; the app's top-level `router` is a shared final.
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

    unawaited(router.navigate(const NamedRoute('Instant vs. Animated')));
    await tester.pumpAndSettle();

    final nextLink = find.text('next: The Curve Trap →');
    await tester.scrollUntilVisible(
      nextLink,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(nextLink);
    await tester.pumpAndSettle();
    expect(find.text('700ms curve'), findsOneWidget);

    // Because the footer replaced instead of pushed, the example stack holds
    // exactly one example page over the home grid — not the whole chain.
    expect(router.topMostRouter().stackData.map((data) => data.name).toList(), [
      'Motor 2.0',
      'The Curve Trap',
    ]);
  });
}
