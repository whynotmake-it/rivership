import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _menu(List<String> log) => Center(
  child: CoilDropdown(
    search: const CoilMenuSearch(
      placeholder: Text('Find'),
      semanticLabel: 'Find',
    ),
    entries: [
      const CoilMenuLabel(Text('Edit')),
      CoilAction(
        label: const Text('Copy'),
        searchText: 'Copy',
        onPressed: () => log.add('copy'),
      ),
      CoilAction(
        label: const Text('Cut'),
        searchText: 'Cut',
        onPressed: () => log.add('cut'),
      ),
      const CoilMenuSeparator(),
      const CoilMenuLabel(Text('File')),
      CoilAction(
        label: const Text('Close'),
        searchText: 'Close',
        onPressed: () => log.add('close'),
      ),
      CoilAction(
        label: const Text('Rename'),
        searchText: 'Rename',
        onPressed: () => log.add('rename'),
      ),
    ],
    builder: (context, menu) =>
        CoilButton(onPressed: menu.open, child: const Text('Actions')),
  ),
);

void main() {
  testWidgets('typing filters rows, keeps their headings, and Enter picks '
      'the first match', (tester) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu(log)));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'c');
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'clo');
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['close']);
  });

  testWidgets('arrows move through matches while the field keeps focus', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu(log)));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'c');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['cut']);
  });

  testWidgets('no match shows the empty label', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu([])));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('Enter during an IME composition only commits it', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu(log)));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'co',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('on a phone a menu with search opens as a sheet', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: _menu([])));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsOneWidget);
  });
}
