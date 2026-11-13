import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _composer(
  List<String> sent, {
  CoilMessageStatus status = CoilMessageStatus.idle,
  VoidCallback? onStop,
}) => Center(
  child: SizedBox(
    width: 360,
    child: CoilInputMessage(onSend: sent.add, status: status, onStop: onStop),
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
}
