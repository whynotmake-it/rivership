import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

const _noDrag = ScrollDragMode.none;
const _transparent = Color(0x00000000);

/// Drags like a finger does, over many frames, and lets everything settle.
Future<void> _dragInSteps(
  WidgetTester tester,
  Finder finder,
  Offset offset, {
  Offset? from,
}) async {
  final gesture = await tester.startGesture(from ?? tester.getCenter(finder));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(offset / 10);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a draggable card on a drawer page keeps its own drags',
      (tester) async {
    final cardOffset = ValueNotifier<double>(0);
    addTearDown(cardOffset.dispose);
    var detectorUpdates = 0;
    const cardKey = ValueKey('card');

    Widget page({required bool excluding}) => Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollDragDetector(
            up: _noDrag,
            down: _noDrag,
            left: _noDrag,
            right: _noDrag,
            onHorizontalDragUpdate: (_, __) => detectorUpdates++,
            child: ColoredBox(
              color: _transparent,
              child: ValueListenableBuilder<double>(
                valueListenable: cardOffset,
                builder: (context, dx, child) => Stack(
                  children: [
                    Positioned(
                      left: 300 + dx,
                      top: 250,
                      child: ExcludeScrollDrag(
                        excluding: excluding,
                        child: GestureDetector(
                          key: cardKey,
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) =>
                              cardOffset.value += details.delta.dx,
                          child: const SizedBox(width: 100, height: 100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    // Without the exclusion the drawer takes the sideways drag.
    await tester.pumpWidget(page(excluding: false));
    await tester.drag(find.byKey(cardKey), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(cardOffset.value, 0);
    expect(detectorUpdates, greaterThan(0));

    // `excluding: false` behaves exactly like no exclusion, and switching it on
    // gives the card its drag back while the drawer stays out of it.
    detectorUpdates = 0;
    await tester.pumpWidget(page(excluding: true));
    await tester.drag(find.byKey(cardKey), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(cardOffset.value, greaterThan(0));
    expect(detectorUpdates, 0);

    // The card keeps working across several drags, and the pointer exclusion
    // does not leak into the next gesture that starts elsewhere.
    final movedOnce = cardOffset.value;
    await tester.drag(find.byKey(cardKey), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(cardOffset.value, lessThan(movedOnce));
    expect(detectorUpdates, 0);

    await _dragInSteps(
      tester,
      find.byType(ScrollDragDetector),
      const Offset(150, 0),
      from: const Offset(40, 40),
    );
    await tester.pumpAndSettle();
    expect(detectorUpdates, greaterThan(0));
  });

  testWidgets(
      'a scrollable inside an exclusion does not hand off to a sheet, '
      'and keeps scrolling normally', (tester) async {
    final plainController = ScrollController();
    final excludedController = ScrollController();
    addTearDown(plainController.dispose);
    addTearDown(excludedController.dispose);
    final starts = <bool>[];
    final updates = <bool>[];

    Widget list(ScrollController controller) => ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 50; i++)
              SizedBox(height: 50, child: Text('$i')),
          ],
        );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollDragDetector(
          up: ScrollDragMode.dragFirst,
          down: ScrollDragMode.boundaryStart,
          left: _noDrag,
          right: _noDrag,
          onVerticalDragStart: (_, didScroll) => starts.add(didScroll),
          onVerticalDragUpdate: (_, wouldScroll) => updates.add(wouldScroll),
          child: Row(
            children: [
              Expanded(child: list(plainController)),
              Expanded(
                child: ExcludeScrollDrag(child: list(excludedController)),
              ),
            ],
          ),
        ),
      ),
    );

    final plainList = find.byWidget(
      tester.widget<ListView>(find.byType(ListView).first),
    );
    final excludedList = find.byWidget(
      tester.widget<ListView>(find.byType(ListView).last),
    );

    // Pulling down at the top: the plain list hands off to the sheet.
    await _dragInSteps(tester, plainList, const Offset(0, 200));
    expect(updates, isNotEmpty);
    expect(updates, contains(true));
    expect(starts, contains(true));

    // The same pull on the excluded list reaches the sheet in no way.
    starts.clear();
    updates.clear();
    await _dragInSteps(tester, excludedList, const Offset(0, 200));
    expect(starts, isEmpty);
    expect(updates, isEmpty);
    expect(excludedController.offset, 0);

    // Dragging up: the sheet takes it first from the plain list, which does
    // not move, while the excluded list scrolls as if no sheet were there.
    updates.clear();
    await _dragInSteps(tester, plainList, const Offset(0, -200));
    expect(updates, isNotEmpty);
    expect(plainController.offset, 0);

    updates.clear();
    await _dragInSteps(tester, excludedList, const Offset(0, -200));
    expect(excludedController.offset, greaterThan(0));
    expect(updates, isEmpty);

    // It can scroll back to the top without the sheet interfering either.
    await _dragInSteps(tester, excludedList, const Offset(0, 1000));
    expect(excludedController.offset, 0);
    expect(updates, isEmpty);
  });

  testWidgets('excluding one axis leaves the other axis to the detector',
      (tester) async {
    final horizontal = <DragUpdateDetails>[];
    final vertical = <DragUpdateDetails>[];
    const insideKey = ValueKey('inside');

    Widget page({required bool excluding}) => Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollDragDetector(
            up: _noDrag,
            down: _noDrag,
            left: _noDrag,
            right: _noDrag,
            onHorizontalDragUpdate: (details, _) => horizontal.add(details),
            onVerticalDragUpdate: (details, _) => vertical.add(details),
            child: ColoredBox(
              color: _transparent,
              child: Align(
                child: ExcludeScrollDrag(
                  axes: const {Axis.horizontal},
                  excluding: excluding,
                  child: const SizedBox(
                    key: insideKey,
                    width: 200,
                    height: 200,
                    child: ColoredBox(color: _transparent),
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(page(excluding: true));

    await tester.drag(find.byKey(insideKey), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(horizontal, isEmpty);

    await tester.drag(find.byKey(insideKey), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(vertical, isNotEmpty);

    // Outside the exclusion the detector still takes sideways drags.
    await _dragInSteps(
      tester,
      find.byType(ScrollDragDetector),
      const Offset(150, 0),
      from: const Offset(40, 40),
    );
    await tester.pumpAndSettle();
    expect(horizontal, isNotEmpty);

    // Turned off, the exclusion lets sideways drags through again.
    horizontal.clear();
    await tester.pumpWidget(page(excluding: false));
    await tester.drag(find.byKey(insideKey), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(horizontal, isNotEmpty);
  });

  testWidgets(
      'an exclusion keeps out every ancestor detector but not those inside it',
      (tester) async {
    var outer = 0;
    var inner = 0;
    var deepest = 0;
    const excludedKey = ValueKey('excluded');
    const nestedKey = ValueKey('nested');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollDragDetector(
          up: _noDrag,
          down: _noDrag,
          left: _noDrag,
          right: _noDrag,
          onVerticalDragUpdate: (_, __) => outer++,
          child: ScrollDragDetector(
            up: _noDrag,
            down: _noDrag,
            left: _noDrag,
            right: _noDrag,
            onVerticalDragUpdate: (_, __) => inner++,
            child: Row(
              children: [
                const Expanded(
                  child: ExcludeScrollDrag(
                    child: SizedBox.expand(
                      key: excludedKey,
                      child: ColoredBox(color: _transparent),
                    ),
                  ),
                ),
                Expanded(
                  child: ExcludeScrollDrag(
                    child: ScrollDragDetector(
                      up: _noDrag,
                      down: _noDrag,
                      left: _noDrag,
                      right: _noDrag,
                      onVerticalDragUpdate: (_, __) => deepest++,
                      child: const SizedBox.expand(
                        key: nestedKey,
                        child: ColoredBox(color: _transparent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Neither the inner nor the outer detector sees a drag inside.
    await tester.drag(find.byKey(excludedKey), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(outer, 0);
    expect(inner, 0);

    // A detector inside the exclusion still works; only ancestors stay out.
    await tester.drag(find.byKey(nestedKey), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(deepest, greaterThan(0));
    expect(outer, 0);
    expect(inner, 0);
  });
}
