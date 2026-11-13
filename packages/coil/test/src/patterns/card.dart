import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `CoilPattern.card` checks, run by `expectCoilPattern` after the card
/// was reached with Tab and showed its focus ring:
///
/// * the card is one button node, with a tap action, named by its text;
/// * the focused node is the card's own: Enter and Space activate it;
/// * the next Tab leaves the card's node (for its inner buttons or the
///   next control): the card itself is a single stop.
Future<void> expectCardPattern(WidgetTester tester, Finder finder) async {
  final root = _buttonNode(tester, finder);
  expect(root, isNotNull, reason: 'card: the whole card is one button node');
  expect(
    root!.hasAction(SemanticsAction.tap),
    isTrue,
    reason: 'card: the button node has a tap action',
  );
  expect(
    root.label.trim(),
    isNotEmpty,
    reason: 'card: the button is named by the card text',
  );

  final cardFocus = FocusManager.instance.primaryFocus!;
  final action = Actions.maybeFind<ActivateIntent>(cardFocus.context!);
  expect(
    action != null && action.isEnabled(const ActivateIntent()),
    isTrue,
    reason: 'card: Enter and Space activate it',
  );

  // The next Tab leaves the card's own node, for its inner buttons or
  // the next control.
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  expect(
    FocusManager.instance.primaryFocus,
    isNot(cardFocus),
    reason: 'card: the card is a single tab stop',
  );
  // Back to the card for the pointer check.
  cardFocus.requestFocus();
  await tester.pumpAndSettle();
}

SemanticsData? _buttonNode(WidgetTester tester, Finder finder) {
  SemanticsData? found;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isButton) {
      found = data;
      return;
    }
    node.visitChildren((child) {
      if (found == null) visit(child);
      return found == null;
    });
  }

  visit(tester.getSemantics(finder));
  return found;
}
