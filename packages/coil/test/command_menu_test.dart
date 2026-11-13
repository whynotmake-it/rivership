import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _opener(List<String> log) => Builder(
  builder: (context) => Center(
    child: CoilButton(
      onPressed: () => showCoilCommandMenu(
        context: context,
        entries: [
          const CoilMenuLabel('Go to'),
          CoilAction(label: 'Inbox', onPressed: () => log.add('inbox')),
          CoilAction(label: 'Settings', onPressed: () => log.add('settings')),
        ],
      ),
      child: const Text('Open'),
    ),
  ),
);

void main() {
  testWidgets('typing filters and Enter closes, then runs the match', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: _opener(log)),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'set');
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['settings']);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('Escape closes it', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: _opener([])),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsNothing);
  });

  testWidgets('on a phone it opens as a sheet', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: _opener([])));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
  });
}
