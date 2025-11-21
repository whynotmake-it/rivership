// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/cupertino.dart';
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
                      clipBehavior: Clip.none,
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

      await snap();

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

        await snap();

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
          snappingConfig: const SheetSnappingConfig.relative([0.5, 1.0]),
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

    group('updateSnappingConfig', () {
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
        const newConfig = SheetSnappingConfig.relative([0.3, 0.6, 1.0]);
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
        const newConfig = SheetSnappingConfig.relative([0.5, 1.0]);
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
          const newConfig = SheetSnappingConfig.relative([0.3, 0.7]);
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
          const newConfig = SheetSnappingConfig.relative([0.5, 1.0]);
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

        goldenFileComparator = PixelDiffGoldenComparator(
          (goldenFileComparator as LocalFileComparator).basedir.path,
          pixelCount: 750,
        );

        addTearDown(() {
          goldenFileComparator = comparator;
        });
      });

      testWidgets('looks correct with default radius', (tester) async {
        await tester.pumpWidget(build());
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap(name: 'default radius', matchToGolden: true);
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

        await snap(name: 'large radius', matchToGolden: true);
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

        await snap(name: 'large radius rrect', matchToGolden: true);
      });

      testWidgets('looks correct with zero radius', (tester) async {
        const shape = LinearBorder.none;

        await tester.pumpWidget(build(shape: shape));
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pumpAndSettle();

        await snap(name: 'zero radius', matchToGolden: true);
      });

      group('deprecated radius parameter', () {
        Widget build({
          required Radius topRadius,
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
                          // ignore: deprecated_member_use_from_same_package
                          topRadius: topRadius,
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

        testWidgets('still works', (tester) async {
          await tester.pumpWidget(build(topRadius: const Radius.circular(50)));
          await tester.tap(find.byKey(const ValueKey('button')));
          await tester.pumpAndSettle();

          await snap(name: 'deprecated radius 50px', matchToGolden: true);
        });
      });
    });
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
