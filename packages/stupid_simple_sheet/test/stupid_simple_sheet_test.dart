import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
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

      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final draggedTopLeft = tester.getTopLeft(scaffoldFinder);

      expect(draggedTopLeft.dy, greaterThan(extendedTopLeft.dy));

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
