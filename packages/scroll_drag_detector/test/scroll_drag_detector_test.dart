// ignore_for_file: cascade_invocations

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

void main() {
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

  group('inherited scroll behavior', () {
    test('compares matching parent delegates safely', () {
      const behavior = ScrollDragBehavior(
        parent: _TypedScrollBehavior(ClampingScrollPhysics()),
      );
      expect(behavior.shouldNotify(const ScrollBehavior()), isTrue);
      expect(behavior.shouldNotify(behavior), isFalse);
      expect(
        behavior.shouldNotify(
          const ScrollDragBehavior(
            parent: _TypedScrollBehavior(BouncingScrollPhysics()),
          ),
        ),
        isTrue,
      );
      expect(
        behavior.shouldNotify(
          ScrollDragBehavior(parent: const ScrollBehavior().copyWith()),
        ),
        isTrue,
      );
    });

    testWidgets('delegates consumer settings outside a detector',
        (tester) async {
      const child = SizedBox();
      final behavior = const ScrollDragBehavior(
        parent: _TypedScrollBehavior(ClampingScrollPhysics()),
      ).copyWith(
        scrollbars: false,
        overscroll: false,
        physics: const BouncingScrollPhysics(),
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        pointerAxisModifiers: {LogicalKeyboardKey.controlLeft},
        multitouchDragStrategy: MultitouchDragStrategy.sumAllPointers,
        platform: TargetPlatform.iOS,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      );
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: child,
        ),
      );
      final context = tester.element(find.byWidget(child));
      expect(behavior.getScrollPhysics(context), isA<BouncingScrollPhysics>());
      expect(
        behavior.dragDevices,
        {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      );
      expect(behavior.pointerAxisModifiers, {LogicalKeyboardKey.controlLeft});
      expect(behavior.getPlatform(context), TargetPlatform.iOS);
      expect(
        behavior.getMultitouchDragStrategy(context),
        MultitouchDragStrategy.sumAllPointers,
      );
      expect(
        behavior.getKeyboardDismissBehavior(context),
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
      const details = ScrollableDetails(direction: AxisDirection.down);
      expect(behavior.buildScrollbar(context, child, details), same(child));
      expect(
        behavior.buildOverscrollIndicator(context, child, details),
        same(child),
      );
    });

    for (final inherited in [false, true]) {
      testWidgets('child override inherited=$inherited preserves drag first',
          (tester) async {
        final starts = <bool>[];
        await tester.pumpWidget(
          _TestScrollable(
            axis: Axis.vertical,
            reverse: false,
            modes: const {AxisDirection.up: ScrollDragMode.dragFirst},
            onStart: starts.add,
            scrollBehavior: const ScrollDragBehavior(
              parent: ScrollBehavior(),
            ).copyWith(physics: const BouncingScrollPhysics()),
            inheritScrollBehavior: inherited,
          ),
        );

        final scrollable = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(400);
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(tester.getCenter(scrollable));
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();

        expect(starts, contains(true));
        expect(tester.state<ScrollableState>(scrollable).position.pixels, 400);

        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          lessThan(400),
        );
        await gesture.up();
        expect(tester.takeException(), isNull);
      });

      testWidgets('child override inherited=$inherited preserves handoff',
          (tester) async {
        final starts = <bool>[];
        await tester.pumpWidget(
          _TestScrollable(
            axis: Axis.vertical,
            reverse: false,
            modes: const {AxisDirection.down: ScrollDragMode.scrollFirst},
            onStart: starts.add,
            scrollBehavior: const ScrollDragBehavior(
              parent: ScrollBehavior(),
            ).copyWith(physics: const ClampingScrollPhysics()),
            inheritScrollBehavior: inherited,
          ),
        );

        final scrollable = find.byType(Scrollable);
        final gesture = await tester.startGesture(tester.getCenter(scrollable));
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump();
        }
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(0),
        );
        expect(starts, isEmpty);

        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump();
        }
        expect(starts, contains(true));
        expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);

        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump();
        }
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(0),
        );
        await gesture.up();
        expect(tester.takeException(), isNull);
      });
    }

    for (final mode in [
      ScrollDragMode.dragFirst,
      ScrollDragMode.boundaryStart,
    ]) {
      testWidgets('$mode hands off with a copied behavior', (tester) async {
        final starts = <bool>[];
        await tester.pumpWidget(
          ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: _TestScrollable(
              axis: Axis.vertical,
              reverse: false,
              modes: {AxisDirection.down: mode},
              onStart: starts.add,
            ),
          ),
        );

        final scrollable = find.byType(Scrollable);
        await tester.drag(scrollable, const Offset(0, 120));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(starts, isNotEmpty);
        expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);

        await tester.drag(scrollable, const Offset(0, -120));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(0),
        );
      });
    }

    testWidgets('updates physics across parent behavior types', (tester) async {
      for (final (behavior, physicsMatcher) in [
        (
          const ScrollBehavior().copyWith(
            physics: const ClampingScrollPhysics(),
          ),
          isA<ClampingScrollPhysics>(),
        ),
        (
          const _TypedScrollBehavior(ClampingScrollPhysics()),
          isA<ClampingScrollPhysics>(),
        ),
        (
          const _TypedScrollBehavior(BouncingScrollPhysics()),
          isA<BouncingScrollPhysics>(),
        ),
        (
          const ScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          isA<BouncingScrollPhysics>(),
        ),
      ]) {
        await tester.pumpWidget(
          ScrollConfiguration(
            behavior: behavior,
            child: _TestScrollable(
              axis: Axis.vertical,
              reverse: false,
              modes: const {AxisDirection.up: ScrollDragMode.dragFirst},
              onStart: (_) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        var physics = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .physics;
        while (physics.parent != null) {
          physics = physics.parent!;
        }
        expect(physics, physicsMatcher);
      }
    });
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

class _TypedScrollBehavior extends ScrollBehavior {
  const _TypedScrollBehavior(this.physics);

  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;

  @override
  bool shouldNotify(covariant _TypedScrollBehavior oldDelegate) =>
      physics != oldDelegate.physics;
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
    this.scrollBehavior,
    this.inheritScrollBehavior = false,
    this.modes = const {},
  });

  final Axis axis;
  final Axis? callbackAxis;
  final ScrollBehavior? scrollBehavior;
  final bool inheritScrollBehavior;
  final bool reverse;
  final ValueChanged<bool> onStart;
  final ValueChanged<bool>? onUpdate;
  final ValueChanged<bool>? onEnd;
  final ValueChanged<DragEndDetails>? onEndDetails;
  final Map<AxisDirection, ScrollDragMode> modes;

  @override
  Widget build(BuildContext context) {
    final effectiveCallbackAxis = callbackAxis ?? axis;
    final scrollable = !inheritScrollBehavior && scrollBehavior != null
        ? CustomScrollView(
            scrollBehavior: scrollBehavior,
            scrollDirection: axis,
            reverse: reverse,
            slivers: [
              SliverFixedExtentList(
                itemExtent: 40,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const SizedBox(),
                  childCount: 100,
                ),
              ),
            ],
          )
        : ListView.builder(
            scrollDirection: axis,
            reverse: reverse,
            itemExtent: 40,
            itemCount: 100,
            itemBuilder: (context, index) => const SizedBox(),
          );
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
      child: inheritScrollBehavior && scrollBehavior != null
          ? ScrollConfiguration(behavior: scrollBehavior!, child: scrollable)
          : scrollable,
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
