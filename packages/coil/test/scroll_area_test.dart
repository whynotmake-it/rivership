import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';

Widget _rows(int count) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < count; i++) SizedBox(height: 32, child: Text('Row $i')),
  ],
);

Widget _app(Widget child, {CoilTier tier = CoilTier.pointer}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: tier),
    child: navigator!,
  ),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) =>
        Center(child: SizedBox(width: 200, height: 160, child: child)),
  ),
);

double _offsetOf(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  // A short area scrolled a little, so both edge fades show.
  matrixGoldenTest(
    'scroll_area',
    (context) => SizedBox(
      width: 160,
      height: 120,
      child: CoilScrollArea(
        controller: ScrollController(initialScrollOffset: 48),
        child: _rows(12),
      ),
    ),
  );

  testWidgets('scrollbar sheet: rest, hovered', (tester) async {
    Widget area() => SizedBox(
      width: 160,
      height: 120,
      child: CoilScrollArea(child: _rows(12)),
    );
    final sheet = await pumpSheet(
      tester,
      CoilTheme(
        data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
        child: ColoredBox(
          color: CoilThemeData.light.colors.background,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [area(), area()],
            ),
          ),
        ),
      ),
      surface: const Size(440, 200),
    );
    final areas = find.byType(CoilScrollArea);
    // Scroll each so its bar shows.
    for (var i = 0; i < 2; i++) {
      await tester.drag(
        areas.at(i),
        const Offset(0, -40),
        kind: PointerDeviceKind.trackpad,
      );
    }
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final second = tester.getRect(areas.at(1));
    await mouse.addPointer(location: second.center);
    await mouse.moveTo(second.centerRight - const Offset(4, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectSheetGolden(tester, sheet, 'goldens/scroll_area.png');
  });

  testWidgets('a scrolling viewport is a tab stop; keys spring it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(40))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'CoilScrollArea',
    );
    expect(
      tester.widget<CoilFocusRing>(find.byType(CoilFocusRing)).visible,
      isTrue,
      reason: 'keyboard focus shows the inset ring',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final midway = _offsetOf(tester);
    await tester.pumpAndSettle();
    expect(_offsetOf(tester), 60);
    expect(midway, inExclusiveRange(0, 60), reason: 'it springs, not jumps');

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    final max = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .maxScrollExtent;
    expect(_offsetOf(tester), max);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(_offsetOf(tester), 0);
  });

  testWidgets('content that fits is not a tab stop', (tester) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(2))));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('CoilScrollArea'),
    );
  });

  testWidgets('reduced motion makes keyboard scrolls instant', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(CoilScrollArea(child: _rows(40))),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(_offsetOf(tester), greaterThan(0));
  });

  testWidgets('.scrollable gives an existing list the same behavior', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        CoilScrollArea.scrollable(
          controller: controller,
          child: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (context, i) =>
                SizedBox(height: 32, child: Text('$i')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, 60);
  });

  testWidgets('a tap never shows the focus ring', (tester) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(40))));
    await tester.pump();
    await tester.tap(find.byType(CoilScrollArea));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoilFocusRing>(find.byType(CoilFocusRing)).visible,
      isFalse,
    );
  });

  testWidgets('a hovering mouse widens the bar; a touch never does', (
    tester,
  ) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(40))));
    await tester.drag(
      find.byType(CoilScrollArea),
      const Offset(0, -40),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.pump();
    // The painter is the scrollbar's own state; reading it is test-only.
    ScrollbarPainter painter() =>
        (tester.state(find.byType(CoilScrollbar)) as RawScrollbarState)
            // ignore: invalid_use_of_protected_member
            .scrollbarPainter;
    final area = tester.getRect(find.byType(CoilScrollArea));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: area.center);
    await mouse.moveTo(area.centerRight - const Offset(4, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 6);

    await mouse.moveTo(area.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 4);

    // Dragging the thumb with the mouse keeps it wide and darker.
    // The thumb sits near the top: the list is scrolled 40 of ~1100.
    final thumb = area.topRight + const Offset(-4, 10);
    await mouse.moveTo(thumb);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.down(thumb);
    await mouse.moveBy(const Offset(0, 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 6);
    expect(
      painter().color,
      CoilThemeData.light.colors.foreground.withValues(alpha: 0.16),
    );
    await mouse.up();
    await mouse.moveTo(area.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // A finger on the bar's spot scrolls; it never widens it.
    final finger = await tester.startGesture(
      area.centerRight - const Offset(4, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 4);
    await finger.up();
  });
}
