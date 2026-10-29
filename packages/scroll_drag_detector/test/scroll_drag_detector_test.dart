// ignore_for_file: cascade_invocations

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

void main() {
  group('layout-time scroll notifications', () {
    for (final axis in Axis.values) {
      testWidgets('ending a $axis drag during layout is safe', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final starts = <bool>[];
        final ends = <bool>[];
        Widget build({VoidCallback? onLayout}) => _TestScrollable(
              axis: axis,
              reverse: false,
              controller: controller,
              onLayout: onLayout,
              modes: const {
                AxisDirection.down: ScrollDragMode.scrollFirst,
                AxisDirection.right: ScrollDragMode.scrollFirst,
              },
              onStart: starts.add,
              onEnd: ends.add,
            );

        await tester.pumpWidget(build());
        final scrollable = find.byType(Scrollable);
        final gesture = await tester.startGesture(tester.getCenter(scrollable));
        final delta =
            axis == Axis.vertical ? const Offset(0, 20) : const Offset(20, 0);
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(delta);
          await tester.pump();
        }
        expect(starts, [true]);

        var endedDuringLayout = false;
        await tester.pumpWidget(
          build(
            onLayout: () {
              expect(
                SchedulerBinding.instance.schedulerPhase,
                SchedulerPhase.persistentCallbacks,
              );
              endedDuringLayout = true;
              controller.jumpTo(controller.offset);
            },
          ),
        );

        expect(endedDuringLayout, isTrue);
        expect(tester.takeException(), isNull);
        expect(ends, [false]);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(ends, [false]);
      });

      for (final overscroll in [false, true]) {
        for (final end in ['update', 'overscroll', 'end']) {
          testWidgets(
            '$axis layout takeover via overscroll=$overscroll, ending via $end',
            (tester) async {
              final starts = <bool>[];
              final updates = <bool>[];
              final ends = <bool>[];
              Widget build({VoidCallback? onLayout}) => _TestScrollable(
                    axis: axis,
                    reverse: false,
                    onLayout: onLayout,
                    modes: const {
                      AxisDirection.down: ScrollDragMode.scrollFirst,
                      AxisDirection.right: ScrollDragMode.scrollFirst,
                    },
                    onStart: starts.add,
                    onUpdate: updates.add,
                    onEnd: ends.add,
                  );

              await tester.pumpWidget(build());
              final context = tester.element(find.byType(Scrollable));
              final metrics = tester
                  .state<ScrollableState>(
                    find.byType(Scrollable),
                  )
                  .position;
              final delta = axis == Axis.vertical
                  ? const Offset(0, 20)
                  : const Offset(20, 0);
              final details = DragUpdateDetails(
                delta: delta,
                primaryDelta: 20,
                globalPosition: Offset.zero,
              );
              ScrollNotification takeover() => overscroll
                  ? OverscrollNotification(
                      metrics: metrics,
                      context: context,
                      dragDetails: details,
                      overscroll: -20,
                    )
                  : ScrollUpdateNotification(
                      metrics: metrics,
                      context: context,
                      dragDetails: details,
                      scrollDelta: -20,
                    );

              await tester.pumpWidget(
                build(
                  onLayout: () {
                    ScrollStartNotification(
                      metrics: metrics,
                      context: context,
                      dragDetails: DragStartDetails(),
                    ).dispatch(context);
                    takeover().dispatch(context);
                    takeover().dispatch(context);
                    switch (end) {
                      case 'update':
                        ScrollUpdateNotification(
                          metrics: metrics,
                          context: context,
                          dragDetails: DragUpdateDetails(
                            delta: -delta,
                            primaryDelta: -20,
                            globalPosition: Offset.zero,
                          ),
                          scrollDelta: 20,
                        ).dispatch(context);
                      case 'overscroll':
                        OverscrollNotification(
                          metrics: metrics,
                          context: context,
                          overscroll: -20,
                        ).dispatch(context);
                      case 'end':
                        ScrollEndNotification(
                          metrics: metrics,
                          context: context,
                        ).dispatch(context);
                    }
                    ScrollEndNotification(
                      metrics: metrics,
                      context: context,
                    ).dispatch(context);
                  },
                ),
              );

              expect(tester.takeException(), isNull);
              expect(starts, [true]);
              expect(updates, [true]);
              expect(ends, [end == 'update']);
              await tester.pumpWidget(build());
              expect(tester.takeException(), isNull);
              final currentContext = tester.element(find.byType(Scrollable));
              final position = tester
                  .state<ScrollableState>(
                    find.byType(Scrollable),
                  )
                  .position;
              final physics = ScrollConfiguration.of(currentContext)
                  .getScrollPhysics(currentContext);
              expect(
                physics.applyBoundaryConditions(position, position.pixels + 20),
                0,
              );
            },
          );
        }
      }
    }

    testWidgets('a restarted drag suppresses the queued end', (tester) async {
      final starts = <bool>[];
      final ends = <bool>[];
      Widget build({VoidCallback? onLayout}) => _TestScrollable(
            axis: Axis.vertical,
            reverse: false,
            onLayout: onLayout,
            modes: const {AxisDirection.down: ScrollDragMode.scrollFirst},
            onStart: starts.add,
            onEnd: ends.add,
          );
      await tester.pumpWidget(build());
      final context = tester.element(find.byType(Scrollable));
      final metrics =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      void start() {
        ScrollStartNotification(
          metrics: metrics,
          context: context,
          dragDetails: DragStartDetails(),
        ).dispatch(context);
        OverscrollNotification(
          metrics: metrics,
          context: context,
          overscroll: -20,
          dragDetails: DragUpdateDetails(
            delta: const Offset(0, 20),
            primaryDelta: 20,
            globalPosition: Offset.zero,
          ),
        ).dispatch(context);
      }

      await tester.pumpWidget(
        build(
          onLayout: () {
            start();
            ScrollEndNotification(metrics: metrics, context: context)
                .dispatch(context);
            start();
          },
        ),
      );
      expect(tester.takeException(), isNull);
      expect(starts, [true, true]);
      expect(ends, isEmpty);
      await tester.pumpWidget(build());
      final currentContext = tester.element(find.byType(Scrollable));
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      final physics = ScrollConfiguration.of(currentContext)
          .getScrollPhysics(currentContext);
      expect(physics.applyBoundaryConditions(position, 20), 20);
      ScrollEndNotification(metrics: position, context: currentContext)
          .dispatch(currentContext);
      await tester.pumpAndSettle();
      expect(ends, [false]);
    });

    testWidgets('queued updates are ignored after disposal', (tester) async {
      final starts = <bool>[];
      final ends = <bool>[];
      await tester.pumpWidget(
        Builder(
          builder: (context) => _TestScrollable(
            axis: Axis.vertical,
            reverse: false,
            modes: const {AxisDirection.down: ScrollDragMode.scrollFirst},
            onStart: starts.add,
            onEnd: ends.add,
          ),
        ),
      );
      final context = tester.element(find.byType(Scrollable));
      final metrics =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      await tester.pumpWidget(
        Builder(
          builder: (_) {
            ScrollStartNotification(
              metrics: metrics,
              context: context,
              dragDetails: DragStartDetails(),
            ).dispatch(context);
            OverscrollNotification(
              metrics: metrics,
              context: context,
              overscroll: -20,
              dragDetails: DragUpdateDetails(
                delta: const Offset(0, 20),
                primaryDelta: 20,
                globalPosition: Offset.zero,
              ),
            ).dispatch(context);
            ScrollEndNotification(metrics: metrics, context: context)
                .dispatch(context);
            return const SizedBox();
          },
        ),
      );
      expect(starts, [true]);
      expect(ends, isEmpty);
      expect(find.byType(ScrollDragDetector), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('ScrollDragMode', () {
    test('exposes every routing mode', () {
      expect(
        ScrollDragMode.values,
        containsAll(<ScrollDragMode>[
          ScrollDragMode.none,
          ScrollDragMode.scrollFirst,
          ScrollDragMode.dragFirst,
          ScrollDragMode.boundaryStart,
        ]),
      );
    });
  });

  group('physical directions', () {
    for (final (direction, axis, delta, reverse, trailingBoundary) in [
      (
        AxisDirection.up,
        Axis.vertical,
        const Offset(0, -120),
        false,
        true,
      ),
      (
        AxisDirection.down,
        Axis.vertical,
        const Offset(0, 120),
        false,
        false,
      ),
      (
        AxisDirection.left,
        Axis.horizontal,
        const Offset(-120, 0),
        false,
        true,
      ),
      (
        AxisDirection.right,
        Axis.horizontal,
        const Offset(120, 0),
        false,
        false,
      ),
    ]) {
      testWidgets(
        '$direction scrollFirst hands off at its physical boundary',
        (tester) async {
          final starts = <bool>[];
          await tester.pumpWidget(
            _TestScrollable(
              axis: axis,
              reverse: reverse,
              modes: {direction: ScrollDragMode.scrollFirst},
              onStart: starts.add,
            ),
          );

          final scrollable = find.byType(Scrollable);
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(
            trailingBoundary
                ? position.maxScrollExtent
                : position.minScrollExtent,
          );
          await tester.pump();
          final gesture = await tester.startGesture(
            tester.getCenter(scrollable),
          );
          for (var i = 0; i < 10; i++) {
            await gesture.moveBy(delta / 10);
            await tester.pump();
          }
          await gesture.up();

          expect(starts, contains(true));
        },
      );
    }
  });

  group('reversed scrollables', () {
    for (final (direction, axis, delta, trailingBoundary) in [
      (
        AxisDirection.up,
        Axis.vertical,
        const Offset(0, -120),
        false,
      ),
      (
        AxisDirection.down,
        Axis.vertical,
        const Offset(0, 120),
        true,
      ),
      (
        AxisDirection.left,
        Axis.horizontal,
        const Offset(-120, 0),
        false,
      ),
      (
        AxisDirection.right,
        Axis.horizontal,
        const Offset(120, 0),
        true,
      ),
    ]) {
      testWidgets('$direction resolves the correct boundary', (tester) async {
        final starts = <bool>[];
        await tester.pumpWidget(
          _TestScrollable(
            axis: axis,
            reverse: true,
            modes: {direction: ScrollDragMode.scrollFirst},
            onStart: starts.add,
          ),
        );

        final scrollable = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(
          trailingBoundary
              ? position.maxScrollExtent
              : position.minScrollExtent,
        );
        await tester.pump();

        final gesture = await tester.startGesture(tester.getCenter(scrollable));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(delta / 10);
          await tester.pump();
        }
        await gesture.up();

        expect(starts, contains(true));
      });
    }
  });

  testWidgets('dragFirst takes over before the child scrolls', (tester) async {
    final starts = <bool>[];
    await tester.pumpWidget(
      _TestScrollable(
        axis: Axis.vertical,
        reverse: false,
        modes: const {AxisDirection.up: ScrollDragMode.dragFirst},
        onStart: starts.add,
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(500);
    await tester.pump();
    final initialPixels = position.pixels;

    await tester.drag(scrollable, const Offset(0, -120));

    expect(position.pixels, initialPixels);
    expect(starts, contains(true));
  });

  testWidgets(
    'boundaryStart does not take over after scrolling to the boundary',
    (tester) async {
      final starts = <bool>[];
      await tester.pumpWidget(
        _TestScrollable(
          axis: Axis.vertical,
          reverse: false,
          modes: const {
            AxisDirection.down: ScrollDragMode.boundaryStart,
          },
          onStart: starts.add,
        ),
      );

      final scrollable = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(200);
      await tester.pump();

      final gesture = await tester.startGesture(tester.getCenter(scrollable));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
      }
      await gesture.up();

      expect(position.pixels, lessThanOrEqualTo(position.minScrollExtent));
      expect(starts, isEmpty);

      final boundaryGesture =
          await tester.startGesture(tester.getCenter(scrollable));
      for (var i = 0; i < 5; i++) {
        await boundaryGesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      await boundaryGesture.up();

      expect(starts, contains(true));
    },
  );

  testWidgets('none leaves boundary movement child-owned', (tester) async {
    final starts = <bool>[];
    await tester.pumpWidget(
      _TestScrollable(
        axis: Axis.vertical,
        reverse: false,
        onStart: starts.add,
      ),
    );

    await tester.drag(find.byType(Scrollable), const Offset(0, 120));

    expect(starts, isEmpty);
  });

  group('returning to the boundary without lifting the pointer', () {
    for (final mode in [
      ScrollDragMode.boundaryStart,
      ScrollDragMode.scrollFirst,
    ]) {
      for (final axisDirection in AxisDirection.values) {
        for (final trailing in [false, true]) {
          final direction =
              trailing ? flipAxisDirection(axisDirection) : axisDirection;
          final axis = axisDirectionToAxis(axisDirection);
          final reverse = axisDirection == AxisDirection.up ||
              axisDirection == AxisDirection.left;
          final sign = direction == AxisDirection.down ||
                  direction == AxisDirection.right
              ? 1.0
              : -1.0;
          final towardsBoundary =
              axis == Axis.vertical ? Offset(0, sign) : Offset(sign, 0);

          testWidgets('$mode at $axisDirection trailing=$trailing',
              (tester) async {
            final starts = <bool>[];
            final updates = <bool>[];
            await tester.pumpWidget(
              _TestScrollable(
                axis: axis,
                reverse: reverse,
                modes: {direction: mode},
                onStart: starts.add,
                onUpdate: updates.add,
              ),
            );

            final scrollable = find.byType(Scrollable);
            final position = tester.state<ScrollableState>(scrollable).position;
            final boundary =
                trailing ? position.maxScrollExtent : position.minScrollExtent;
            if (trailing) {
              position.jumpTo(boundary);
              await tester.pump();
            }
            expect(position.pixels, boundary);

            final gesture =
                await tester.startGesture(tester.getCenter(scrollable));
            for (var i = 0; i < 6; i++) {
              await gesture.moveBy(towardsBoundary * -20);
              await tester.pump();
            }
            expect((position.pixels - boundary).abs(), greaterThan(50));
            expect(starts, isEmpty);

            // Small steps expose a handoff that freezes short of the boundary.
            for (var i = 0; i < 30; i++) {
              await gesture.moveBy(towardsBoundary * 7);
              await tester.pump();
            }
            expect(starts, [true]);
            expect(updates, isNotEmpty);
            expect(updates, everyElement(isTrue));
            expect(
              tester.state<ScrollableState>(scrollable).position.pixels,
              boundary,
            );
            await gesture.up();
            await tester.pumpAndSettle();

            // A fresh gesture must still drag without stranding the scrollable.
            starts.clear();
            updates.clear();
            final nextGesture =
                await tester.startGesture(tester.getCenter(scrollable));
            for (var i = 0; i < 5; i++) {
              await nextGesture.moveBy(towardsBoundary * 20);
              await tester.pump();
            }
            await nextGesture.up();
            await tester.pumpAndSettle();
            expect(starts, [true]);
            expect(updates, isNotEmpty);
            expect(
              tester.state<ScrollableState>(scrollable).position.pixels,
              boundary,
            );
          });
        }
      }
    }
  });

  testWidgets(
    'scrollFirst can reach a boundary, take over, then return to scrolling',
    (tester) async {
      final starts = <bool>[];
      final ends = <bool>[];
      await tester.pumpWidget(
        _TestScrollable(
          axis: Axis.vertical,
          reverse: false,
          modes: const {AxisDirection.up: ScrollDragMode.scrollFirst},
          onStart: starts.add,
          onEnd: ends.add,
        ),
      );

      final scrollable = find.byType(Scrollable);
      final gesture = await tester.startGesture(tester.getCenter(scrollable));
      for (var i = 0; i < 140; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
      }
      final position = tester.state<ScrollableState>(scrollable).position;

      expect(position.pixels, closeTo(position.maxScrollExtent, 20));
      expect(starts, contains(true));

      // Reverse the same gesture. The parent drag ends and scrolling resumes.
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
      }
      await gesture.up();

      expect(ends, contains(true));
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        lessThan(position.maxScrollExtent),
      );
    },
  );

  testWidgets('boundaryStart can retake the same gesture', (tester) async {
    final starts = <bool>[];
    final ends = <bool>[];
    await tester.pumpWidget(
      _TestScrollable(
        axis: Axis.vertical,
        reverse: false,
        modes: const {
          AxisDirection.down: ScrollDragMode.boundaryStart,
        },
        onStart: starts.add,
        onEnd: ends.add,
      ),
    );

    final scrollable = find.byType(Scrollable);
    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(starts, hasLength(1));

    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    expect(ends, contains(true));

    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();

    expect(starts.length, greaterThanOrEqualTo(2));
  });

  testWidgets('modes on an untracked axis do not intercept scrolling',
      (tester) async {
    final starts = <bool>[];
    await tester.pumpWidget(
      _TestScrollable(
        axis: Axis.horizontal,
        callbackAxis: Axis.vertical,
        reverse: false,
        modes: const {AxisDirection.left: ScrollDragMode.dragFirst},
        onStart: starts.add,
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(500);
    await tester.pump();

    await tester.drag(scrollable, const Offset(-120, 0));

    expect(starts, isEmpty);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(500),
    );
  });

  group('release velocity', () {
    for (final reverse in [false, true]) {
      testWidgets('stays physical when reverse=$reverse', (tester) async {
        final ends = <DragEndDetails>[];
        await tester.pumpWidget(
          _TestScrollable(
            axis: Axis.vertical,
            reverse: reverse,
            modes: const {AxisDirection.up: ScrollDragMode.dragFirst},
            onStart: (_) {},
            onEndDetails: ends.add,
          ),
        );

        await tester.fling(
          find.byType(Scrollable),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(ends, isNotEmpty);
        expect(ends.last.primaryVelocity, lessThanOrEqualTo(0));
      });
    }
  });

  testWidgets('mode changes take effect during an active gesture',
      (tester) async {
    final starts = <bool>[];
    final ends = <bool>[];
    const dragFirstModes = {
      AxisDirection.up: ScrollDragMode.dragFirst,
    };

    await tester.pumpWidget(
      _TestScrollable(
        axis: Axis.vertical,
        reverse: false,
        modes: dragFirstModes,
        onStart: starts.add,
        onEnd: ends.add,
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(500);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    expect(starts, contains(true));

    await tester.pumpWidget(
      _TestScrollable(
        axis: Axis.vertical,
        reverse: false,
        onStart: starts.add,
        onEnd: ends.add,
      ),
    );
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    await gesture.up();

    expect(ends, contains(true));
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(500),
    );
  });

  group('legacy constructor', () {
    for (final canMoveBack in [false, true]) {
      for (final onlyFromTop in [false, true]) {
        test(
          'maps canMoveBack=$canMoveBack onlyFromTop=$onlyFromTop',
          () {
            final detector = ScrollDragDetector.legacy(
              scrollableCanMoveBack: canMoveBack,
              onlyDragWhenScrollWasAtTop: onlyFromTop,
              child: const SizedBox(),
            );

            expect(
              detector.up,
              canMoveBack ? ScrollDragMode.dragFirst : ScrollDragMode.none,
            );
            expect(
              detector.left,
              canMoveBack ? ScrollDragMode.dragFirst : ScrollDragMode.none,
            );
            expect(
              detector.down,
              onlyFromTop
                  ? ScrollDragMode.boundaryStart
                  : ScrollDragMode.scrollFirst,
            );
            expect(
              detector.right,
              onlyFromTop
                  ? ScrollDragMode.boundaryStart
                  : ScrollDragMode.scrollFirst,
            );
          },
        );
      }
    }
  });
}

class _TestScrollable extends StatelessWidget {
  const _TestScrollable({
    required this.axis,
    required this.reverse,
    required this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onEndDetails,
    this.callbackAxis,
    this.controller,
    this.onLayout,
    this.modes = const {},
  });

  final Axis axis;
  final Axis? callbackAxis;
  final ScrollController? controller;
  final VoidCallback? onLayout;
  final bool reverse;
  final ValueChanged<bool> onStart;
  final ValueChanged<bool>? onUpdate;
  final ValueChanged<bool>? onEnd;
  final ValueChanged<DragEndDetails>? onEndDetails;
  final Map<AxisDirection, ScrollDragMode> modes;

  @override
  Widget build(BuildContext context) {
    final effectiveCallbackAxis = callbackAxis ?? axis;
    final detector = ScrollDragDetector(
      up: modes[AxisDirection.up] ?? ScrollDragMode.none,
      down: modes[AxisDirection.down] ?? ScrollDragMode.none,
      left: modes[AxisDirection.left] ?? ScrollDragMode.none,
      right: modes[AxisDirection.right] ?? ScrollDragMode.none,
      onVerticalDragStart: effectiveCallbackAxis == Axis.vertical
          ? (details, didScroll) => onStart(didScroll)
          : null,
      onVerticalDragUpdate: effectiveCallbackAxis == Axis.vertical
          ? (details, wouldScroll) => onUpdate?.call(wouldScroll)
          : null,
      onVerticalDragEnd: effectiveCallbackAxis == Axis.vertical
          ? (details, willScroll) {
              onEnd?.call(willScroll);
              onEndDetails?.call(details);
            }
          : null,
      onHorizontalDragStart: effectiveCallbackAxis == Axis.horizontal
          ? (details, didScroll) => onStart(didScroll)
          : null,
      onHorizontalDragUpdate: effectiveCallbackAxis == Axis.horizontal
          ? (details, wouldScroll) => onUpdate?.call(wouldScroll)
          : null,
      onHorizontalDragEnd: effectiveCallbackAxis == Axis.horizontal
          ? (details, willScroll) {
              onEnd?.call(willScroll);
              onEndDetails?.call(details);
            }
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          onLayout?.call();
          return ListView.builder(
            controller: controller,
            scrollDirection: axis,
            reverse: reverse,
            itemExtent: 40,
            itemCount: 100,
            itemBuilder: (context, index) => const SizedBox(),
          );
        },
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 300,
        height: 300,
        child: detector,
      ),
    );
  }
}
