/// @docImport 'package:coil_cli/src/testing/coil_pattern.dart';
library;

import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the [CoilPattern.disclosure] contract for [expectCoilPattern]
/// after the target has been focused with Tab and shown its focus ring.
///
/// Checks that the focused trigger is an enabled button with a tap action and
/// an expanded state, and that Enter and Space each toggle that state.
/// Requires a stateful host that applies `onChanged`.
Future<void> expectDisclosurePattern(
  WidgetTester tester,
  Finder finder,
) async {
  final focused = FocusManager.instance.primaryFocus!.context!;
  SemanticsData trigger() {
    final data = tester
        .getSemantics(find.byElementPredicate((e) => identical(e, focused)))
        .getSemanticsData();
    final flags = data.flagsCollection;
    if (!flags.isButton || flags.isExpanded == Tristate.none) {
      throw TestFailure(
        'disclosure: the focused trigger is a button with an expanded state',
      );
    }
    return data;
  }

  expect(
    trigger().hasAction(SemanticsAction.tap),
    isTrue,
    reason: 'disclosure: the trigger has a tap action',
  );
  expect(
    trigger().flagsCollection.isEnabled,
    Tristate.isTrue,
    reason: 'disclosure: the trigger is enabled',
  );
  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    final before = trigger().flagsCollection.isExpanded;
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
    expect(
      trigger().flagsCollection.isExpanded,
      isNot(before),
      reason: 'disclosure: ${key.keyLabel} toggles it (needs a stateful host)',
    );
  }
}
