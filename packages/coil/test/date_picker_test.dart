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
