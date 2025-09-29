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
  });

  group('StupidSimpleCupertinoSheetRoute', () {
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 400),
      snapToEnd: true,
    );

    Widget build({
      Motion motion = motion,
      bool clearBarrierImmediately = true,
      SheetSnappingConfig snappingConfig =
          const SheetSnappingConfig.relative([1.0]),
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
  });
}
