import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
  const motion = CupertinoMotion.smooth(duration: Duration(milliseconds: 300));

  Widget buildApp({
    required RouteSnapshotMode mode,
    SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
    bool enableSecondSheet = false,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.of(context).push(
                StupidSimpleGlassSheetRoute<void>(
                  motion: motion,
                  backgroundSnapshotMode: mode,
                  snappingConfig: snappingConfig,
                  child: Builder(
                    builder: (context) => Scaffold(
                      key: const ValueKey('sheet'),
                      body: enableSecondSheet
                          ? Center(
                              child: TextButton(
                                key: const ValueKey('open2'),
                                onPressed: () => Navigator.of(context).push(
                                  StupidSimpleGlassSheetRoute<void>(
                                    motion: motion,
                                    backgroundSnapshotMode: mode,
                                    child: const Scaffold(
                                      key: ValueKey('sheet2'),
                                    ),
                                  ),
                                ),
                                child: const Text('Open 2'),
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the route's [SnapshotController.allowSnapshotting] value.
  bool isSnapshotting(WidgetTester tester) {
    final route = ModalRoute.of(
      tester.element(find.byKey(const ValueKey('sheet'))),
    )! as StupidSimpleGlassSheetRoute;
    // ignore: invalid_use_of_protected_member
    return route.backgroundSnapshotController.allowSnapshotting;
  }

  group('RouteSnapshotMode', () {
    testWidgets('never: no SnapshotWidget in delegated transition',
        (tester) async {
      await tester.pumpWidget(buildApp(mode: RouteSnapshotMode.never));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      // With never, delegatedTransition returns null → no SnapshotWidget
      expect(find.byType(SnapshotWidget), findsNothing);
    });

    testWidgets('always: snapshotting stays on throughout', (tester) async {
      await tester.pumpWidget(buildApp(mode: RouteSnapshotMode.always));
      await tester.tap(find.byKey(const ValueKey('open')));
      // Mid-animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(isSnapshotting(tester), isTrue);

      // Settled
      await tester.pumpAndSettle();
      expect(isSnapshotting(tester), isTrue);
    });

    testWidgets('openAndForward: on during open animation and when settled',
        (tester) async {
      await tester.pumpWidget(
        buildApp(mode: RouteSnapshotMode.openAndForward),
      );
      await tester.tap(find.byKey(const ValueKey('open')));

      // Mid open-animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(isSnapshotting(tester), isTrue);

      // Settled
      await tester.pumpAndSettle();
      expect(isSnapshotting(tester), isTrue);
    });

    testWidgets('openAndForward: off during user drag', (tester) async {
      await tester.pumpWidget(
        buildApp(mode: RouteSnapshotMode.openAndForward),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(isSnapshotting(tester), isTrue);

      // Start drag
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('sheet'))),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();

      expect(isSnapshotting(tester), isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('openAndForward: off during animation to intermediate snap',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          mode: RouteSnapshotMode.openAndForward,
          // Initial snap is 0.5 (the lowest non-zero point).
          // The sheet opens to 0.5, not 1.0.
          snappingConfig: const SheetSnappingConfig([0.5, 1.0]),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));

      // Mid-animation toward 0.5 — target is not max extent so no snapshot
      await tester.pump(const Duration(milliseconds: 100));
      expect(isSnapshotting(tester), isFalse);

      // Settled at 0.5, still not the final snap point (1.0)
      await tester.pumpAndSettle();
      expect(isSnapshotting(tester), isFalse);
    });

    testWidgets('animating: on during animation, off when settled',
        (tester) async {
      await tester.pumpWidget(buildApp(mode: RouteSnapshotMode.animating));
      await tester.tap(find.byKey(const ValueKey('open')));

      // Mid-animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(isSnapshotting(tester), isTrue);

      // Settled
      await tester.pumpAndSettle();
      expect(isSnapshotting(tester), isFalse);
    });

    testWidgets('settled: off during animation, on when settled',
        (tester) async {
      await tester.pumpWidget(buildApp(mode: RouteSnapshotMode.settled));
      await tester.tap(find.byKey(const ValueKey('open')));

      // Mid-animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(isSnapshotting(tester), isFalse);

      // Settled
      await tester.pumpAndSettle();
      expect(isSnapshotting(tester), isTrue);
    });

    testWidgets(
        'sheet-on-sheet: second sheet snapshots the first via '
        'maybeSnapshotChild', (tester) async {
      await tester.pumpWidget(
        buildApp(
          mode: RouteSnapshotMode.always,
          enableSecondSheet: true,
        ),
      );

      // Open first sheet
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      // No SnapshotWidget wrapping the first sheet's own content yet
      // (maybeSnapshotChild returns child as-is when not covered)
      final snapshotsBefore =
          tester.widgetList<SnapshotWidget>(find.byType(SnapshotWidget));
      final countBefore = snapshotsBefore.length;

      // Open second sheet on top
      await tester.tap(find.byKey(const ValueKey('open2')));
      await tester.pumpAndSettle();

      // Now there should be an additional SnapshotWidget from
      // maybeSnapshotChild wrapping the first sheet's content
      final snapshotsAfter =
          tester.widgetList<SnapshotWidget>(find.byType(SnapshotWidget));
      expect(snapshotsAfter.length, greaterThan(countBefore));
    });
  });
}
