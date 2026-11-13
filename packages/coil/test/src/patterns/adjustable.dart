import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `CoilPattern.adjustable` checks, run by `expectCoilPattern`
/// after the target was reached with Tab and showed its focus ring.
///
/// An adjustable control is one node with a value and increase/decrease
/// actions. Up raises the value and Down lowers it, whatever the reading
/// direction. Needs a stateful host that applies `onChanged`, with a value
/// that can move up from where it starts.
Future<void> expectAdjustablePattern(
  WidgetTester tester,
  Finder finder,
) async {
  SemanticsData node() {
    final out = <SemanticsData>[];
    void visit(SemanticsNode n) {
      out.add(n.getSemanticsData());
      n.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.getSemantics(finder));
    return out.firstWhere(
      (n) =>
          n.hasAction(SemanticsAction.increase) ||
          n.hasAction(SemanticsAction.decrease),
      orElse: () =>
          throw TestFailure('adjustable: no node with increase/decrease'),
    );
  }

  final before = node();
  expect(before.value, isNotEmpty, reason: 'adjustable: the node has a value');
  expect(
    before.hasAction(SemanticsAction.increase),
    isTrue,
    reason: 'adjustable: can increase from the starting value',
  );

  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.pumpAndSettle();
  final raised = node();
  expect(
    raised.value,
    isNot(before.value),
    reason: 'adjustable: Up changes the value (needs a stateful host)',
  );
  expect(
    raised.hasAction(SemanticsAction.decrease),
    isTrue,
    reason: 'adjustable: a raised value can decrease again',
  );

  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  expect(
    node().value,
    before.value,
    reason: 'adjustable: Down undoes Up',
  );
}
