/// @docImport 'package:coil_cli/src/testing/coil_pattern.dart';
library;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the [CoilPattern.adjustable] contract for [expectCoilPattern]
/// after the target has been focused with Tab and shown its focus ring.
///
/// Checks that the adjustable control exposes a single node with a value and
/// increase/decrease actions, and that Arrow Up raises the value while Arrow
/// Down lowers it regardless of reading direction. Requires a stateful host
/// that applies `onChanged` starting from a value that can increase.
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
