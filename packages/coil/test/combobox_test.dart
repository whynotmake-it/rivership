import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('every option clicked in the list lands, however fast', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    // A click: [frames] frames pass while the button is down. A real click
    // holds it for a few; a fast one lifts within the frame.
    Future<void> click(Finder finder, {int frames = 0}) async {
      final at = tester.getCenter(finder);
      await mouse.moveTo(at);
      await mouse.down(at);
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
    }

    Finder row(String label) => find.descendant(
      of: find.byType(CoilPopoverSurface),
      matching: find.text(label),
    );

    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: const _MultiDemo(options: fruits),
      ),
    );
    await click(find.byType(EditableText), frames: 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // Two fast clicks with no frame between them, then an ordinary one.
    await click(row('Apple'));
    await click(row('Banana'));
    await tester.pump(const Duration(milliseconds: 16));
    await click(row('Cherry'), frames: 5);
    await tester.pumpAndSettle();
    // A click on a match of a typed query.
    await tester.enterText(find.byType(EditableText), 'man');
    await tester.pumpAndSettle();
    await click(row('Mango'), frames: 5);
    await tester.pumpAndSettle();
    expect(_values(tester), {'apple', 'banana', 'cherry', 'mango'});
    for (final label in ['Apple', 'Banana', 'Cherry', 'Mango']) {
      expect(find.bySemanticsLabel('Remove $label'), findsOneWidget);
    }

    // The single combobox: a held click on a match picks it, and the field
    // keeps focus for the next search.
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('single'),
        child: testApp(tier: CoilTier.pointer, home: const _Demo()),
      ),
    );
    await click(find.byType(EditableText), frames: 2);
    await tester.enterText(find.byType(EditableText), 'ban');
    await tester.pumpAndSettle();
    await click(row('Banana'), frames: 5);
    await tester.pumpAndSettle();
    expect(tester.state<_DemoState>(find.byType(_Demo)).value, 'banana');
    expect(_fieldText(tester), 'Banana');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  }, variant: TargetPlatformVariant.desktop());
}

class _MultiDemo extends StatefulWidget {
  const _MultiDemo({this.options = _fruit, this.initial = const {}});

  final List<CoilOption<String>> options;
  final Set<String> initial;

  @override
  State<_MultiDemo> createState() => _MultiDemoState();
}

class _MultiDemoState extends State<_MultiDemo> {
  late Set<String> values = widget.initial;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.7),
    child: SizedBox(
      width: 240,
      child: CoilMultiCombobox<String>(
        options: widget.options,
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

    // Both picks show as chips inside the field, before the query text: each
    // chip's box sits within the editable text's field bounds and ahead of
    // the caret.
    final field = tester.getRect(find.byType(EditableText));
    for (final label in ['Apple', 'Banana']) {
      final chip = tester.getRect(find.bySemanticsLabel('Remove $label'));
      expect(field.top, lessThanOrEqualTo(chip.center.dy));
      expect(field.bottom, greaterThanOrEqualTo(chip.center.dy));
      expect(chip.left, lessThan(field.left));
    }

    // Backspace in the empty field removes the last chip.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_values(tester), {'apple'});

    // A tap on a chip's remove button removes that one.
    await tester.tap(find.bySemanticsLabel('Remove Apple'));
    await tester.pumpAndSettle();
    expect(_values(tester), isEmpty);
  });

  testWidgets('a press on the field opens the list, Tab focus does not, and '
      'a leading chip sits evenly inset', (tester) async {
    useScreen(tester, TestScreen.desktop);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final list = find.byType(CoilPopoverSurface);
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey(direction),
          child: testApp(
            tier: CoilTier.pointer,
            home: Directionality(
              textDirection: direction,
              child: const _MultiDemo(initial: {'apple'}),
            ),
          ),
        ),
      );
      final node = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;

      // Tab reaches the field without opening the list.
      for (var i = 0; i < 4 && !node.hasFocus; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(node.hasFocus, isTrue);
      expect(list, findsNothing);

      // The chip leads the field as far in from its leading edge as from
      // its top.
      final field = tester.getRect(find.byType(CoilTextFieldCore));
      final chip = tester.getRect(
        find
            .ancestor(of: find.text('Apple'), matching: find.byType(SizedBox))
            .first,
      );
      final leading = direction == TextDirection.ltr
          ? chip.left - field.left
          : field.right - chip.right;
      expect(leading, moreOrLessEquals(chip.top - field.top, epsilon: 0.5));
      expect(
        chip.top - field.top,
        moreOrLessEquals(field.bottom - chip.bottom),
      );

      // A click on the field opens the list, and another keeps it open.
      for (var i = 0; i < 2; i++) {
        await mouse.moveTo(field.center);
        await mouse.down(field.center);
        await tester.pump(const Duration(milliseconds: 50));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: list, matching: find.text('Banana')),
          findsOneWidget,
        );
      }
    }
  });
}
