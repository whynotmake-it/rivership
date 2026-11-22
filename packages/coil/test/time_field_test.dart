import 'package:coil/coil.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

typedef _Time = ({int hour, int minute});

/// Holds the time a picker reports, as an app would.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.builder,
    required this.onReport,
  });

  final _Time initial;
  final Widget Function(_Time value, ValueChanged<_Time> onChanged) builder;
  final ValueChanged<_Time> onReport;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late _Time value = widget.initial;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: widget.builder(value, (time) {
      widget.onReport(time);
      setState(() => value = time);
    }),
  );
}

void main() {
  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  Future<void> keys(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
    for (final k in keys) {
      await key(tester, k);
    }
  }

  final digits = {
    '0': LogicalKeyboardKey.digit0,
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '9': LogicalKeyboardKey.digit9,
  };

  Future<void> type(WidgetTester tester, String text) =>
      keys(tester, [for (final c in text.split('')) digits[c]!]);

  /// Pumps a field and returns what it last reported.
  Future<_Time Function()> pumpField(
    WidgetTester tester, {
    required _Time initial,
    required bool use24,
    int minuteInterval = 1,
  }) async {
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = use24;
    useScreen(tester, TestScreen.desktop);
    var reported = initial;
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: _Host(
          initial: initial,
          onReport: (time) => reported = time,
          builder: (value, onChanged) => CoilTimeField(
            value: value,
            onChanged: onChanged,
            minuteInterval: minuteInterval,
          ),
        ),
      ),
    );
    // Tab comes in at the hour.
    await key(tester, LogicalKeyboardKey.tab);
    await tester.pump();
    return () => reported;
  }

  testWidgets('a 24-hour field types, steps, wraps and pastes', (tester) async {
    final reported = await pumpField(
      tester,
      initial: (hour: 9, minute: 5),
      use24: true,
      minuteInterval: 5,
    );

    // Digits fill the hour, which moves on by itself, then the minute.
    await type(tester, '1430');
    expect(reported(), (hour: 14, minute: 30));

    // A first digit that can't lead a second finishes the hour at once.
    await keys(tester, [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.digit7,
    ]);
    await type(tester, '9');
    expect(reported(), (hour: 7, minute: 9));

    // The arrows step the segment and wrap without carrying.
    await key(tester, LogicalKeyboardKey.arrowLeft);
    await key(tester, LogicalKeyboardKey.end);
    expect(reported().hour, 23);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(reported().hour, 0);
    await key(tester, LogicalKeyboardKey.pageDown);
    expect(reported().hour, 18);
    await key(tester, LogicalKeyboardKey.arrowRight);
    // Minutes typed stay as typed; the arrows land on the interval.
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(reported().minute, 10);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(reported().minute, 0);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(reported(), (hour: 18, minute: 55));
    await key(tester, LogicalKeyboardKey.pageUp);
    expect(reported().minute, 10);
    await key(tester, LogicalKeyboardKey.home);
    expect(reported().minute, 0);
    await key(tester, LogicalKeyboardKey.end);
    expect(reported().minute, 55);

    // A click picks the segment to edit.
    final field = tester.getRect(find.byType(CoilTimeField));
    await tester.tapAt(field.centerLeft + const Offset(24, 0));
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(reported(), (hour: 19, minute: 55));

    // Paste takes the forms of a time, and ignores what isn't one.
    Future<void> paste(String text) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': text}
            : null,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
    }

    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await paste('0815');
    expect(reported(), (hour: 8, minute: 15));
    await paste('2:30 pm');
    expect(reported(), (hour: 14, minute: 30));
    await paste('soon');
    await paste('25:00');
    expect(reported(), (hour: 14, minute: 30));
    await paste('9:45');
    expect(reported(), (hour: 9, minute: 45));
  });

  testWidgets('a 12-hour field has AM and PM, and screen readers adjust it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final reported = await pumpField(
      tester,
      initial: (hour: 9, minute: 0),
      use24: false,
    );

    // "2", "3", "0": hour 2, minute 30; the field moves on to AM and PM.
    await type(tester, '2');
    expect(reported(), (hour: 2, minute: 0));
    await type(tester, '30');
    expect(reported(), (hour: 2, minute: 30));
    await key(tester, LogicalKeyboardKey.keyP);
    expect(reported(), (hour: 14, minute: 30));
    await key(tester, LogicalKeyboardKey.keyA);
    expect(reported(), (hour: 2, minute: 30));
    await key(tester, LogicalKeyboardKey.keyP);

    // The hour goes 1 to 12 and keeps the period.
    await keys(tester, [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.end,
    ]);
    expect(reported(), (hour: 12, minute: 30));
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(reported(), (hour: 13, minute: 30));
    await key(tester, LogicalKeyboardKey.home);
    expect(reported(), (hour: 13, minute: 30));

    // Each segment is an adjustable node of a group named "Time".
    expect(find.bySemanticsLabel('Time'), findsOneWidget);
    Future<void> act(String label, SemanticsAction action) async {
      tester.semantics.performAction(find.semantics.byLabel(label), action);
      await tester.pump();
    }

    expect(
      tester.getSemantics(find.bySemanticsLabel('Hour')).value,
      '1',
    );
    await act('Hour', SemanticsAction.increase);
    expect(reported(), (hour: 14, minute: 30));
    await act('Minute', SemanticsAction.decrease);
    expect(reported(), (hour: 14, minute: 29));
    await act('AM/PM', SemanticsAction.decrease);
    expect(reported(), (hour: 2, minute: 29));
    semantics.dispose();
  });

  group('CoilTimeColumns on a phone', () {
    Future<_Time Function()> pumpColumns(
      WidgetTester tester, {
      required _Time initial,
      required bool use24,
    }) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = use24;
      useScreen(tester, TestScreen.phone);
      var reported = initial;
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: _Host(
            initial: initial,
            onReport: (time) => reported = time,
            builder: (value, onChanged) =>
                CoilTimeColumns(value: value, onChanged: onChanged),
          ),
        ),
      );
      return () => reported;
    }

    testWidgets('tapping a number brings it to the band', (tester) async {
      final reported = await pumpColumns(
        tester,
        initial: (hour: 9, minute: 15),
        use24: true,
      );
      await tester.tap(find.text('07').first);
      await tester.pumpAndSettle();
      expect(reported(), (hour: 7, minute: 15));
      // The minute below the band, a row away.
      await tester.tap(find.text('20').first);
      await tester.pumpAndSettle();
      expect(reported(), (hour: 7, minute: 20));
      // The rows the wheel shows follow the value it landed on.
      expect(find.text('07'), findsWidgets);
    });

    testWidgets('tapping the picked number opens the number pad', (
      tester,
    ) async {
      final reported = await pumpColumns(
        tester,
        initial: (hour: 14, minute: 40),
        use24: true,
      );
      await tester.tap(find.text('14').first);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      tester.testTextInput.enterText('0915');
      await tester.pumpAndSettle();
      expect(reported(), (hour: 9, minute: 15));

      // Another tap in the columns puts the pad away.
      await tester.tap(find.text('07').first);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a 12-hour clock types the hour and minute, AM and PM stays', (
      tester,
    ) async {
      final reported = await pumpColumns(
        tester,
        initial: (hour: 15, minute: 0),
        use24: false,
      );
      await tester.tap(find.text('3').first);
      await tester.pump();
      tester.testTextInput.enterText('1030');
      await tester.pumpAndSettle();
      expect(reported(), (hour: 22, minute: 30));
      // Tapping the AM row above PM brings the morning.
      await tester.tapAt(tester.getCenter(find.text('AM').first));
      await tester.pumpAndSettle();
      expect(reported(), (hour: 10, minute: 30));
    });

    testWidgets('a focused column takes keys', (tester) async {
      final reported = await pumpColumns(
        tester,
        initial: (hour: 9, minute: 15),
        use24: true,
      );
      await key(tester, LogicalKeyboardKey.tab);
      await type(tester, '16');
      expect(reported(), (hour: 16, minute: 15));
      await key(tester, LogicalKeyboardKey.arrowRight);
      // As in a list, Down moves on to the larger values and Up back.
      await key(tester, LogicalKeyboardKey.pageDown);
      expect(reported(), (hour: 16, minute: 30));
      await key(tester, LogicalKeyboardKey.end);
      expect(reported(), (hour: 16, minute: 55));
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(reported(), (hour: 17, minute: 55));
      // A pause starts a number over.
      await tester.pump(const Duration(seconds: 2));
      await type(tester, '0');
      await tester.pump(const Duration(seconds: 2));
      await type(tester, '7');
      expect(reported().hour, 7);
    });
  });

  testWidgets("dates and times read on the locale's clock", (tester) async {
    const labels = CoilCalendarLabels();
    final afternoon = DateTime(2026, 11, 14, 14, 30);
    expect(
      labels.dateLabel(afternoon, withTime: true, use24HourFormat: false),
      'November 14, 2026, 2:30\u00A0PM',
    );
    expect(
      labels.summaryLabel(afternoon, withTime: true, use24HourFormat: true),
      'Selected: Saturday, November 14, 2026, 14:30',
    );
    expect(
      labels.dateLabel(
        DateTime(2026, 11, 14),
        withTime: true,
        use24HourFormat: false,
      ),
      'November 14, 2026, 12:00\u00A0AM',
    );

    tester.platformDispatcher.alwaysUse24HourFormatTestValue = false;
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 300,
            child: CoilDatePicker(
              value: afternoon,
              withTime: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('November 14, 2026, 2:30\u00A0PM'), findsOneWidget);
  });
}
