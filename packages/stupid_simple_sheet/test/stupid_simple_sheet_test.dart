import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
  setUp(() {
    SnaptestSettings.global = SnaptestSettings.rendered(
      devices: [Devices.ios.iPhone16],
    );
  });

  tearDown(SnaptestSettings.resetGlobal);

  group('showStupidSimpleSheet', () {
    Widget build() {
      return MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return TextButton(
                  key: const ValueKey('button'),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(
                    StupidSimpleCupertinoSheetRoute<void>(
                      child: Scaffold(
                        key: const ValueKey('scaffold'),
                        body: ListView.builder(
                          itemCount: 100,
                          itemBuilder: (context, index) => ListTile(
                            title: Text('Item $index'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Show Stupid Simple Sheet'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('shows', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scaffold')), findsOneWidget);
    });

    testWidgets('can be dragged down', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final extendedTopLeft = tester.getTopLeft(scaffoldFinder);

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      await snap(
        name: 'fully extended',
        matchToGolden: true,
      );

      const dragFrames = 10;
      const dragPx = 30.0;

      for (var i = 0; i < dragFrames; i++) {
        await gesture.moveBy(const Offset(0, dragPx));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // We expect to loose 2 frames. One for the scroll notification, and one
      // for the extra frame we wait before calling the callback.
      const expectedFrames = dragFrames - 2;

      final draggedTopLeft = tester.getTopLeft(scaffoldFinder);

      final expected = extendedTopLeft.dy + expectedFrames * dragPx;

      expect(draggedTopLeft.dy, moreOrLessEquals(expected));

      await snap(name: 'dragged down', matchToGolden: true);

      await gesture.up();
    });

    testWidgets('does not show overscroll indicator', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(build());
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final indicatorFinder = find.byType(GlowingOverscrollIndicator);
      expect(indicatorFinder, findsNothing);

      debugDefaultTargetPlatformOverride = null;

      await gesture.up();
    });
  });
}
