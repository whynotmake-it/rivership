import 'dart:ui';

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

class _Demo extends StatefulWidget {
  const _Demo({this.firstDate});

  final DateTime? firstDate;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  DateTime? picked = DateTime(2026, 11, 14);

  @override
  Widget build(BuildContext context) => Center(
    child: CoilCalendar(
      selected: picked,
      firstDate: widget.firstDate,
      onSelected: (day) => setState(() => picked = day),
    ),
  );
}

DateTime? _picked(WidgetTester tester) =>
    tester.state<_DemoState>(find.byType(_Demo)).picked;

void main() {
  testWidgets('shows the selected month and picks a tapped day', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    expect(find.text('November 2026'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('14')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(_picked(tester), DateTime(2026, 11, 20));
  });

  testWidgets('the arrows move a day and turn the page past the month', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    // Tab past the title and the two month buttons onto the grid.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_picked(tester), DateTime(2026, 12, 5));
    expect(find.text('December 2026'), findsOneWidget);
  });

  testWidgets('PageUp turns back a month, Shift+PageUp a year', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(find.text('October 2025'), findsOneWidget);
  });

  testWidgets('days before firstDate cannot be picked', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: _Demo(firstDate: DateTime(2026, 11, 10)),
      ),
    );
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    expect(_picked(tester), DateTime(2026, 11, 14));
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  pagingTests();
  sizingTests();
  titleTests();
  monthViewTests();
}

/// The calendar's days, laid out in the grid.
Finder _days() => find.descendant(
  of: find.byType(PageView),
  matching: find.byType(CoilHoverItem),
);

void pagingTests() {
  testWidgets('a swipe on touch turns the month, and back', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    final grid = find.byType(PageView);
    await tester.fling(grid, const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.fling(grid, const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    // A day on the page the swipe landed on picks.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(_picked(tester), DateTime(2026, 11, 20));
  });

  testWidgets('the page follows the finger and a short drag springs back', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    final grid = find.byType(PageView);
    final before = tester.getTopLeft(find.text('14').first);
    final gesture = await tester.startGesture(tester.getCenter(grid));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('14').first).dx,
      lessThan(before.dx - 30),
    );
    // Slowly back a little, then let go: not past half a page, no fling.
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(tester.getTopLeft(find.text('14').first), before);
  });

  testWidgets('a mouse drag on the pointer tier does not page', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.fling(
      find.byType(PageView),
      const Offset(-200, 0),
      1000,
      deviceKind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('a trackpad swipe pages', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(tester.getCenter(find.byType(PageView)));
    for (var i = 0; i < 10; i++) {
      await gesture.panZoomUpdate(
        tester.getCenter(find.byType(PageView)),
        pan: Offset(-20.0 * (i + 1), 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
  });

  testWidgets('the buttons and keys turn the page after a swipe', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('January 2027'), findsOneWidget);
    // One page in the tree once it settles.
    expect(_days(), findsNWidgets(42));
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    // Down from the 1st of December's focus start, then pick.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_picked(tester), DateTime(2026, 12, 8));
  });

  testWidgets('a swipe stops at firstDate', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: _Demo(firstDate: DateTime(2026, 11, 10)),
      ),
    );
    await tester.fling(find.byType(PageView), const Offset(250, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets(
    'paging plays a selection click on iOS',
    (tester) async {
      final played = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            played.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _Demo()),
      );
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(played, ['HapticFeedbackType.selectionClick']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a tap on a day ticks; Enter picks silently',
    (tester) async {
      final played = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            played.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final picked = <DateTime>[];
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Center(
            child: CoilCalendar(
              selected: DateTime(2026, 11, 14),
              autofocus: true,
              onSelected: picked.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').first);
      await tester.pumpAndSettle();
      expect(picked, [DateTime(2026, 11, 20)]);
      expect(played, isNotEmpty);

      played.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, hasLength(2));
      expect(played, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

void sizingTests() {
  for (final (width, scale) in const [
    (220.0, 1.0),
    (260.0, 2.0),
    (320.0, 2.0),
    (380.0, 1.0),
  ]) {
    testWidgets('fits $width px at text scale $scale', (tester) async {
      useScreen(tester, TestScreen.phone);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Center(
            child: SizedBox(
              width: width,
              child: CoilCalendar(
                selected: DateTime(2026, 9, 23),
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final calendar = tester.getRect(find.byType(CoilCalendar));
      expect(calendar.width, width);
      // Square days, no taller than the cell's extent at this scale: the
      // rows follow the columns inside the focus-ring inset.
      final day = tester.getSize(_days().first);
      expect(day.width, moreOrLessEquals(day.height, epsilon: 0.05));
      expect(day.height, lessThanOrEqualTo(44 - 22 + 22 * scale + 0.01));
      // The six weeks fit inside the calendar.
      expect(
        tester.getRect(_days().last).bottom,
        lessThanOrEqualTo(calendar.bottom + 0.01),
      );
    });
  }

  testWidgets('cells grow with the text scale on the pointer tier', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    final day = tester.getSize(_days().first);
    // 36 at 1×; the 20 px line box doubles.
    expect(day.height, greaterThan(50));
    expect(
      tester.getSize(find.byType(CoilCalendar)).width,
      greaterThanOrEqualTo(day.width * 7),
    );
  });

  for (final tier in CoilTier.values) {
    testWidgets('a wide space centers the calendar with square days '
        '(${tier.name})', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(1000, 1000) * 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          tier: tier,
          home: Center(
            child: SizedBox(
              width: 800,
              child: CoilCalendar(
                selected: DateTime(2026, 11, 14),
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final natural = switch (tier) {
        CoilTier.pointer => 36.0,
        CoilTier.touch => 44.0,
      };
      final grid = tester.getRect(find.byType(PageView));
      // At most 20 % past the natural cell, and centered in the 800.
      expect(grid.width, lessThanOrEqualTo(natural * 1.2 * 7 + 8));
      expect(grid.center.dx, moreOrLessEquals(500, epsilon: 0.5));
      // Every day's cell (its tap area) is square, and its fill is too.
      for (final cell in _cells().evaluate().take(7)) {
        final size = tester.getSize(find.byWidget(cell.widget));
        expect(size.width, moreOrLessEquals(size.height, epsilon: 0.05));
      }
      final fill = tester.getSize(_days().first);
      expect(fill.width, moreOrLessEquals(fill.height, epsilon: 0.05));
    });
  }

  testWidgets('every point of the grid picks a day', (tester) async {
    useScreen(tester, TestScreen.phone);
    DateTime? picked;
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: Center(
          child: SizedBox(
            width: 380,
            child: CoilCalendar(
              selected: DateTime(2026, 11, 14),
              onSelected: (day) => picked = day,
            ),
          ),
        ),
      ),
    );
    final grid = tester.getRect(find.byType(PageView));
    final cells = <RenderObject>{
      for (final cell in _cells().evaluate())
        tester.renderObject(
          find
              .descendant(
                of: find.byWidget(cell.widget),
                matching: find.byType(Listener),
              )
              .first,
        ),
    };
    // Every point, edges and the focus ring's inset included, hits a cell.
    var misses = 0;
    for (var y = grid.top + 0.5; y < grid.bottom; y += 1) {
      for (var x = grid.left + 0.5; x < grid.right; x += 1) {
        final result = HitTestResult();
        RendererBinding.instance.hitTestInView(
          result,
          Offset(x, y),
          tester.view.viewId,
        );
        if (!result.path.any((entry) => cells.contains(entry.target))) {
          misses++;
        }
      }
    }
    expect(misses, 0);

    // A real tap in a cell's corner, outside its fill, picks its day; so
    // does one in the inset at the grid's edge.
    final cell = tester.getRect(
      find.byWidget(_cells().evaluate().elementAt(19).widget),
    );
    for (final corner in [
      cell.topLeft + const Offset(1, 1),
      cell.bottomRight - const Offset(1, 1),
    ]) {
      picked = null;
      await tester.tapAt(corner);
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 11, 14));
    }
    picked = null;
    await tester.tapAt(Offset(grid.left + 0.5, cell.center.dy));
    await tester.pumpAndSettle();
    // November 2026 starts on a Sunday: Monday the 9th leads row three.
    expect(picked, DateTime(2026, 11, 9));
  });
}

/// Each day's whole cell, the area that takes its tap.
Finder _cells() => find.descendant(
  of: find.byType(PageView),
  matching: find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_Day',
  ),
);

/// A calendar for the month view's tests, picking into `picked`.
class _MonthsDemo extends StatefulWidget {
  const _MonthsDemo({
    this.firstDate,
    this.lastDate,
    this.direction = TextDirection.ltr,
  });

  final DateTime? firstDate;
  final DateTime? lastDate;
  final TextDirection direction;

  @override
  State<_MonthsDemo> createState() => _MonthsDemoState();
}

class _MonthsDemoState extends State<_MonthsDemo> {
  DateTime? picked = DateTime(2026, 11, 14);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: widget.direction,
    child: Center(
      child: CoilCalendar(
        selected: picked,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        onSelected: (day) => setState(() => picked = day),
      ),
    ),
  );
}

/// The month view's list of years.
Finder _years() => find.descendant(
  of: find.byType(CoilCalendar),
  matching: find.byType(ListView),
);

/// The visible years' headings, as numbers.
List<int> _visibleYears(WidgetTester tester) {
  final list = tester.getRect(_years());
  return [
    for (final element
        in find
            .descendant(of: _years(), matching: find.byType(Text))
            .evaluate())
      if (int.tryParse((element.widget as Text).data ?? '') case final year?
          when list.overlaps(tester.getRect(find.byWidget(element.widget))))
        year,
  ];
}

bool _enabledMonth(WidgetTester tester, String label) =>
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .flagsCollection
        .isEnabled ==
    Tristate.isTrue;

void titleTests() {
  testWidgets('the title follows the page mid-swipe', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    final grid = find.byType(PageView);
    final width = tester.getSize(grid).width;
    final gesture = await tester.startGesture(tester.getCenter(grid));
    Future<void> moveTo(double fraction, double from) async {
      const steps = 10;
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(-(fraction - from) * width / steps, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Past the slop and under half a page: still November.
    await gesture.moveBy(const Offset(-kTouchSlop - 1, 0));
    await moveTo(0.4, 0);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('December 2026'), findsNothing);
    // Past half a page, with the finger still down: December.
    await moveTo(0.6, 0.4);
    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('November 2026'), findsNothing);
    // Back under half: November again.
    await moveTo(0.3, 0.6);
    expect(find.text('November 2026'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('the title blur-fades between months', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.tap(find.bySemanticsLabel('Next month'));
    // Halfway through the page turn both titles are in the switcher, the
    // old one leaving.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('December 2026'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('December 2026'),
        matching: find.byType(CoilBlurFade),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsNothing);
  });
}

void monthViewTests() {
  testWidgets('the title zooms out to the months, and a month zooms back', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _MonthsDemo()),
    );
    final title = find.bySemanticsLabel('November 2026');
    expect(
      tester.getSemantics(title).flagsCollection.isExpanded,
      Tristate.isFalse,
    );
    expect(find.semantics.byLabel('Saturday, November 14, 2026'), findsOne);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(_years(), findsOneWidget);
    // The shown month's year opens in the middle of the list.
    final list = tester.getRect(_years());
    final heading = tester.getRect(find.text('2026'));
    expect(heading.top, greaterThan(list.top));
    expect(heading.top, lessThan(list.center.dy));
    expect(_visibleYears(tester), contains(2026));
    // The picked month reads as selected.
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('November 2026').last)
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    // The days take no taps, focus or semantics while hidden.
    expect(find.semantics.byLabel('Saturday, November 14, 2026'), findsNothing);

    await tester.tap(find.bySemanticsLabel('March 2026'));
    await tester.pumpAndSettle();
    expect(_years(), findsNothing);
    expect(find.text('March 2026'), findsOneWidget);
    await tester.tap(find.text('31').first);
    expect(
      tester.state<_MonthsDemoState>(find.byType(_MonthsDemo)).picked,
      DateTime(2026, 3, 31),
    );
  });

  testWidgets('the month view scrolls through the years', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _MonthsDemo()),
    );
    await tester.tap(find.bySemanticsLabel('November 2026'));
    await tester.pumpAndSettle();
    final sectionHeight =
        tester.getRect(find.text('2027')).top -
        tester.getRect(find.text('2026')).top;
    // Up through the years with a mouse wheel, as a list scrolls.
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(_years()),
        scrollDelta: Offset(0, -sectionHeight * 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(_visibleYears(tester), contains(2022));
    expect(_visibleYears(tester), isNot(contains(2026)));
    // And down by dragging.
    await tester.drag(_years(), Offset(0, -sectionHeight * 8));
    await tester.pumpAndSettle();
    expect(_visibleYears(tester), contains(2030));
    await tester.tap(find.bySemanticsLabel('June 2030'));
    await tester.pumpAndSettle();
    expect(find.text('June 2030'), findsOneWidget);
  });

  testWidgets('firstDate and lastDate bound the years and months', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: _MonthsDemo(
          firstDate: DateTime(2026, 11, 10),
          lastDate: DateTime(2027, 2, 15),
        ),
      ),
    );
    // Open it from the keyboard: Tab onto the title, then Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_visibleYears(tester), [2026, 2027]);
    expect(_enabledMonth(tester, 'October 2026'), isFalse);
    expect(_enabledMonth(tester, 'December 2026'), isTrue);
    expect(_enabledMonth(tester, 'February 2027'), isTrue);
    expect(_enabledMonth(tester, 'March 2027'), isFalse);
    // A dimmed month takes no tap.
    await tester.tap(find.bySemanticsLabel('October 2026'));
    await tester.pumpAndSettle();
    expect(_years(), findsOneWidget);
    // The keyboard stops at the ends.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('February 2027'), findsOneWidget);
  });

  testWidgets('keys: arrows, PageUp/PageDown, Enter and Escape', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _MonthsDemo()),
    );
    // Tab onto the title and open it with Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_years(), findsOneWidget);
    // Escape goes back to the days and keeps the month.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_years(), findsNothing);
    expect(find.text('November 2026'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_years(), findsOneWidget);
    // November → December → March → March a year back → April.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_years(), findsNothing);
    expect(find.text('April 2026'), findsOneWidget);
    // The grid has the keyboard again: Enter picks a day there.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester.state<_MonthsDemoState>(find.byType(_MonthsDemo)).picked?.month,
      4,
    );
  });

  testWidgets('right to left, the months and the arrows mirror', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: const _MonthsDemo(direction: TextDirection.rtl),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final jan = tester.getCenter(find.bySemanticsLabel('January 2026'));
    final feb = tester.getCenter(find.bySemanticsLabel('February 2026'));
    expect(jan.dx, greaterThan(feb.dx));
    // Left is forward in right-to-left.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    // The title stays at the start: the right edge.
    final calendar = tester.getRect(find.byType(CoilCalendar));
    expect(
      tester.getRect(find.text('December 2026')).right,
      greaterThan(calendar.center.dx),
    );
  });

  for (final width in const [260.0, 320.0]) {
    testWidgets('the month view fits $width px at text scale 2', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: Center(
            child: SizedBox(
              width: width,
              child: CoilCalendar(
                selected: DateTime(2026, 9, 14),
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      // The title fits next to the arrows (an overflow fails the test).
      await tester.tap(find.bySemanticsLabel('September 2026'));
      await tester.pumpAndSettle();
      expect(_years(), findsOneWidget);
      final list = tester.getRect(_years());
      expect(list.width, lessThanOrEqualTo(width));
      final sep = tester.getRect(find.bySemanticsLabel('September 2026').last);
      expect(sep.width, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion zooms with a fade only', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: testApp(tier: CoilTier.pointer, home: const _MonthsDemo()),
      ),
    );
    await tester.tap(find.bySemanticsLabel('November 2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // No scale: every transform in the zoom is the identity.
    final scales = tester
        .widgetList<Transform>(
          find.ancestor(of: _years(), matching: find.byType(Transform)),
        )
        .map((t) => t.transform.getMaxScaleOnAxis());
    expect(scales, everyElement(1));
    await tester.pumpAndSettle();
  });
}
