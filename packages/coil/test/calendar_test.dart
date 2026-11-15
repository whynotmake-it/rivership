import 'dart:ui';

import 'package:coil/coil.dart';
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
    // Tab past the two month buttons onto the grid.
    for (var i = 0; i < 3; i++) {
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
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
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
}
