import 'dart:ui';

import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  sheetGestureTests();
  confirmTests();
  monthViewSheetTests();
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
    // The day applies at once; the popup stays for the time.
    expect(find.byType(CoilCalendar), findsOneWidget);
    expect(find.text('November 20, 2026, 09:30'), findsOneWidget);

    // A screen reader steps the hour column.
    tester.semantics.increase(find.semantics.byLabel('Hour'));
    await tester.pumpAndSettle();
    expect(find.text('November 20, 2026, 10:30'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CoilCalendar), findsNothing);
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

  testWidgets('in a phone sheet the days fill the width, on one edge with '
      'the month title and the footer', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _Demo()));
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    // A day's cell: its column, which takes its taps.
    final days = find.descendant(
      of: find.byType(PageView),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_Day',
      ),
    );
    final first = tester.getRect(days.first);
    final title = tester.getRect(
      find
          .descendant(
            of: find.byType(CoilCalendar),
            matching: find.textContaining(RegExp(r'\d{4}')),
          )
          .first,
    );
    final done = tester.getRect(find.widgetWithText(CoilButton, 'Done'));
    // The month title's text starts where the first day starts, and Done
    // ends where the last day ends, mirrored about the sheet's middle.
    final sheet = tester.getRect(find.byType(CoilSheetPanel));
    expect(title.left, moreOrLessEquals(first.left, epsilon: 1));
    expect(
      sheet.right - done.right,
      moreOrLessEquals(first.left - sheet.left, epsilon: 1),
    );
  });

  testWidgets('a wide sheet centers the calendar and time at their widest', (
    tester,
  ) async {
    _useWindow(tester, const Size(834, 1194));
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        presentation: CoilPresentation.sheet,
        home: const _TimeDemo(),
      ),
    );
    await tester.tap(find.byType(CoilDatePicker));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(CoilSheetPanel));
    final grid = tester.getRect(find.byType(PageView));
    final time = tester.getRect(find.byType(CoilTimeColumns));
    // Days 30 % past the 44 touch cell at most, so the 560 sheet doesn't
    // stretch them; the time band spans the days, inside the calendar's
    // focus-ring room.
    expect(grid.width, lessThanOrEqualTo(44 * 1.3 * 7 + 8));
    expect(grid.center.dx, moreOrLessEquals(sheet.center.dx, epsilon: 0.5));
    expect(time.width, moreOrLessEquals(grid.width - 6, epsilon: 0.5));
    expect(time.center.dx, moreOrLessEquals(sheet.center.dx, epsilon: 0.5));
    // Square rows: six of them as tall as the columns are wide.
    expect(grid.height, moreOrLessEquals((grid.width - 6) * 6 / 7, epsilon: 6));
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
          final scroll = find
              .descendant(
                of: find.byType(
                  presentation == .popover
                      ? CoilPopoverSurface
                      : CoilSheetPanel,
                ),
                matching: find.byType(SingleChildScrollView),
              )
              .first;
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

  testWidgets('a short desktop window keeps the time under the calendar', (
    tester,
  ) async {
    _useWindow(tester, const Size(900, 500));
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _TimeDemo()),
    );
    await tester.tap(find.byType(CoilDatePicker));
    await tester.pumpAndSettle();
    final calendar = tester.getRect(find.byType(CoilCalendar));
    final time = tester.getRect(find.byType(CoilTimeColumns));
    expect(time.top, greaterThan(calendar.bottom));
  });

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
    // Up, slowly: past the touch slop that's three rows, and no fling, so
    // it lands three hours on.
    final row = tester.getSize(hour).height / CoilTimeColumns.visibleRows;
    final gesture = await tester.startGesture(tester.getCenter(hour));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(0, -(kTouchSlop + row * 3) / 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    // Still open, and the sheet didn't take the drag.
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('November 14, 2026, 12:30'), findsOneWidget);
  });
}

/// Every gesture the owner tried on the picker in a phone sheet: none may
/// throw, and none of them closes the sheet.
void sheetGestureTests() {
  for (final platform in const [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final withTime in const [false, true]) {
      for (final short in const [false, true]) {
        testWidgets(
          'gestures in a phone sheet under a wrapped scroll behavior '
          '(${platform.name}, ${withTime ? 'date and time' : 'date'}'
          '${short ? ', short window' : ''})',
          (tester) async {
            debugDefaultTargetPlatformOverride = platform;
            if (short) {
              _useWindow(tester, const Size(390, 520));
            } else {
              useScreen(tester, TestScreen.phone);
            }
            await tester.pumpWidget(
              testApp(
                tier: CoilTier.touch,
                // The example's shell (and an app's scrollbar setting)
                // hands routes a `ScrollConfiguration.copyWith` behavior,
                // which the sheet's drag detector swaps during a drag.
                wrappedScrollBehavior: true,
                home: withTime ? const _TimeDemo() : const _Demo(),
              ),
            );
            await tester.tap(find.byType(CoilDatePicker));
            await tester.pumpAndSettle();

            Future<void> drag(Finder target, Offset by) async {
              final gesture = await tester.startGesture(
                tester.getCenter(target),
              );
              for (var i = 0; i < 12; i++) {
                await gesture.moveBy(by / 12);
                await tester.pump(const Duration(milliseconds: 16));
              }
              await gesture.up();
              await tester.pumpAndSettle();
              expect(find.byType(CoilSheetPanel), findsOneWidget);
            }

            final grid = find.byType(PageView);
            await drag(grid, const Offset(-200, 0));
            await drag(grid, const Offset(200, 0));
            await drag(grid, const Offset(0, -200));
            await drag(grid, const Offset(140, -140));
            // A short pull down hands off to the sheet and springs back.
            await drag(grid, const Offset(0, 40));
            await tester.fling(grid, const Offset(-200, 0), 2000);
            await tester.pumpAndSettle();
            if (withTime) {
              final hours = find.byType(ListWheelScrollView).first;
              await drag(hours, const Offset(0, -120));
              await drag(hours, const Offset(0, 120));
              await tester.fling(hours, const Offset(0, -150), 2500);
              await tester.pumpAndSettle();
            }
            final content = find.descendant(
              of: find.byType(CoilSheetPanel),
              matching: find.byType(SingleChildScrollView),
            );
            await drag(content.first, const Offset(0, -150));
            await drag(content.first, const Offset(0, 40));
            expect(tester.takeException(), isNull);
            // The binding checks this before tear-downs run.
            debugDefaultTargetPlatformOverride = null;
          },
        );
      }
    }
  }
}

/// A picker that records every value it's handed.
class _ConfirmDemo extends StatefulWidget {
  const _ConfirmDemo({this.withTime = false, this.initial});

  final bool withTime;
  final DateTime? initial;

  @override
  State<_ConfirmDemo> createState() => _ConfirmDemoState();
}

class _ConfirmDemoState extends State<_ConfirmDemo> {
  late DateTime? value = widget.initial;
  final changes = <DateTime>[];

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.95),
    child: SizedBox(
      width: 240,
      child: CoilDatePicker(
        value: value,
        withTime: widget.withTime,
        sheetTitle: const Text('Due'),
        onChanged: (v) => setState(() {
          value = v;
          changes.add(v);
        }),
      ),
    ),
  );
}

List<DateTime> _changes(WidgetTester tester) =>
    tester.state<_ConfirmDemoState>(find.byType(_ConfirmDemo)).changes;

/// Opens a [_ConfirmDemo] on a phone sheet or a desktop popover.
Future<void> _openConfirmDemo(
  WidgetTester tester, {
  required CoilPresentation presentation,
  bool withTime = false,
}) async {
  final sheet = presentation == CoilPresentation.sheet;
  if (sheet) {
    useScreen(tester, TestScreen.phone);
  } else {
    useScreen(tester, TestScreen.desktop);
    tester.view.physicalSize = const Size(1200, 1600);
  }
  await tester.pumpWidget(
    testApp(
      tier: sheet ? CoilTier.touch : CoilTier.pointer,
      presentation: presentation,
      home: _ConfirmDemo(
        withTime: withTime,
        initial: DateTime(2026, 11, 14, 9, 30),
      ),
    ),
  );
  await tester.tap(find.byType(CoilDatePicker));
  await tester.pumpAndSettle();
}

/// Whether [day] of the shown month reads as selected to screen readers.
bool _isSelected(WidgetTester tester, String day) =>
    tester
        .getSemantics(
          find
              .descendant(
                of: find.byType(PageView),
                matching: find.text(day),
              )
              .first,
        )
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

void confirmTests() {
  group('sheet', () {
    testWidgets('a picked day is a draft until Done', (tester) async {
      await _openConfirmDemo(tester, presentation: .sheet);
      await tester.tap(find.text('20').first);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsOneWidget);
      expect(_isSelected(tester, '20'), isTrue);
      expect(_changes(tester), isEmpty);
      // The footer is pinned under the calendar.
      final done = tester.getRect(find.widgetWithText(CoilButton, 'Done'));
      final calendar = tester.getRect(find.byType(CoilCalendar));
      expect(done.top, greaterThan(calendar.bottom));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(_changes(tester), [DateTime(2026, 11, 20)]);
    });

    final dismissals = <String, Future<void> Function(WidgetTester)>{
      'the close button': (tester) =>
          tester.tap(find.byType(CoilSheetCloseButton)),
      'the scrim': (tester) => tester.tapAt(const Offset(20, 20)),
      'a drag down': (tester) => tester.fling(
        find.text('Due'),
        const Offset(0, 500),
        2000,
      ),
      'back': (tester) => tester.binding.handlePopRoute(),
      'Escape': (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape),
    };
    for (final MapEntry(key: name, value: dismiss) in dismissals.entries) {
      testWidgets('$name cancels the draft', (tester) async {
        await _openConfirmDemo(tester, presentation: .sheet, withTime: true);
        await tester.tap(find.text('20').first);
        await tester.pumpAndSettle();
        await dismiss(tester);
        await tester.pumpAndSettle();
        expect(find.byType(CoilSheetPanel), findsNothing);
        expect(_changes(tester), isEmpty);
        expect(find.text('November 14, 2026, 09:30'), findsOneWidget);
        // Opening again starts from the value, not the old draft.
        await tester.tap(find.byType(CoilDatePicker));
        await tester.pumpAndSettle();
        expect(_isSelected(tester, '14'), isTrue);
        expect(_isSelected(tester, '20'), isFalse);
      });
    }

    testWidgets('Done waits for a pick when there is no value', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _ConfirmDemo()),
      );
      await tester.tap(find.byType(CoilDatePicker));
      await tester.pumpAndSettle();
      final done = find.widgetWithText(CoilButton, 'Done');
      expect(tester.widget<CoilButton>(done).onPressed, isNull);
      await tester.tap(find.text('20').first);
      await tester.pump();
      expect(tester.widget<CoilButton>(done).onPressed, isNotNull);
    });

    testWidgets('Enter on the grid picks the day and confirms', (
      tester,
    ) async {
      await _openConfirmDemo(tester, presentation: .sheet, withTime: true);
      // The grid has focus as the sheet opens; the keyboard moves a day.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(_changes(tester), [DateTime(2026, 11, 15, 9, 30)]);
    });
  });

  group('popover', () {
    testWidgets('a day alone commits on the tap and closes', (tester) async {
      await _openConfirmDemo(tester, presentation: .popover);
      expect(find.text('Done'), findsNothing);
      await tester.tap(find.text('20').first);
      await tester.pumpAndSettle();
      expect(find.byType(CoilCalendar), findsNothing);
      expect(_changes(tester), [DateTime(2026, 11, 20)]);
    });

    testWidgets('Enter on the grid commits once and closes', (tester) async {
      await _openConfirmDemo(tester, presentation: .popover);
      // The grid takes focus as the popover opens.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(CoilCalendar), findsNothing);
      expect(_changes(tester), [DateTime(2026, 11, 21)]);
    });

    testWidgets('with time, each pick applies at once and closing keeps it', (
      tester,
    ) async {
      await _openConfirmDemo(tester, presentation: .popover, withTime: true);
      // No Done: the field follows each pick while the popover stays open.
      expect(find.text('Done'), findsNothing);
      await tester.tap(find.text('20').first);
      await tester.pumpAndSettle();
      expect(find.byType(CoilCalendar), findsOneWidget);
      expect(find.text('November 20, 2026, 09:30'), findsOneWidget);
      // Tab from the grid to the hour column and step it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('November 20, 2026, 10:30'), findsOneWidget);
      expect(_changes(tester), [
        DateTime(2026, 11, 20, 9, 30),
        DateTime(2026, 11, 20, 10, 30),
      ]);

      // A tap outside closes it with what's picked; so does Escape.
      await tester.tapAt(const Offset(1, 790));
      await tester.pumpAndSettle();
      expect(find.byType(CoilCalendar), findsNothing);
      expect(find.text('November 20, 2026, 10:30'), findsOneWidget);
      await tester.tap(find.byType(CoilDatePicker));
      await tester.pumpAndSettle();
      expect(_isSelected(tester, '20'), isTrue);
      await tester.tap(find.text('22').first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(CoilCalendar), findsNothing);
      expect(_changes(tester).last, DateTime(2026, 11, 22, 10, 30));
      expect(find.text('November 22, 2026, 10:30'), findsOneWidget);
    });
  });

  testWidgets('the month view picks a month in the sheet', (tester) async {
    await _openConfirmDemo(tester, presentation: .sheet);
    await tester.tap(find.bySemanticsLabel('November 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Mar'), findsWidgets);
    // Escape goes back to the days, and the sheet stays.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    expect(find.text('Mar'), findsNothing);

    await tester.tap(find.bySemanticsLabel('November 2026'));
    await tester.pumpAndSettle();
    // The years page on in the sheet, which stays.
    final years = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'CalendarMonthView',
      ),
      matching: find.byType(PageView),
    );
    await tester.fling(years, const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('March 2027'));
    await tester.pumpAndSettle();
    expect(find.text('March 2027'), findsOneWidget);
    expect(find.text('Mar'), findsNothing);
    await tester.tap(find.text('17').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_changes(tester), [DateTime(2027, 3, 17)]);
  });
}

void monthViewSheetTests() {
  testWidgets('in a sheet, a drag down on the months moves the sheet, and '
      'the footer names the draft', (tester) async {
    await _openConfirmDemo(tester, presentation: .sheet);
    // A draft pick, then out to the months and two years back.
    await tester.tap(find.text('20').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('November 2026'));
    await tester.pumpAndSettle();
    final years = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'CalendarMonthView',
      ),
      matching: find.byType(PageView),
    );
    for (var i = 0; i < 2; i++) {
      await tester.fling(years, const Offset(250, 0), 1000);
      await tester.pumpAndSettle();
    }
    expect(find.text('2024'), findsOneWidget);

    // A slow drag down on the months takes the sheet with the finger.
    final sheet = find.byType(CoilSheetPanel);
    final top = tester.getRect(sheet).top;
    final gesture = await tester.startGesture(tester.getCenter(years));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getRect(sheet).top, greaterThan(top));
    // Let go after a pause: it springs back, on the same year.
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(sheet).top, top);
    expect(find.text('2024'), findsOneWidget);

    // Years from the draft, the footer still names it.
    expect(
      find.bySemanticsLabel('Selected: Friday, November 20, 2026'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_changes(tester), [DateTime(2026, 11, 20)]);
  });

  testWidgets('the footer follows the draft wherever the calendar goes, and '
      'Done confirms what it says', (tester) async {
    await _openConfirmDemo(tester, presentation: .sheet, withTime: true);
    Finder footer(String label) => find.bySemanticsLabel('Selected: $label');
    // It opens on the value.
    expect(footer('Saturday, November 14, 2026, 09:30'), findsOneWidget);

    // A day and an hour: the footer follows the draft, the field doesn't.
    await tester.tap(find.text('20').first);
    await tester.pumpAndSettle();
    tester.semantics.increase(find.semantics.byLabel('Hour'));
    await tester.pumpAndSettle();
    expect(footer('Friday, November 20, 2026, 10:30'), findsOneWidget);
    expect(find.text('November 14, 2026, 09:30'), findsOneWidget);

    // Months on, then zoomed out and years back: it still names the draft.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
    }
    expect(_isSelected(tester, '20'), isFalse);
    expect(footer('Friday, November 20, 2026, 10:30'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('February 2027'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.bySemanticsLabel('Previous year'));
      await tester.pumpAndSettle();
    }
    expect(footer('Friday, November 20, 2026, 10:30'), findsOneWidget);

    // Another day, years away: the footer follows, keeping the time.
    await tester.tap(find.bySemanticsLabel('March 2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('17').first);
    await tester.pumpAndSettle();
    expect(footer('Monday, March 17, 2025, 10:30'), findsOneWidget);
    expect(footer('Friday, November 20, 2026, 10:30'), findsNothing);

    // The summary is no button, and Done confirms exactly what it said.
    await tester.tap(footer('Monday, March 17, 2025, 10:30'));
    await tester.pumpAndSettle();
    expect(_changes(tester), isEmpty);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsNothing);
    expect(_changes(tester), [DateTime(2025, 3, 17, 10, 30)]);
    expect(find.text('March 17, 2025, 10:30'), findsOneWidget);
  });
}
