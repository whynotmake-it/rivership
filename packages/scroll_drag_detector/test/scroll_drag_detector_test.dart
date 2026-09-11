// ignore_for_file: cascade_invocations

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
      expect(position.pixels, lessThan(position.maxScrollExtent));
    },
  );

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
    this.onEnd,
    this.modes = const {},
  });

  final Axis axis;
  final bool reverse;
  final ValueChanged<bool> onStart;
  final ValueChanged<bool>? onEnd;
  final Map<AxisDirection, ScrollDragMode> modes;

  @override
  Widget build(BuildContext context) {
    final detector = ScrollDragDetector(
      up: modes[AxisDirection.up] ?? ScrollDragMode.none,
      down: modes[AxisDirection.down] ?? ScrollDragMode.none,
      left: modes[AxisDirection.left] ?? ScrollDragMode.none,
      right: modes[AxisDirection.right] ?? ScrollDragMode.none,
      onVerticalDragStart: axis == Axis.vertical
          ? (details, didScroll) => onStart(didScroll)
          : null,
      onVerticalDragEnd: axis == Axis.vertical
          ? (details, willScroll) => onEnd?.call(willScroll)
          : null,
      onHorizontalDragStart: axis == Axis.horizontal
          ? (details, didScroll) => onStart(didScroll)
          : null,
      onHorizontalDragEnd: axis == Axis.horizontal
          ? (details, willScroll) => onEnd?.call(willScroll)
          : null,
      child: ListView.builder(
        scrollDirection: axis,
        reverse: reverse,
        itemExtent: 40,
        itemCount: 100,
        itemBuilder: (context, index) => const SizedBox(),
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
