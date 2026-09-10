import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

void main() {
  group('ScrollDragHandoff', () {
    test('exposes disabled, edge, and before-scroll modes', () {
      expect(
        ScrollDragHandoff.values,
        containsAll(<ScrollDragHandoff>[
          ScrollDragHandoff.none,
          ScrollDragHandoff.edge,
          ScrollDragHandoff.beforeScroll,
        ]),
      );
    });
  });

  group('leading-edge handoff', () {
    for (final (axis, reverse, delta) in [
      (Axis.vertical, false, const Offset(0, 120)),
      (Axis.vertical, true, const Offset(0, -120)),
      (Axis.horizontal, false, const Offset(120, 0)),
      (Axis.horizontal, true, const Offset(-120, 0)),
    ]) {
      testWidgets(
        '$axis ${reverse ? 'reverse' : 'forward'} uses the leading edge',
        (tester) async {
          final starts = <bool>[];
          await tester.pumpWidget(
            _TestScrollable(
              axis: axis,
              reverse: reverse,
              leadingEdgeHandoff: ScrollDragHandoff.edge,
              trailingEdgeHandoff: ScrollDragHandoff.none,
              onStart: starts.add,
            ),
          );

          final scrollable = find.byType(Scrollable);
          final gesture = await tester.startGesture(
            tester.getCenter(scrollable),
          );
          await gesture.moveBy(delta);
          await tester.pump();
          await gesture.up();

          expect(starts, contains(true));
        },
      );
    }
  });

  testWidgets(
    'leading-edge overscroll settles after the drag ends',
    (tester) async {
      await tester.pumpWidget(
        _TestScrollable(
          axis: Axis.vertical,
          reverse: false,
          scrollBehavior: const CupertinoScrollBehavior(),
          leadingEdgeHandoff: ScrollDragHandoff.edge,
          trailingEdgeHandoff: ScrollDragHandoff.none,
          onStart: (_) {},
        ),
      );

      final scrollable = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scrollable).position;
      final gesture = await tester.startGesture(tester.getCenter(scrollable));
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }

      expect(position.pixels, lessThan(position.minScrollExtent));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));

      expect(position.pixels, position.minScrollExtent);
    },
  );

  testWidgets(
    'edge handoff can scroll to the trailing edge before taking over',
    (tester) async {
      final starts = <bool>[];
      final ends = <bool>[];
      await tester.pumpWidget(
        _TestScrollable(
          axis: Axis.vertical,
          reverse: false,
          leadingEdgeHandoff: ScrollDragHandoff.none,
          trailingEdgeHandoff: ScrollDragHandoff.edge,
          onlyDragWhenScrollWasAtTrailingEdge: false,
          onStart: starts.add,
          onEnd: ends.add,
        ),
      );

      final scrollable = find.byType(Scrollable);
      final gesture = await tester.startGesture(tester.getCenter(scrollable));
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
      }
      final position = tester.state<ScrollableState>(scrollable).position;

      expect(position.pixels, position.maxScrollExtent);
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
}

class _TestScrollable extends StatelessWidget {
  const _TestScrollable({
    required this.axis,
    required this.reverse,
    this.scrollBehavior,
    required this.leadingEdgeHandoff,
    required this.trailingEdgeHandoff,
    required this.onStart,
    this.onEnd,
    this.onlyDragWhenScrollWasAtTrailingEdge = true,
  });

  final Axis axis;
  final bool reverse;
  final ScrollBehavior? scrollBehavior;
  final ScrollDragHandoff leadingEdgeHandoff;
  final ScrollDragHandoff trailingEdgeHandoff;
  final ValueChanged<bool> onStart;
  final ValueChanged<bool>? onEnd;
  final bool onlyDragWhenScrollWasAtTrailingEdge;

  @override
  Widget build(BuildContext context) {
    final detector = ScrollDragDetector(
      leadingEdgeHandoff: leadingEdgeHandoff,
      trailingEdgeHandoff: trailingEdgeHandoff,
      onlyDragWhenScrollWasAtTrailingEdge: onlyDragWhenScrollWasAtTrailingEdge,
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
        child: scrollBehavior == null
            ? detector
            : ScrollConfiguration(
                behavior: scrollBehavior!,
                child: detector,
              ),
      ),
    );
  }
}
