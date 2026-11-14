import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

const _fruit = [
  CoilOption(value: 'apple', label: Text('Apple'), searchText: 'Apple'),
  CoilOption(value: 'apricot', label: Text('Apricot'), searchText: 'Apricot'),
  CoilOption(value: 'banana', label: Text('Banana'), searchText: 'Banana'),
];

class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  String? value;

  void setValue(String v) => setState(() => value = v);

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.7),
    child: SizedBox(
      width: 240,
      child: CoilCombobox<String>(
        options: _fruit,
        value: value,
        onChanged: (v) => setState(() => value = v),
      ),
    ),
  );
}

String _fieldText(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .controller
    .text;

void main() {
  testWidgets('typing filters, arrows move and Enter picks while the field '
      'keeps focus', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'ap');
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsNothing);
    expect(find.text('Apricot'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'Apricot');
    expect(find.text('Apple'), findsNothing);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);

    // Reopened, it lists every option again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOneWidget);
  });

  testWidgets('a click on a match picks it', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'b');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'Banana');
  });

  testWidgets('Escape closes the list, and leaving drops unpicked text', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'zz');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsNothing);
    expect(_fieldText(tester), 'zz');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(_fieldText(tester), '');
  });

  testWidgets('Enter during an IME composition picks nothing', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Demo()),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ba',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'ba');
    expect(find.text('Banana'), findsOneWidget);
  });

  testWidgets('on a phone a trigger opens a sheet with the field', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: const _Demo()),
    );
    await tester.tap(find.byType(CoilCombobox<String>));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'ban');
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsNothing);
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    expect(find.byType(CoilSheetPanel), findsNothing);
    expect(find.text('Banana'), findsOneWidget);
  });

  testWidgets('a value set from outside while the sheet filters', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: const _Demo()),
    );
    await tester.tap(find.byType(CoilCombobox<String>));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'ap');
    await tester.pumpAndSettle();
    tester.state<_DemoState>(find.byType(_Demo)).setValue('banana');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The sheet keeps filtering what was typed in it.
    expect(find.text('Apricot'), findsOneWidget);
  });

  multiTests();
}

class _MultiDemo extends StatefulWidget {
  const _MultiDemo();

  @override
  State<_MultiDemo> createState() => _MultiDemoState();
}

class _MultiDemoState extends State<_MultiDemo> {
  Set<String> values = {};

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.7),
    child: SizedBox(
      width: 240,
      child: CoilMultiCombobox<String>(
        options: _fruit,
        values: values,
        onChanged: (v) => setState(() => values = v),
      ),
    ),
  );
}

Set<String> _values(WidgetTester tester) =>
    tester.state<_MultiDemoState>(find.byType(_MultiDemo)).values;

void multiTests() {
  testWidgets('multi: picks toggle, the list stays open, chips show', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _MultiDemo()),
    );
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'ap');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_values(tester), {'apple'});
    expect(_fieldText(tester), isEmpty);
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    expect(_values(tester), {'apple', 'banana'});
    expect(find.bySemanticsLabel('Remove Apple'), findsOneWidget);

    // Backspace in the empty field removes the last chip.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_values(tester), {'apple'});

    await tester.tap(find.bySemanticsLabel('Remove Apple'));
    await tester.pumpAndSettle();
    expect(_values(tester), isEmpty);
  });
}
