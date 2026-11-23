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
          const CoilMenuLabel(Text('Go to')),
          CoilAction(
            label: const Text('Inbox'),
            searchText: 'Inbox',
            onPressed: () => log.add('inbox'),
          ),
          CoilAction(
            label: const Text('Settings'),
            searchText: 'Settings',
            onPressed: () => log.add('settings'),
          ),
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

  testWidgets('on a phone the panel and its search field stay put', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    final trigger = FocusNode();
    addTearDown(trigger.dispose);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: Builder(
          builder: (context) => Center(
            child: CoilButton(
              focusNode: trigger,
              onPressed: () => showCoilCommandMenu(
                context: context,
                entries: [
                  for (var i = 0; i < 30; i++)
                    CoilAction(
                      label: Text('Item $i'),
                      searchText: 'Item $i',
                      onPressed: () {},
                    ),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    // Opened from the keyboard, so the trigger holds focus.
    trigger.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // The rows' text, not the search field's.
    Finder row(String text) =>
        find.byWidgetPredicate((w) => w is Text && w.data == text);
    final field = find.byType(EditableText);
    final panel = find.byType(CoilSheetPanel);
    final fieldRect = tester.getRect(field);
    final panelRect = tester.getRect(panel);

    // Filtering down to a few results, then to none, moves neither.
    await tester.enterText(field, 'Item 29');
    await tester.pumpAndSettle();
    expect(row('Item 29'), findsOneWidget);
    expect(row('Item 3'), findsNothing);
    expect(tester.getRect(field), fieldRect);
    expect(tester.getRect(panel), panelRect);
    await tester.enterText(field, 'nothing like it');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
    expect(tester.getRect(field), fieldRect);
    expect(tester.getRect(panel), panelRect);
    // The empty state sits right under the search line, not centered in
    // the stable panel.
    final empty = tester.getTopLeft(find.text('No results')).dy;
    expect(empty, greaterThan(fieldRect.bottom));
    expect(empty, lessThan(panelRect.center.dy));

    // The keyboard takes room from the bottom: the field stays where it is.
    const keyboard = 300.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 2);
    await tester.pumpAndSettle();
    expect(tester.getRect(field), fieldRect);
    expect(
      tester.getRect(panel).bottom,
      lessThanOrEqualTo(TestScreen.phone.size.height - keyboard),
    );
    expect(tester.getRect(panel).bottom, lessThan(panelRect.bottom));

    // The list scrolls under a finger; the menu stays open.
    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(row('Item 0')).dy;
    await tester.drag(row('Item 2'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.getTopLeft(row('Item 0')).dy, lessThan(before));
    expect(tester.getRect(panel).left, panelRect.left);

    // A sideways swipe throws the panel away and hands focus back to what
    // opened it.
    await tester.fling(row('Item 6'), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    expect(trigger.hasFocus, isTrue);
  });

  testWidgets('on a phone a downward swipe closes the menu only from the top '
      'of its list, and otherwise scrolls the list', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: Builder(
          builder: (context) => Center(
            child: CoilButton(
              onPressed: () => showCoilCommandMenu(
                context: context,
                entries: [
                  for (var i = 0; i < 30; i++)
                    CoilAction(
                      label: Text('Item $i'),
                      searchText: 'Item $i',
                      onPressed: () {},
                    ),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    Finder row(String text) =>
        find.byWidgetPredicate((w) => w is Text && w.data == text);
    final field = find.byType(EditableText);
    expect(field, findsOneWidget);

    // Scrolled down a little, a downward drag scrolls the list back.
    await tester.drag(row('Item 2'), const Offset(0, -150));
    await tester.pumpAndSettle();
    final scrolled = tester.getTopLeft(row('Item 3')).dy;
    await tester.drag(row('Item 3'), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    expect(tester.getTopLeft(row('Item 3')).dy, greaterThan(scrolled));

    // A fling that began scrolled scrolls the list to its top and stays.
    await tester.fling(row('Item 3'), const Offset(0, 600), 1500);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);

    // From the top, a downward fling throws the panel away.
    await tester.fling(row('Item 3'), const Offset(0, 600), 1500);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
  });
}
