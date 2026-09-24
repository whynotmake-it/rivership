import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/main.dart' as example;

Future<void> _frames(WidgetTester tester, [int count = 30]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<RootStackRouter> _pumpApp(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  await tester.pumpWidget(
    MotorDevTools(child: CupertinoApp.router(routerConfig: router.config())),
  );
  await _frames(tester);
  return router;
}

void main() {
  const sizes = [
    Size(1280, 800),
    Size(800, 600),
    Size(390, 844),
    Size(500, 320),
  ];

  for (final size in sizes) {
    testWidgets('every chapter lays out at $size', (tester) async {
      final router = await _pumpApp(tester, size);
      for (final chapter in chapters) {
        unawaited(router.navigate(NamedRoute(chapter.title)));
        await _frames(tester);
      }
      unawaited(router.navigate(const NamedRoute('Motor 2.0')));
      await _frames(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('every chapter survives resizing the window', (tester) async {
    final router = await _pumpApp(tester, const Size(1280, 800));
    for (final chapter in [null, ...chapters]) {
      unawaited(router.navigate(NamedRoute(chapter?.title ?? 'Motor 2.0')));
      await _frames(tester, 10);
      for (var width = 1280.0; width >= 320; width -= 23) {
        tester.view.physicalSize = Size(width, 800);
        await _frames(tester, 2);
      }
      for (var height = 800.0; height >= 240; height -= 29) {
        tester.view.physicalSize = Size(320, height);
        await _frames(tester, 2);
      }
      tester.view.physicalSize = const Size(1280, 800);
      await _frames(tester, 4);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the now-playing player lays out while it overshoots', (
    tester,
  ) async {
    // Tall enough that the page doesn't scroll, so the drag reaches the
    // player.
    final router = await _pumpApp(tester, const Size(1280, 1400));
    unawaited(router.navigate(const NamedRoute('Phases')));
    await _frames(tester);
    final player = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NowPlaying',
    );
    // A quick drag up from card hands the springs enough speed to shrink
    // the player well below its mini size, and past zero.
    for (final speed in [30.0, 50.0, 80.0]) {
      await tester.tap(find.text('CARD'));
      await _frames(tester, 60);
      final drag = await tester.startGesture(tester.getCenter(player));
      for (var i = 0; i < 5; i++) {
        await drag.moveBy(Offset(0, -speed));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await drag.up();
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 8));
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no page throws in a tiny window', (tester) async {
    final router = await _pumpApp(tester, const Size(1280, 800));
    final errors = <String>[];
    final onError = FlutterError.onError;
    // Pages don't fit a window this small; only overflows are acceptable.
    FlutterError.onError = (details) {
      final error = details.exceptionAsString();
      if (!error.contains('overflowed')) errors.add(error);
    };
    for (final chapter in [null, ...chapters]) {
      unawaited(router.navigate(NamedRoute(chapter?.title ?? 'Motor 2.0')));
      tester.view.physicalSize = const Size(1280, 800);
      await _frames(tester, 10);
      for (final size in const [Size(90, 400), Size(40, 300), Size.zero]) {
        tester.view.physicalSize = size;
        await _frames(tester, 4);
      }
    }
    FlutterError.onError = onError;
    expect(errors, isEmpty);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(const SizedBox());
  });
}
