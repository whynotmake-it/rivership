import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _composer(
  List<String> sent, {
  CoilMessageStatus status = CoilMessageStatus.idle,
  VoidCallback? onStop,
  ValueChanged<String>? onQueue,
}) => Center(
  child: SizedBox(
    width: 360,
    child: CoilInputMessage(
      onSend: sent.add,
      status: status,
      onStop: onStop,
      onQueue: onQueue,
    ),
  ),
);

String _text(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  testWidgets('with a pointer, Enter sends the trimmed text and clears', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final sent = <String>[];
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: _composer(sent)),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), '  hello ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['hello']);
    expect(_text(tester), isEmpty);
  });

  testWidgets('the send button is off while the field is blank', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final sent = <String>[];
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: _composer(sent)),
    );
    await tester.tap(find.bySemanticsLabel('Send'));
    expect(sent, isEmpty);
    await tester.enterText(find.byType(EditableText), 'hi');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    expect(sent, ['hi']);
  });

  testWidgets('on touch, Return is a new line', (tester) async {
    useScreen(tester, TestScreen.phone);
    final sent = <String>[];
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: _composer(sent)),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'hi');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('while streaming the button stops and Enter does not send', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final sent = <String>[];
    var stopped = 0;
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: _composer(
          sent,
          status: CoilMessageStatus.streaming,
          onStop: () => stopped++,
        ),
      ),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'next');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.bySemanticsLabel('Stop'));
    expect(sent, isEmpty);
    expect(stopped, 1);
  });

  group('queue', () {
    testWidgets('while streaming, Enter queues the draft and clears', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      final sent = <String>[];
      final queued = <String>[];
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: _composer(
            sent,
            status: CoilMessageStatus.streaming,
            onStop: () {},
            onQueue: queued.add,
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), '  next ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(queued, ['next']);
      expect(sent, isEmpty);
      expect(_text(tester), isEmpty);
    });

    testWidgets('the button queues a draft and stops when the field is empty', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      final queued = <String>[];
      var stopped = 0;
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: _composer(
            [],
            status: CoilMessageStatus.streaming,
            onStop: () => stopped++,
            onQueue: queued.add,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Stop'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'later');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Stop'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Queue message'));
      await tester.pumpAndSettle();
      expect(queued, ['later']);
      expect(find.bySemanticsLabel('Stop'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Stop'));
      expect(stopped, 1);
    });

    testWidgets('once the reply ends, the button sends again', (tester) async {
      useScreen(tester, TestScreen.desktop);
      final sent = <String>[];
      final status = ValueNotifier(CoilMessageStatus.streaming);
      addTearDown(status.dispose);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: ValueListenableBuilder(
            valueListenable: status,
            builder: (context, value, _) =>
                _composer(sent, status: value, onQueue: (_) {}),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'hi');
      status.value = CoilMessageStatus.idle;
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Send'));
      expect(sent, ['hi']);
    });
  });
}
