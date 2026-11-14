import 'dart:ui' show CheckedState, SemanticsRole;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `CoilPattern.question` checks, run by `expectCoilPattern` after the
/// question's rows were reached with Tab and showed the focus ring:
///
/// * the rows are option nodes (radios in a radio group, or checkboxes),
///   inside a node labelled by the question;
/// * Up and Down move focus between rows without picking;
/// * Space picks the focused row: its checked state flips, or the card
///   moves to the next question;
/// * the rows are one tab stop.
Future<void> expectQuestionPattern(WidgetTester tester, Finder finder) async {
  final options = _options(tester, finder);
  expect(
    options.length,
    greaterThan(1),
    reason: 'question: option nodes with a checked state',
  );
  final radios = options.every(
    (n) => n.flagsCollection.isInMutuallyExclusiveGroup,
  );
  if (radios) {
    expect(
      _all(tester, finder).any((n) => n.role == SemanticsRole.radioGroup),
      isTrue,
      reason: 'question: single choice is a radio group',
    );
  }
  expect(
    _all(tester, finder).any(
      (n) => n.label.isNotEmpty && n.flagsCollection.isHeader,
    ),
    isTrue,
    reason: 'question: the question is a header',
  );

  final checked = _checked(tester, finder);
  final first = FocusManager.instance.primaryFocus;
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  final second = FocusManager.instance.primaryFocus;
  expect(
    second,
    isNot(first),
    reason: 'question: Down moves focus to the next row',
  );
  expect(
    _checked(tester, finder),
    checked,
    reason: 'question: moving focus does not pick',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.pumpAndSettle();
  expect(
    FocusManager.instance.primaryFocus,
    first,
    reason: 'question: Up moves focus back',
  );

  // One tab stop: Tab leaves the rows.
  final row = FocusManager.instance.primaryFocus;
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  final next = FocusManager.instance.primaryFocus;
  expect(next, isNot(row), reason: 'question: Tab leaves the row');
  expect(next, isNot(second), reason: 'question: the rows are one tab stop');
  await _shiftTab(tester, times: 1);
  expect(
    FocusManager.instance.primaryFocus,
    row,
    reason: 'question: Shift+Tab returns to the same row',
  );

  final title = _headers(tester, finder);
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pumpAndSettle();
  expect(
    _checked(tester, finder) != checked || _headers(tester, finder) != title,
    isTrue,
    reason: 'question: Space picks the focused row',
  );
}

Future<void> _shiftTab(WidgetTester tester, {required int times}) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }
}

List<SemanticsData> _all(WidgetTester tester, Finder finder) {
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    out.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return out;
}

List<SemanticsData> _options(WidgetTester tester, Finder finder) => _all(
  tester,
  finder,
).where((n) => n.flagsCollection.isChecked != CheckedState.none).toList();

List<bool> _checked(WidgetTester tester, Finder finder) => [
  for (final n in _options(tester, finder))
    n.flagsCollection.isChecked == CheckedState.isTrue,
];

List<String> _headers(WidgetTester tester, Finder finder) => [
  for (final n in _all(tester, finder))
    if (n.flagsCollection.isHeader) n.label,
];
