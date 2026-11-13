import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `CoilPattern.table` checks, run by `expectCoilPattern` after the
/// table was reached with Tab and showed its focus ring:
///
/// * a table node whose children are rows, the first of them column
///   headers and the rest cells;
/// * Space selects the active row, and the arrows move it: Space, Down,
///   Space selects the first two body rows.
///
/// Needs a stateful host with a selectable table of two or more rows and
/// nothing selected.
Future<void> expectTablePattern(WidgetTester tester, Finder finder) async {
  SemanticsNode table() {
    SemanticsNode? found;
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().role == SemanticsRole.table) {
        found = node;
        return;
      }
      node.visitChildren((child) {
        if (found == null) visit(child);
        return found == null;
      });
    }

    visit(tester.getSemantics(finder));
    if (found == null) throw TestFailure('table: no table node');
    return found!;
  }

  List<SemanticsNode> children(SemanticsNode node) {
    final out = <SemanticsNode>[];
    node.visitChildren((child) {
      out.add(child);
      return true;
    });
    return out;
  }

  final rows = children(table());
  expect(
    rows.every((r) => r.getSemanticsData().role == SemanticsRole.row),
    isTrue,
    reason: 'table: every child of the table is a row',
  );
  expect(rows.length, greaterThan(2), reason: 'table: a header and rows');
  expect(
    children(rows.first).every(
      (c) => c.getSemanticsData().role == SemanticsRole.columnHeader,
    ),
    isTrue,
    reason: 'table: the first row holds column headers',
  );
  expect(
    children(rows[1]).every(
      (c) => c.getSemanticsData().role == SemanticsRole.cell,
    ),
    isTrue,
    reason: 'table: body rows hold cells',
  );

  List<bool> selected() => [
    for (final row in children(table()).skip(1))
      row.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue,
  ];
  expect(selected(), everyElement(isFalse), reason: 'table: nothing selected');
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pumpAndSettle();
  expect(
    selected().take(3),
    [true, true, false],
    reason:
        'table: Space selects the active row and Down moves it '
        '(needs a stateful host)',
  );
}
