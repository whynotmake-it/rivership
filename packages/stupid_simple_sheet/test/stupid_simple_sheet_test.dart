// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
  setUp(() {
    SnaptestSettings.global = const SnaptestSettings.rendered();
  });

  tearDown(SnaptestSettings.resetGlobal);

  group('StupidSimpleSheetRoute', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget build({
      Motion motion = motion,
      bool onlyDragWhenScrollWasAtTop = true,
      bool draggable = true,
      bool originateAboveBottomViewInset = false,
    }) {
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
                    StupidSimpleSheetRoute<void>(
                      motion: motion,
                      onlyDragWhenScrollWasAtTop: onlyDragWhenScrollWasAtTop,
                      draggable: draggable,
                      originateAboveBottomViewInset:
                          originateAboveBottomViewInset,
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

      await snap.golden(
        name: 'fully extended',
        device: Devices.ios.iPhone16,
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

      await snap.golden(
        name: 'dragged down',
        device: Devices.ios.iPhone16,
      );

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

      await gesture.up();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('only drags when started at top', (tester) async {
      await tester.pumpWidget(build(onlyDragWhenScrollWasAtTop: true));
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final initialTopLeft = tester.getTopLeft(scaffoldFinder);

      // First scroll down to move away from the top
      await tester.timedDragFrom(
        tester.getCenter(scaffoldFinder),
        const Offset(0, -50),
        const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final finalTopLeft = tester.getTopLeft(scaffoldFinder);

      await snap(device: Devices.ios.iPhone16);

      // Sheet should not have moved down (should be overscrolling instead)
      expect(finalTopLeft.dy, equals(initialTopLeft.dy));
      expect(find.byType(GlowingOverscrollIndicator), findsOneWidget);
    });

    testWidgets('drags from anywhere if onlyDragWhenScrollWasAtTop is false',
        (tester) async {
      await tester.pumpWidget(build(onlyDragWhenScrollWasAtTop: false));
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final initialTopLeft = tester.getTopLeft(scaffoldFinder);

      // First scroll down to move away from the top
      await tester.timedDragFrom(
        tester.getCenter(scaffoldFinder),
        const Offset(0, -100),
        const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      // Now scroll up/drag the sheet downwards
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final finalTopLeft = tester.getTopLeft(scaffoldFinder);

      // Sheet has moved down
      expect(finalTopLeft.dy, greaterThan(initialTopLeft.dy));
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    });

    group('page behind becomes interactable quickly', () {
      testWidgets('when popping', (tester) async {
        final buttonFinder = find.byKey(const ValueKey('button'));
        final widget = build();
        await tester.pumpWidget(widget);
        await tester.tap(buttonFinder);

        await tester.pumpAndSettle();
        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        expect(buttonFinder.hitTestable(), findsNothing);

        Navigator.of(tester.element(scaffoldFinder)).pop();

        await tester.pump();
        expect(buttonFinder.hitTestable(), findsOneWidget);
      });
    });

    testWidgets('cannot be dragged when draggable is false', (tester) async {
      await tester.pumpWidget(build(draggable: false));
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final initialTopLeft = tester.getTopLeft(scaffoldFinder);

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      const dragFrames = 10;
      const dragPx = 30.0;
      const expectedDragDelta = dragFrames * dragPx;

      for (var i = 0; i < dragFrames; i++) {
        await gesture.moveBy(const Offset(0, dragPx));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final draggedTopLeft = tester.getTopLeft(scaffoldFinder);
      final dragDelta = draggedTopLeft.dy - initialTopLeft.dy;

      // We have moved less than 20% of the expected drag distance because we're
      // sticking to the top.
      expect(dragDelta, lessThan(expectedDragDelta * .2));

      await gesture.up();
    });

    testWidgets('does not bounce when dragged at the top', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final initialTopLeft = tester.getTopLeft(scaffoldFinder);

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      const dragFrames = 5;
      const dragDownPx = 20.0;
      const dragUpPx = -40.0;

      // Drag downwards
      for (var i = 0; i < dragFrames; i++) {
        await gesture.moveBy(const Offset(0, dragDownPx));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // And upwards but with some extra distance
      for (var i = 0; i < dragFrames; i++) {
        await gesture.moveBy(const Offset(0, dragUpPx));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final draggedTopLeft = tester.getTopLeft(scaffoldFinder);

      // We did not overshoot
      expect(draggedTopLeft, equals(initialTopLeft));

      // and we have started scrolling
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(
          of: scaffoldFinder,
          matching: find.byType(Scrollable),
        ),
      );

      expect(scrollableState.position.pixels, greaterThan(0.0));

      await gesture.up();
    });

    testWidgets('can be closed properly while dragging', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      const dragFrames = 10;
      const dragPx = 30.0;

      for (var i = 0; i < dragFrames; i++) {
        await gesture.moveBy(const Offset(0, dragPx));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Now close while dragging
      Navigator.of(tester.element(scaffoldFinder)).pop();

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scaffold')), findsNothing);

      await gesture.up();
    });

    group('originateAboveBottomViewInset', () {
      const keyboardHeight = 300.0;

      void openKeyboard(WidgetTester tester) {
        tester.view.viewInsets = FakeViewPadding(
          bottom: keyboardHeight * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.reset);
      }

      testWidgets('sheet moves up by bottom view inset', (tester) async {
        addTearDown(tester.view.reset);

        await tester.pumpWidget(build(originateAboveBottomViewInset: true));
        // Show the sheet without keyboard
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final bottomLeft = tester.getBottomLeft(scaffoldFinder);

        // Close the sheet
        Navigator.of(tester.element(scaffoldFinder)).pop();
        await tester.pumpAndSettle();

        // Simulate keyboard appearing
        openKeyboard(tester);

        // Show the sheet with keyboard
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final withKeyboardBottomLeft = tester.getBottomLeft(scaffoldFinder);

        // The sheet should have moved up by the keyboard height
        expect(
          withKeyboardBottomLeft.dy,
          equals(bottomLeft.dy - keyboardHeight),
        );
      });

      testWidgets(
        'viewInsets inside the sheet are unchaged by default',
        (tester) async {
          // Simulate keyboard appearing
          openKeyboard(tester);

          await tester.pumpWidget(build());
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final element = tester.element(
            find.byKey(const ValueKey('scaffold')),
          );

          final insets = MediaQuery.viewInsetsOf(element);

          // The insets should reflect the keyboard height
          expect(insets.bottom, equals(keyboardHeight));
        },
      );

      testWidgets(
        'viewInsets inside the sheet is 0 when keyboard is opened',
        (tester) async {
          // Simulate keyboard appearing
          openKeyboard(tester);

          await tester.pumpWidget(build(originateAboveBottomViewInset: true));
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final element = tester.element(
            find.byKey(const ValueKey('scaffold')),
          );

          final insets = MediaQuery.viewInsetsOf(element);

          // The insets should be zero because they are removed
          expect(insets.bottom, equals(0.0));
        },
      );
    });
  });

  group('resistance when route cannot pop', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget build({
      SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
    }) {
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
                    StupidSimpleSheetRoute<void>(
                      motion: motion,
                      snappingConfig: snappingConfig,
                      child: const PopScope(
                        canPop: false,
                        child: Scaffold(
                          key: ValueKey('scaffold'),
                          body: Center(child: Text('Sheet Content')),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Show Sheet'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets(
      'applies resistance when dragged below min snap point',
      (tester) async {
        await tester.pumpWidget(build());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));

        final topLeft = tester.getTopLeft(scaffoldFinder);

        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        const dragFrames = 10;
        const dragPx = 30.0;
        const expectedDelta = dragFrames * dragPx;

        for (var i = 0; i < dragFrames; i++) {
          await gesture.moveBy(const Offset(0, dragPx));
          await tester.pump(const Duration(milliseconds: 16));
        }

        final delta = tester.getTopLeft(scaffoldFinder).dy - topLeft.dy;

        // The value should have moved less than 30% of what it would
        // without resistance.
        expect(delta, lessThan(expectedDelta * 0.3));

        await gesture.up();
      },
    );

    testWidgets(
      'snaps back to min snap point after drag release',
      (tester) async {
        await tester.pumpWidget(build());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final topLeft = tester.getTopLeft(scaffoldFinder);
        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(tester.getTopLeft(scaffoldFinder).dy, greaterThan(topLeft.dy));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(scaffoldFinder), topLeft);
      },
    );

    testWidgets(
      'applies resistance with multi-snap config',
      (tester) async {
        await tester.pumpWidget(
          build(
            snappingConfig: const SheetSnappingConfig(
              [0.5, 1.0],
              initialSnap: 0.5,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final route = ModalRoute.of(tester.element(scaffoldFinder))!
            as StupidSimpleSheetRoute;
        // ignore: invalid_use_of_protected_member
        final controller = route.controller!;

        // Sheet should start at 0.5
        expect(controller.value, equals(0.5));

        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        // Drag downward significantly
        for (var i = 0; i < 15; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        // Should have moved very little below 0.5 due to resistance
        final valueDelta = 0.5 - controller.value;
        expect(valueDelta, lessThan(0.1));

        await gesture.up();
        await tester.pumpAndSettle();

        // Should snap back to 0.5 (the min snap point)
        expect(controller.value, closeTo(0.5, 0.01));
      },
    );

    testWidgets(
      'does not apply resistance when dragging between snap points',
      (tester) async {
        await tester.pumpWidget(
          build(
            snappingConfig: const SheetSnappingConfig(
              [0.5, 1.0],
              initialSnap: 1,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final route = ModalRoute.of(tester.element(scaffoldFinder))!
            as StupidSimpleSheetRoute;
        // ignore: invalid_use_of_protected_member
        final controller = route.controller!;

        expect(controller.value, equals(1.0));

        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        // Drag down a moderate amount (should move freely between 1.0 and 0.5)
        // We lose 2 frames to scroll detection, so use more frames.
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        // Should have moved significantly (no resistance between snap points)
        final valueDelta = 1.0 - controller.value;
        expect(valueDelta, greaterThan(0.1));

        // And the sheet should still be above 0.5 (min snap) since we
        // are just verifying free movement, not that it passes through.
        expect(controller.value, lessThan(1.0));

        await gesture.up();
      },
    );
  });

  group('DismissalMode', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget buildWithDismissalMode({
      DismissalMode dismissalMode = DismissalMode.slide,
      Widget? sheetChild,
      bool draggable = true,
      bool onlyDragWhenScrollWasAtTop = true,
      SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
    }) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return TextButton(
                  key: const ValueKey('button'),
                  onPressed: () => Navigator.of(context).push(
                    StupidSimpleSheetRoute<void>(
                      motion: motion,
                      dismissalMode: dismissalMode,
                      draggable: draggable,
                      snappingConfig: snappingConfig,
                      onlyDragWhenScrollWasAtTop: onlyDragWhenScrollWasAtTop,
                      child: sheetChild ??
                          const ColoredBox(
                            key: ValueKey('sheet'),
                            color: Color(0xFF2196F3),
                            child: SizedBox(
                              height: 300,
                              child: Center(
                                child: Text('Sheet Content'),
                              ),
                            ),
                          ),
                    ),
                  ),
                  child: const Text('Show Sheet'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('shrink mode opens and displays content', (tester) async {
      await tester.pumpWidget(
        buildWithDismissalMode(dismissalMode: DismissalMode.shrink),
      );
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();

      expect(find.text('Sheet Content'), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    });

    testWidgets(
      'shrink mode sizes down a child shorter than the route',
      (tester) async {
        // Use a large screen so that 0.5 * screenHeight > childMax.
        // Default test env is 800x600 which is too small; use a
        // phone-sized surface instead.
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const childKey = ValueKey('modal-child');

        await tester.pumpWidget(
          buildWithDismissalMode(
            dismissalMode: DismissalMode.shrink,
            snappingConfig: const SheetSnappingConfig(
              [0.5, 1],
              initialSnap: 0.5,
            ),
            sheetChild: Container(
              key: childKey,
              constraints: const BoxConstraints(
                minHeight: 50,
                maxHeight: 400,
              ),
              color: const Color(0xFF2196F3),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        // At 0.5 extent on a 2532px screen the target height is
        // ~1266px — well above the child's 400px max. Without the
        // fix the child stays at 400px because the shrink window
        // is still larger than it.
        final childHeight = tester.getSize(find.byKey(childKey)).height;
        expect(
          childHeight,
          lessThan(400),
          reason: 'At 0.5 extent the child should have shrunk '
              'below its natural 400px. Got $childHeight.',
        );
      },
    );

    testWidgets('slide mode opens and displays content', (tester) async {
      await tester.pumpWidget(
        buildWithDismissalMode(dismissalMode: DismissalMode.slide),
      );
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();

      expect(find.text('Sheet Content'), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    });

    testWidgets('shrink mode can be dragged down', (tester) async {
      await tester.pumpWidget(
        buildWithDismissalMode(
          dismissalMode: DismissalMode.shrink,
          sheetChild: Scaffold(
            key: const ValueKey('scaffold'),
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Item $index')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();

      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final route = ModalRoute.of(tester.element(scaffoldFinder))!;

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The animation value should have decreased from dragging down
      expect(route.animation!.value, lessThan(1.0));

      await gesture.up();
    });

    testWidgets('shrink mode can be popped programmatically', (tester) async {
      await tester.pumpWidget(
        buildWithDismissalMode(
          dismissalMode: DismissalMode.shrink,
          sheetChild: const Scaffold(
            key: ValueKey('scaffold'),
            body: Center(child: Text('Sheet Content')),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();

      expect(find.text('Sheet Content'), findsOneWidget);

      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      Navigator.of(tester.element(scaffoldFinder)).pop();
      await tester.pumpAndSettle();

      expect(find.text('Sheet Content'), findsNothing);
    });

    testWidgets(
      'shrink mode: page behind becomes interactable quickly when popping',
      (tester) async {
        final buttonFinder = find.byKey(const ValueKey('button'));
        await tester.pumpWidget(
          buildWithDismissalMode(
            dismissalMode: DismissalMode.shrink,
            sheetChild: const Scaffold(
              key: ValueKey('scaffold'),
              body: Center(child: Text('Sheet Content')),
            ),
          ),
        );
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        expect(buttonFinder.hitTestable(), findsNothing);

        Navigator.of(tester.element(scaffoldFinder)).pop();

        await tester.pump();
        expect(buttonFinder.hitTestable(), findsOneWidget);
      },
    );

    testWidgets('shrink mode can be closed while dragging', (tester) async {
      await tester.pumpWidget(
        buildWithDismissalMode(
          dismissalMode: DismissalMode.shrink,
          sheetChild: Scaffold(
            key: const ValueKey('scaffold'),
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Item $index')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();

      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Close while dragging
      Navigator.of(tester.element(scaffoldFinder)).pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scaffold')), findsNothing);

      await gesture.up();
    });

    testWidgets('shrink mode does not bounce when dragged at top',
        (tester) async {
      await tester.pumpWidget(
        buildWithDismissalMode(
          dismissalMode: DismissalMode.shrink,
          sheetChild: Scaffold(
            key: const ValueKey('scaffold'),
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Item $index')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();

      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final route = ModalRoute.of(tester.element(scaffoldFinder))!;

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      // Drag down then back up with extra distance
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Should not overshoot past fully open
      expect(route.animation!.value, lessThanOrEqualTo(1.0));

      // and we have started scrolling
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(
          of: scaffoldFinder,
          matching: find.byType(Scrollable),
        ),
      );

      expect(scrollableState.position.pixels, greaterThan(0.0));

      await gesture.up();
    });

    testWidgets(
      'shrink mode cannot be dragged when draggable is false',
      (tester) async {
        await tester.pumpWidget(
          buildWithDismissalMode(
            dismissalMode: DismissalMode.shrink,
            draggable: false,
            sheetChild: Scaffold(
              key: const ValueKey('scaffold'),
              body: ListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) =>
                    ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final route = ModalRoute.of(tester.element(scaffoldFinder))!;
        final initialValue = route.animation!.value;

        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        final delta = initialValue - route.animation!.value;

        // Should barely have moved (resistance applied)
        expect(delta, lessThan(initialValue * 0.2));

        await gesture.up();
      },
    );
  });

  group('StupidSimpleCupertinoSheetRoute', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget build({
      Motion motion = motion,
      bool clearBarrierImmediately = true,
      SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
      bool draggable = true,
      ShapeBorder? shape,
      Widget? child,
    }) {
      return CupertinoApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return CupertinoButton.filled(
                  key: const ValueKey('button'),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(
                    StupidSimpleCupertinoSheetRoute<void>(
                      clearBarrierImmediately: clearBarrierImmediately,
                      motion: motion,
                      snappingConfig: snappingConfig,
                      draggable: draggable,
                      shape:
                          shape ?? StupidSimpleCupertinoSheetRoute.iOS18Shape,
                      child: child ??
                          Scaffold(
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

    group('route behind becomes interactable quickly', () {
      testWidgets('when popping', (tester) async {
        final buttonFinder = find.byKey(const ValueKey('button'));
        final widget = build();
        await tester.pumpWidget(widget);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();
        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        expect(buttonFinder.hitTestable(), findsNothing);

        Navigator.of(tester.element(scaffoldFinder)).pop();

        // Allow the sheet to clear the button enough, it should become
        // hit testable even though the sheet is still animating down.
        await tester.pumpFrames(build(), const Duration(milliseconds: 120));

        expect(buttonFinder.hitTestable(), findsOneWidget);
      });

      testWidgets('when swiping', (tester) async {
        final buttonFinder = find.byKey(const ValueKey('button'));
        final widget = build();
        await tester.pumpWidget(widget);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();
        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        expect(buttonFinder.hitTestable(), findsNothing);

        await tester.timedDragFrom(
          tester.getTopLeft(scaffoldFinder),
          Offset(0, tester.getSize(scaffoldFinder).height * .6),
          const Duration(milliseconds: 300),
        );

        await tester.pump(motion.duration);

        await snap(device: Devices.ios.iPhone16);

        expect(buttonFinder.hitTestable(), findsOneWidget);
        expect(find.byType(ModalBarrier).hitTestable(), findsNothing);
      });

      testWidgets('unless clearBarrierImmediately is false', (tester) async {
        final buttonFinder = find.byKey(const ValueKey('button'));
        final widget = build(clearBarrierImmediately: false);
        await tester.pumpWidget(widget);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();
        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        expect(buttonFinder.hitTestable(), findsNothing);

        await tester.timedDragFrom(
          tester.getTopLeft(scaffoldFinder),
          Offset(0, tester.getSize(scaffoldFinder).height * .6),
          const Duration(milliseconds: 300),
        );

        await tester.pump(motion.duration);

        expect(buttonFinder.hitTestable(), findsNothing);
        expect(find.byType(ModalBarrier).hitTestable(), findsOneWidget);
      });
    });

    group('snap and scroll', () {
      testWidgets(
        'sheet with only [0.5] snap settles at .5 when dragged up',
        (tester) async {
          await tester.pumpWidget(
            build(
              snappingConfig: const SheetSnappingConfig([0.5]),
              child: Container(
                key: const ValueKey('sheet-content'),
                height: 200,
                color: Colors.blue,
              ),
            ),
          );

          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final contentFinder = find.byKey(const ValueKey('sheet-content'));
          final route = ModalRoute.of(tester.element(contentFinder))!
              as StupidSimpleCupertinoSheetRoute;

          // Sheet should be at 0.5 (the initial snap)
          expect(route.animation!.value, equals(0.5));

          final gesture =
              await tester.startGesture(tester.getCenter(contentFinder));
          for (var i = 0; i < 20; i++) {
            await gesture.moveBy(const Offset(0, -30));
            await tester.pump(const Duration(milliseconds: 16));
          }

          expect(route.animation!.value, greaterThan(0.5));

          await gesture.up();
          await tester.pumpAndSettle();

          // The sheet must not settle at 1.0 — it should snap back to 0.5
          // since that is the only defined snap point.
          // ignore: invalid_use_of_protected_member
          final settledValue = route.controller!.value;
          expect(
            settledValue,
            closeTo(0.5, 0.01),
            reason: 'Sheet should snap back to 0.5 (the only defined snap '
                'point), not 1.0. Settled at $settledValue.',
          );
        },
      );
      testWidgets(
        'snapping sheet snaps back to 1.0 when dragged up past 1.0',
        (tester) async {
          await tester.pumpWidget(
            build(
              snappingConfig: const SheetSnappingConfig(
                [0.5, 1.0],
                initialSnap: 1,
              ),
              child: Container(
                key: const ValueKey('sheet-content'),
                height: 200,
                color: Colors.blue,
              ),
            ),
          );

          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final contentFinder = find.byKey(const ValueKey('sheet-content'));
          final route = ModalRoute.of(tester.element(contentFinder))!
              as StupidSimpleCupertinoSheetRoute;
          // ignore: invalid_use_of_protected_member
          final controller = route.controller!;

          expect(route.animation!.value, equals(1));

          await tester.fling(
            contentFinder,
            const Offset(0, -800),
            10000,
          );
          expect(controller.value, greaterThan(1));

          await tester.pumpAndSettle();

          final settledValue = controller.value;
          expect(settledValue, equals(1));
        },
      );
      testWidgets(
        'overshoot resistance is the same whether sheet opened at max or '
        'was dragged there from a lower snap',
        (tester) async {
          // Helper: measure overshoot after a fling at a sheet
          // that is already at 1.0.
          Future<double> measureOvershoot({
            required double initialSnap,
          }) async {
            await tester.pumpWidget(
              build(
                snappingConfig: SheetSnappingConfig(
                  const [0.5, 1.0],
                  initialSnap: initialSnap,
                ),
                child: Container(
                  key: const ValueKey('sheet-content'),
                  height: 200,
                  color: Colors.blue,
                ),
              ),
            );

            await tester.tap(find.byKey(const ValueKey('button')));
            await tester.pumpAndSettle();

            final contentFinder = find.byKey(const ValueKey('sheet-content'));
            final route = ModalRoute.of(tester.element(contentFinder))!
                as StupidSimpleCupertinoSheetRoute;
            // ignore: invalid_use_of_protected_member
            final controller = route.controller!;

            if (initialSnap < 1.0) {
              // Drag from 0.5 up to ~1.0 and let it settle there
              final gesture =
                  await tester.startGesture(tester.getCenter(contentFinder));
              for (var i = 0; i < 20; i++) {
                await gesture.moveBy(const Offset(0, -30));
                await tester.pump(const Duration(milliseconds: 16));
              }
              await gesture.up();
              await tester.pumpAndSettle();

              expect(
                controller.value,
                closeTo(1.0, 0.01),
                reason: 'Sheet should have settled at 1.0',
              );
            }

            // Now fling upward from 1.0
            await tester.fling(
              contentFinder,
              const Offset(0, -800),
              10000,
            );

            final overshoot = controller.value - 1.0;

            // Tear down by settling
            await tester.pumpAndSettle();

            // Pop the route so we start clean
            Navigator.of(tester.element(contentFinder)).pop();
            await tester.pumpAndSettle();

            return overshoot;
          }

          // Sheet opened directly at 1.0
          final directOvershoot = await measureOvershoot(initialSnap: 1);

          // Sheet opened at 0.5, dragged to 1.0, then overshot
          final draggedOvershoot = await measureOvershoot(initialSnap: 0.5);

          // Both should overshoot by roughly the same amount — if the sticking
          // point wasn't updated the second case would be near zero.
          expect(
            draggedOvershoot,
            closeTo(directOvershoot, directOvershoot * 0.3),
            reason: 'Overshoot should be comparable regardless '
                'of initial snap. '
                'Direct: $directOvershoot, '
                'After drag: $draggedOvershoot',
          );
        },
      );

      testWidgets('will not scroll at all when dragged up from snap',
          (tester) async {
        await tester.pumpWidget(
          build(
            snappingConfig: const SheetSnappingConfig(
              [0.5, 1.0],
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scrollableFinder = find.descendant(
          of: find.byKey(const ValueKey('scaffold')),
          matching: find.byType(Scrollable),
        );

        final sheetRoute = ModalRoute.of(tester.element(scrollableFinder))!
            as StupidSimpleCupertinoSheetRoute;

        expect(scrollableFinder, findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollableFinder).position.pixels,
          equals(0.0),
        );
        expect(sheetRoute.animation!.value, equals(0.5));

        // Drag sheet to top quickly
        final gesture =
            await tester.startGesture(tester.getTopLeft(scrollableFinder));
        for (var i = 0; i < 15; i++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(sheetRoute.animation!.value, greaterThan(0.5));

        expect(
          tester.state<ScrollableState>(scrollableFinder).position.pixels,
          equals(0.0),
        );

        await gesture.up();
        await tester.pumpAndSettle();

        expect(sheetRoute.animation!.value, equals(1.0));
      });

      testWidgets('will clear overscroll immediately when let go',
          (tester) async {
        await tester.pumpWidget(
          build(),
        );

        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scrollableFinder = find.descendant(
          of: find.byKey(const ValueKey('scaffold')),
          matching: find.byType(Scrollable),
        );

        expect(scrollableFinder, findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollableFinder).position.pixels,
          equals(0.0),
        );

        // Drag sheet to bottom quickly
        final gesture =
            await tester.startGesture(tester.getTopLeft(scrollableFinder));
        for (var i = 0; i < 15; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }

        final scrollPixels =
            tester.state<ScrollableState>(scrollableFinder).position.pixels;

        expect(scrollPixels, lessThan(0.0));

        await gesture.up();

        await tester.pumpFrames(build(), const Duration(milliseconds: 200));

        expect(
          tester.state<ScrollableState>(scrollableFinder).position.pixels,
          greaterThan(scrollPixels),
        );
      });
    });

    group('controlling imperatively', () {
      testWidgets('can find controller', (tester) async {
        final widget = build();

        await tester.pumpWidget(widget);
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffold = find.byKey(const ValueKey('scaffold'));
        final controller = StupidSimpleSheetController.maybeOf<dynamic>(
          tester.element(scaffold),
        );

        expect(controller, isA<StupidSimpleSheetController<dynamic>>());
      });

      testWidgets('can move sheet to specific position', (tester) async {
        final widget = build();

        await tester.pumpWidget(widget);
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffold = find.byKey(const ValueKey('scaffold'));
        final controller = StupidSimpleSheetController.maybeOf<dynamic>(
          tester.element(scaffold),
        );

        controller!.animateToRelative(0.5).ignore();
        await tester.pumpAndSettle();

        final route = ModalRoute.of(tester.element(scaffold))!
            as StupidSimpleCupertinoSheetRoute;

        // ignore: invalid_use_of_protected_member
        expect(route.controller!.value, equals(0.5));
      });

      testWidgets('will snap to snap point', (tester) async {
        final widget = build(
          snappingConfig: const SheetSnappingConfig([0.5, 1.0]),
        );

        await tester.pumpWidget(widget);
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffold = find.byKey(const ValueKey('scaffold'));
        final controller = StupidSimpleSheetController.maybeOf<dynamic>(
          tester.element(scaffold),
        );

        controller!.animateToRelative(0.6, snap: true).ignore();
        await tester.pumpAndSettle();

        final route = ModalRoute.of(tester.element(scaffold))!
            as StupidSimpleCupertinoSheetRoute;

        // ignore: invalid_use_of_protected_member
        expect(route.controller!.value, equals(0.5));
      });

      testWidgets('will throw if trying to close', (tester) async {
        final widget = build();

        await tester.pumpWidget(widget);
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffold = find.byKey(const ValueKey('scaffold'));
        final controller = StupidSimpleSheetController.maybeOf<dynamic>(
          tester.element(scaffold),
        );

        expect(
          () => controller!.animateToRelative(0, snap: true).ignore(),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('updateSheetSnappingConfig', () {
      testWidgets('updates the snapping configuration', (tester) async {
        final widget = build();

        await tester.pumpWidget(widget);
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffold = find.byKey(const ValueKey('scaffold'));
        final controller = StupidSimpleSheetController.maybeOf<dynamic>(
          tester.element(scaffold),
        );

        // Initially should use the default config
        expect(
          controller!.effectiveSnappingConfig,
          equals(SheetSnappingConfig.full),
        );

        // Update to a new configuration
        const newConfig = SheetSnappingConfig([0.3, 0.6, 1.0]);
        await controller.overrideSnappingConfig(newConfig);

        expect(controller.effectiveSnappingConfig, equals(newConfig));

        // Reset to the original configuration
        await controller.overrideSnappingConfig(null);

        expect(
          controller.effectiveSnappingConfig,
          equals(SheetSnappingConfig.full),
        );
      });

      testWidgets('animates to comply with new config', (tester) async {
        final widget = build();

        await tester.pumpWidget(widget);
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffold = find.byKey(const ValueKey('scaffold'));
        final controller = StupidSimpleSheetController.maybeOf<dynamic>(
          tester.element(scaffold),
        );

        // Move to a specific position
        controller!.animateToRelative(0.8).ignore();
        await tester.pumpAndSettle();

        final route = ModalRoute.of(tester.element(scaffold))!
            as StupidSimpleCupertinoSheetRoute;

        // ignore: invalid_use_of_protected_member
        expect(route.controller!.value, closeTo(0.8, 0.01));

        // Update config with animateToComply - should snap to nearest point
        const newConfig = SheetSnappingConfig([0.5, 1.0]);
        controller
            .overrideSnappingConfig(newConfig, animateToComply: true)
            .ignore();
        await tester.pumpAndSettle();

        // Should snap to 1.0 as it's closest to 0.8
        // ignore: invalid_use_of_protected_member
        expect(route.controller!.value, closeTo(1.0, 0.01));
      });

      testWidgets(
        'does not interrupt dismissal animation when called right after pop',
        (tester) async {
          final widget = build();

          await tester.pumpWidget(widget);
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final scaffold = find.byKey(const ValueKey('scaffold'));
          final controller = StupidSimpleSheetController.maybeOf<dynamic>(
            tester.element(scaffold),
          );

          // Pop the route but don't pump yet
          Navigator.of(tester.element(scaffold)).pop();

          // Before any animation frames, try to override config
          const newConfig = SheetSnappingConfig([0.3, 0.7]);
          controller!
              .overrideSnappingConfig(newConfig, animateToComply: true)
              .ignore();

          // Now pump the dismissal animation
          await tester.pumpAndSettle();

          // The sheet should be gone
          expect(find.byKey(const ValueKey('scaffold')), findsNothing);
        },
      );

      testWidgets(
        'does not interrupt dismissal animation when called mid-dismissal',
        (tester) async {
          final widget = build();

          await tester.pumpWidget(widget);
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final scaffold = find.byKey(const ValueKey('scaffold'));
          final controller = StupidSimpleSheetController.maybeOf<dynamic>(
            tester.element(scaffold),
          );

          final route = ModalRoute.of(tester.element(scaffold))!
              as StupidSimpleCupertinoSheetRoute;

          // Start dismissing
          Navigator.of(tester.element(scaffold)).pop();

          // Pump a few frames so dismissal animation is in progress
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          // ignore: invalid_use_of_protected_member
          final valueDuringDismissal = route.controller!.value;

          // Value should be decreasing (dismissing)
          expect(valueDuringDismissal, lessThan(1.0));

          // Try to override config mid-dismissal
          const newConfig = SheetSnappingConfig([0.5, 1.0]);
          controller!
              .overrideSnappingConfig(newConfig, animateToComply: true)
              .ignore();

          // Continue the animation
          await tester.pumpAndSettle();

          // Sheet should still dismiss properly
          expect(find.byKey(const ValueKey('scaffold')), findsNothing);
        },
      );
    });

    group('animateToRelative', () {
      testWidgets(
        'does not interrupt dismissal animation when called right after pop',
        (tester) async {
          final widget = build();

          await tester.pumpWidget(widget);
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final scaffold = find.byKey(const ValueKey('scaffold'));
          final controller = StupidSimpleSheetController.maybeOf<dynamic>(
            tester.element(scaffold),
          );

          // Pop the route but don't pump yet
          Navigator.of(tester.element(scaffold)).pop();

          // Before any animation frames, try to animate to a position
          controller!.animateToRelative(0.5).ignore();

          // Now pump the dismissal animation
          await tester.pumpAndSettle();

          // The sheet should be gone
          expect(find.byKey(const ValueKey('scaffold')), findsNothing);
        },
      );

      testWidgets(
        'does not interrupt dismissal animation when called mid-dismissal',
        (tester) async {
          final widget = build();

          await tester.pumpWidget(widget);
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          final scaffold = find.byKey(const ValueKey('scaffold'));
          final controller = StupidSimpleSheetController.maybeOf<dynamic>(
            tester.element(scaffold),
          );

          final route = ModalRoute.of(tester.element(scaffold))!
              as StupidSimpleCupertinoSheetRoute;

          // Start dismissing
          Navigator.of(tester.element(scaffold)).pop();

          // Pump a few frames so dismissal animation is in progress
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          // ignore: invalid_use_of_protected_member
          final valueDuringDismissal = route.controller!.value;

          // Value should be decreasing (dismissing)
          expect(valueDuringDismissal, lessThan(1.0));

          // Try to animate to a position mid-dismissal
          controller!.animateToRelative(0.8, snap: true).ignore();

          // Continue the animation
          await tester.pumpAndSettle();

          // Sheet should still dismiss properly
          expect(find.byKey(const ValueKey('scaffold')), findsNothing);
        },
      );
    });

    testWidgets('cannot be dragged when draggable is false', (tester) async {
      await tester.pumpWidget(build(draggable: false));
      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
      final initialTopLeft = tester.getTopLeft(scaffoldFinder);

      final gesture =
          await tester.startGesture(tester.getCenter(scaffoldFinder));

      const dragFrames = 10;
      const dragPx = 30.0;
      const expectedDragDelta = dragFrames * dragPx;

      for (var i = 0; i < dragFrames; i++) {
        await gesture.moveBy(const Offset(0, dragPx));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final draggedTopLeft = tester.getTopLeft(scaffoldFinder);

      final dragDelta = draggedTopLeft.dy - initialTopLeft.dy;

      // We have moved less than 20% of the expected drag distance because we're
      // sticking
      expect(dragDelta, lessThan(expectedDragDelta * .2));

      await gesture.up();
    });

    group('radius goldens', () {
      setUp(() {
        final comparator = goldenFileComparator;

        if (!autoUpdateGoldenFiles) {
          goldenFileComparator = PixelDiffGoldenComparator(
            (goldenFileComparator as LocalFileComparator).basedir.path,
            pixelCount: 750,
          );
        }

        addTearDown(() {
          goldenFileComparator = comparator;
        });
      });

      testWidgets('looks correct with default radius', (tester) async {
        await tester.pumpWidget(build());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'default radius',
          device: Devices.ios.iPhone16,
        );
      });

      testWidgets('looks correct with large radius', (tester) async {
        const shape = RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        );

        await tester.pumpWidget(build(shape: shape));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'large radius',
          device: Devices.ios.iPhone16,
        );
      });

      testWidgets('looks correct with rounded rectangle', (tester) async {
        const shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        );

        await tester.pumpWidget(build(shape: shape));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'large radius rrect',
          device: Devices.ios.iPhone16,
        );
      });

      testWidgets('looks correct with zero radius', (tester) async {
        const shape = LinearBorder.none;

        await tester.pumpWidget(build(shape: shape));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'zero radius',
          device: Devices.ios.iPhone16,
        );
      });
    });

    group('shrink dismissal mode', () {
      Widget buildShrink({
        SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
        bool draggable = true,
        Widget? child,
      }) {
        return CupertinoApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return CupertinoButton.filled(
                    key: const ValueKey('button'),
                    onPressed: () => Navigator.of(context).push(
                      StupidSimpleCupertinoSheetRoute<void>(
                        motion: motion,
                        dismissalMode: DismissalMode.shrink,
                        snappingConfig: snappingConfig,
                        draggable: draggable,
                        child: child ??
                            Scaffold(
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
                    child: const Text('Show Sheet'),
                  );
                },
              ),
            ),
          ),
        );
      }

      testWidgets('opens and shows content', (tester) async {
        await tester.pumpWidget(buildShrink());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scaffold')), findsOneWidget);
      });

      testWidgets('can be dragged down', (tester) async {
        await tester.pumpWidget(buildShrink());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        // The route animation value should be less than 1.0 after dragging
        final route = ModalRoute.of(tester.element(scaffoldFinder))!
            as StupidSimpleCupertinoSheetRoute;
        expect(route.animation!.value, lessThan(1.0));

        await gesture.up();
      });

      testWidgets('route behind becomes interactable when popping',
          (tester) async {
        final buttonFinder = find.byKey(const ValueKey('button'));
        await tester.pumpWidget(buildShrink());
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        expect(buttonFinder.hitTestable(), findsNothing);

        Navigator.of(tester.element(scaffoldFinder)).pop();

        // Allow the sheet to clear the button enough
        await tester.pumpFrames(
          buildShrink(),
          const Duration(milliseconds: 120),
        );

        expect(buttonFinder.hitTestable(), findsOneWidget);
      });

      testWidgets('can be closed while dragging', (tester) async {
        await tester.pumpWidget(buildShrink());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        Navigator.of(tester.element(scaffoldFinder)).pop();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scaffold')), findsNothing);

        await gesture.up();
      });

      testWidgets('cannot be dragged when draggable is false', (tester) async {
        await tester.pumpWidget(buildShrink(draggable: false));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final route = ModalRoute.of(tester.element(scaffoldFinder))!
            as StupidSimpleCupertinoSheetRoute;
        final initialValue = route.animation!.value;

        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        // ignore: invalid_use_of_protected_member
        final currentValue = route.controller!.value;
        final delta = initialValue - currentValue;

        // Resistance should prevent significant movement
        expect(delta, lessThan(initialValue * 0.2));

        await gesture.up();
      });

      testWidgets('snapping works with shrink mode', (tester) async {
        await tester.pumpWidget(
          buildShrink(
            snappingConfig: const SheetSnappingConfig(
              [0.5, 1.0],
              initialSnap: 1,
            ),
            child: Container(
              key: const ValueKey('sheet-content'),
              height: 200,
              color: const Color(0xFF2196F3),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final contentFinder = find.byKey(const ValueKey('sheet-content'));
        final route = ModalRoute.of(tester.element(contentFinder))!
            as StupidSimpleCupertinoSheetRoute;

        expect(route.animation!.value, equals(1));

        // Fling the sheet past 1.0
        await tester.fling(
          contentFinder,
          const Offset(0, -800),
          10000,
        );

        await tester.pumpAndSettle();

        // ignore: invalid_use_of_protected_member
        expect(route.controller!.value, equals(1));
      });
    });
  });

  group('StupidSimpleGlassSheetRoute', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget build({
      ShapeBorder? shape,
    }) {
      return CupertinoApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return CupertinoButton.filled(
                  key: const ValueKey('button'),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(
                    StupidSimpleGlassSheetRoute<void>(
                      motion: motion,
                      shape: shape ?? StupidSimpleGlassSheetRoute.glassShape,
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

    group('radius goldens', () {
      setUp(() {
        final comparator = goldenFileComparator;

        if (!autoUpdateGoldenFiles) {
          goldenFileComparator = PixelDiffGoldenComparator(
            (goldenFileComparator as LocalFileComparator).basedir.path,
            pixelCount: 750,
          );
        }

        addTearDown(() {
          goldenFileComparator = comparator;
        });
      });

      testWidgets('looks correct with default glass shape', (tester) async {
        await tester.pumpWidget(build());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'glass default radius',
          device: Devices.ios.iPhone16,
        );
      });

      testWidgets('looks correct with large radius', (tester) async {
        const shape = RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(48),
          ),
        );

        await tester.pumpWidget(build(shape: shape));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'glass large radius',
          device: Devices.ios.iPhone16,
        );
      });

      testWidgets('looks correct with small radius', (tester) async {
        const shape = RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(12),
          ),
        );

        await tester.pumpWidget(build(shape: shape));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap.golden(
          name: 'glass small radius',
          device: Devices.ios.iPhone16,
        );
      });
    });

    testWidgets('barrierColor can be set', (tester) async {
      const key = Key('');
      await tester.pumpWidget(
        CupertinoApp(
          home: Scaffold(
            body: Center(
              child: Container(
                key: key,
                child: const SizedBox.expand(child: GridPaper()),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byKey(key));

      // Push a full screen sheet
      Navigator.of(context)
          .push(
            StupidSimpleGlassSheetRoute<void>(
              child: const Scaffold(),
              blurBehindBarrier: true,
              barrierColor: Colors.red.withValues(alpha: .1),
            ),
          )
          .ignore();

      await tester.pumpAndSettle();
      await snap.golden(
        name: 'glass barrier color and blur',
        device: Devices.ios.iPhone16,
      );

      await Navigator.of(context).maybePop();

      await tester.pumpAndSettle();

      // Push a full screen sheet
      Navigator.of(context)
          .push(
            StupidSimpleGlassSheetRoute<void>(
              child: const Scaffold(),
              blurBehindBarrier: false,
              barrierColor: Colors.blue.withValues(alpha: .1),
            ),
          )
          .ignore();

      await tester.pumpAndSettle();
      await snap.golden(
        name: 'glass barrier color no blur',
        device: Devices.ios.iPhone16,
      );
    });

    group('shrink dismissal mode', () {
      Widget buildShrink({
        Widget? child,
      }) {
        return CupertinoApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return CupertinoButton.filled(
                    key: const ValueKey('button'),
                    onPressed: () => Navigator.of(context).push(
                      StupidSimpleGlassSheetRoute<void>(
                        motion: motion,
                        dismissalMode: DismissalMode.shrink,
                        child: child ??
                            Scaffold(
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
                    child: const Text('Show Sheet'),
                  );
                },
              ),
            ),
          ),
        );
      }

      testWidgets('opens and shows content', (tester) async {
        await tester.pumpWidget(buildShrink());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scaffold')), findsOneWidget);
      });

      testWidgets('can be popped programmatically', (tester) async {
        await tester.pumpWidget(buildShrink());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        Navigator.of(tester.element(scaffoldFinder)).pop();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scaffold')), findsNothing);
      });

      testWidgets('can be dragged down', (tester) async {
        await tester.pumpWidget(buildShrink());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final scaffoldFinder = find.byKey(const ValueKey('scaffold'));
        final route = ModalRoute.of(tester.element(scaffoldFinder))!
            as StupidSimpleGlassSheetRoute;

        final gesture =
            await tester.startGesture(tester.getCenter(scaffoldFinder));

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(route.animation!.value, lessThan(1.0));

        await gesture.up();
      });
    });

    testWidgets('transition looks correct when snapping', (tester) async {
      const key = Key('');
      await tester.pumpWidget(
        CupertinoApp(
          home: Scaffold(
            body: Center(
              child: Container(
                key: key,
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byKey(key));

      // Push a full screen sheet
      Navigator.of(context)
          .push(
            StupidSimpleGlassSheetRoute<void>(
              child: const Scaffold(),
              blurBehindBarrier: false,
            ),
          )
          .ignore();

      await tester.pumpAndSettle();

      const topSheetKey = Key('top sheet');

      // Now push a second sheet with snapping points
      Navigator.of(context)
          .push(
            StupidSimpleGlassSheetRoute<void>(
              child: const Scaffold(
                key: topSheetKey,
              ),
              snappingConfig: const SheetSnappingConfig([0.5, 1.0]),
            ),
          )
          .ignore();

      await tester.pumpAndSettle();

      await snap.golden(
        name: 'glass snap transition',
        device: Devices.ios.iPhone16,
      );

      // Now snap the sheet to full
      StupidSimpleSheetController.maybeOf<dynamic>(
        tester.element(find.byKey(topSheetKey)),
      )!
          .animateToRelative(1)
          .ignore();

      await tester.pumpAndSettle();

      await snap.golden(
        name: 'glass snap transition full',
        device: Devices.ios.iPhone16,
      );
    });
  });

  group('SnapPhysics integration', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget build({
      required SheetSnappingConfig snappingConfig,
      bool canPop = true,
    }) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return TextButton(
                  key: const ValueKey('button'),
                  onPressed: () => Navigator.of(context).push(
                    StupidSimpleSheetRoute<void>(
                      motion: motion,
                      snappingConfig: snappingConfig,
                      child: PopScope(
                        canPop: canPop,
                        child: const SizedBox.expand(
                          key: ValueKey('sheet-content'),
                          child: ColoredBox(
                            color: Color(0xFF2196F3),
                            child: Center(child: Text('Sheet')),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Show Sheet'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets(
      'FlingSnapPhysics: fling down from 1.0 settles at adjacent snap, '
      'not further',
      (tester) async {
        await tester.pumpWidget(
          build(
            canPop: false,
            snappingConfig: const SheetSnappingConfig(
              [0.3, 0.6, 1.0],
              initialSnap: 1,
              // FlingSnapPhysics is the default
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final contentFinder = find.byKey(const ValueKey('sheet-content'));
        final route = ModalRoute.of(tester.element(contentFinder))!
            as StupidSimpleSheetRoute;
        // ignore: invalid_use_of_protected_member
        final controller = route.controller!;

        expect(controller.value, equals(1.0));

        // Short, fast drag to produce fling velocity while keeping the
        // position still above 0.6 at release time.
        await tester.timedDragFrom(
          tester.getCenter(contentFinder),
          const Offset(0, 100),
          const Duration(milliseconds: 100),
        );
        expect(controller.value, greaterThan(0.6));
        await tester.pumpAndSettle();

        // FlingSnapPhysics should stop at 0.6 (the adjacent snap below 1.0),
        // not skip to 0.3
        expect(
          controller.value,
          equals(.6),
          reason: 'FlingSnapPhysics should snap to adjacent point (0.6), '
              'not skip past it. Got ${controller.value}.',
        );
      },
    );

    testWidgets(
      'FrictionSnapPhysics: fling down from 1.0 can skip intermediate snaps',
      (tester) async {
        await tester.pumpWidget(
          build(
            canPop: false,
            snappingConfig: const SheetSnappingConfig(
              [0.3, 0.6, 1.0],
              initialSnap: 1,
              physics: FrictionSnapPhysics(),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final contentFinder = find.byKey(const ValueKey('sheet-content'));
        final route = ModalRoute.of(tester.element(contentFinder))!
            as StupidSimpleSheetRoute;
        // ignore: invalid_use_of_protected_member
        final controller = route.controller!;

        expect(controller.value, equals(1.0));

        // Same physical fling gesture — friction physics should project further
        await tester.timedDragFrom(
          tester.getCenter(contentFinder),
          const Offset(0, 100),
          const Duration(milliseconds: 100),
        );
        expect(controller.value, greaterThan(0.6));
        await tester.pumpAndSettle();

        // FrictionSnapPhysics projects using a friction simulation, so with
        // enough velocity it should skip past 0.6 to 0.3
        expect(
          controller.value,
          equals(.3),
          reason: 'FrictionSnapPhysics should skip intermediate '
              'snap points with a fling. Got ${controller.value}.',
        );
      },
    );

    testWidgets(
      'slow drag release snaps to closest point',
      (tester) async {
        await tester.pumpWidget(
          build(
            canPop: false,
            snappingConfig: const SheetSnappingConfig(
              [0.3, 0.6, 1.0],
              initialSnap: 1,
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        final contentFinder = find.byKey(const ValueKey('sheet-content'));
        final route = ModalRoute.of(tester.element(contentFinder))!
            as StupidSimpleSheetRoute;
        // ignore: invalid_use_of_protected_member
        final controller = route.controller!;

        expect(controller.value, equals(1.0));

        // Very slow drag — should produce negligible velocity
        await tester.timedDragFrom(
          tester.getCenter(contentFinder),
          const Offset(0, 150),
          const Duration(milliseconds: 1500),
        );
        await tester.pumpAndSettle();

        // Should snap to nearest point (0.6 or 1.0), not skip to 0.3
        expect(
          controller.value,
          anyOf(closeTo(0.6, 0.05), closeTo(1.0, 0.05)),
          reason: 'Slow drag should snap to nearest point. '
              'Got ${controller.value}.',
        );
      },
    );
  });
}

/// A golden file comparator that allows a specified number of pixels
/// to be different between the golden image file and the test image file, and
/// still pass.
class PixelDiffGoldenComparator extends LocalFileComparator {
  PixelDiffGoldenComparator(
    String testBaseDirectory, {
    required int pixelCount,
  })  : _testBaseDirectory = testBaseDirectory,
        _maxPixelMismatchCount = pixelCount,
        super(Uri.parse(testBaseDirectory));

  @override
  Uri get basedir => Uri.parse(_testBaseDirectory);

  /// The file system path to the directory that holds the currently executing
  /// Dart test file.
  final String _testBaseDirectory;

  /// The maximum number of mismatched pixels for which this pixel test
  /// is considered a success/pass.
  final int _maxPixelMismatchCount;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    // Note: the incoming `golden` Uri is a partial path from the currently
    // executing test directory to the golden file, e.g., "goldens/my-test.png".
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed) {
      return true;
    }

    final diffImage = result.diffs!.entries.first.value;
    final pixelCount = diffImage.width * diffImage.height;
    final pixelMismatchCount = pixelCount * result.diffPercent;

    if (pixelMismatchCount <= _maxPixelMismatchCount) {
      return true;
    }

    // Paint the golden diffs and images to failure files.
    await generateFailureOutput(result, golden, basedir);
    throw FlutterError(
      "Pixel test failed. ${result.diffPercent.toStringAsFixed(2)}% diff, "
      "$pixelMismatchCount pixel count diff (max allowed pixel mismatch "
      "count is $_maxPixelMismatchCount)",
    );
  }
}
