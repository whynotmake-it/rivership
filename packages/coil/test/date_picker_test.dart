import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  DateTime? value;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.9),
    child: SizedBox(
      width: 240,
      child: CoilDatePicker(
        value: value,
        onChanged: (day) => setState(() => value = day),
      ),
    ),
  );
}

void main() {
  testWidgets('opens a calendar, and a picked day closes it and shows', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    expect(find.text('Pick a date'), findsOneWidget);
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilCalendar), findsOneWidget);
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    expect(find.byType(CoilCalendar), findsNothing);
    final now = DateTime.now();
    expect(
      find.text(
        const CoilCalendarLabels().dateLabel(
          DateTime(now.year, now.month, 15),
          withTime: false,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Escape closes the calendar and focus returns to the field', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.byType(CoilCalendar), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CoilCalendar), findsNothing);
    expect(Focus.of(tester.element(find.text('Pick a date'))).hasFocus, isTrue);
  });

  testWidgets('on a phone the calendar opens in a sheet', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    expect(find.byType(CoilCalendar), findsOneWidget);
  });

  timeTests();
  sizingTests();
}

class _TimeDemo extends StatefulWidget {
  const _TimeDemo();

  @override
  State<_TimeDemo> createState() => _TimeDemoState();
}

class _TimeDemoState extends State<_TimeDemo> {
  DateTime? value = DateTime(2026, 11, 14, 9, 30);

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.95),
    child: SizedBox(
      width: 240,
      child: CoilDatePicker(
        value: value,
        withTime: true,
        onChanged: (v) => setState(() => value = v),
      ),
    ),
  );
}

void timeTests() {
  testWidgets('with time, a picked day keeps the time and the popup', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    tester.view.physicalSize = const Size(1200, 1600);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _TimeDemo()),
    );
    expect(find.text('November 14, 2026, 09:30'), findsOneWidget);
    await tester.tap(find.text('November 14, 2026, 09:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').first);
    await tester.pumpAndSettle();
    expect(find.byType(CoilCalendar), findsOneWidget);
    expect(find.text('November 20, 2026, 09:30'), findsOneWidget);

    // A screen reader steps the hour column.
    tester.semantics.increase(find.semantics.byLabel('Hour'));
    await tester.pumpAndSettle();
    expect(find.text('November 20, 2026, 10:30'), findsOneWidget);
  });
}

/// A phone-sized window of [size] (logical), touch tier.
void _useWindow(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = size * 2
    ..padding = FakeViewPadding.zero;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void sizingTests() {
  testWidgets('the popover hugs the calendar', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    final surface = tester.getRect(find.byType(CoilPopoverSurface));
    final calendar = tester.getRect(find.byType(CoilCalendar));
    // The content's padding (popupInset × 2) on each side, and no more.
    expect(surface.width, calendar.width + 16);
    expect(surface.height, calendar.height + 16);
  });

  testWidgets('in a phone sheet the calendar fills the width', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(CoilSheetPanel));
    final calendar = tester.getRect(find.byType(CoilCalendar));
    // The sheet's 8 px margin and the content's 12 px padding.
    expect(calendar.width, sheet.width - 2 * (8 + 12));
  });

  for (final presentation in CoilPresentation.values) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets(
        'a short landscape phone fits date and time in a '
        '${presentation.name} at text scale $scale',
        (tester) async {
          _useWindow(tester, const Size(844, 390), scale: scale);
          await tester.pumpWidget(
            testApp(
              tier: CoilTier.touch,
              presentation: presentation,
              home: const _TimeDemo(),
            ),
          );
          await tester.tap(find.byType(CoilDatePicker));
          await tester.pumpAndSettle();
          // No overflow (the test fails on one); the time sits beside the
          // calendar, and the content scrolls to its last week.
          final calendar = tester.getRect(find.byType(CoilCalendar));
          final time = tester.getRect(find.byType(CoilTimeColumns));
          expect(time.left, greaterThan(calendar.right));
          final scroll = find.descendant(
            of: find.byType(
              presentation == .sheet ? CoilSheetPanel : CoilPopoverSurface,
            ),
            matching: find.byType(SingleChildScrollView),
          );
          await tester.drag(scroll, const Offset(0, -600));
          await tester.pumpAndSettle();
          final viewport = tester.getRect(scroll);
          expect(
            tester.getRect(find.text('6').last).bottom,
            lessThanOrEqualTo(viewport.bottom),
          );
        },
      );
    }
  }

  for (final width in const [320.0, 375.0]) {
    testWidgets('a $width px phone fits date and time at text scale 2', (
      tester,
    ) async {
      _useWindow(tester, Size(width, 667), scale: 2);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _TimeDemo()),
      );
      await tester.tap(find.byType(CoilDatePicker));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(CoilSheetPanel));
      expect(
        tester.getRect(find.byType(CoilCalendar)).right,
        lessThan(sheet.right),
      );
    });
  }

  testWidgets('dragging the hour column in a sheet sets the hour', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: const _TimeDemo()),
    );
    await tester.tap(find.byType(CoilDatePicker));
    await tester.pumpAndSettle();
    final hour = find.byType(ListWheelScrollView).first;
    // 160 px up, slowly: past the touch slop that's three 44 px rows,
    // and no fling, so it lands three hours on.
    final gesture = await tester.startGesture(tester.getCenter(hour));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -8));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    // Still open, and the sheet didn't take the drag.
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('November 14, 2026, 12:30'), findsOneWidget);
  });
}
