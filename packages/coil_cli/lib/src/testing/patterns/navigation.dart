/// @docImport 'package:coil_cli/src/testing/coil_pattern.dart';
library;

import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the [CoilPattern.navigation] contract for [expectCoilPattern]
/// after the first link has been focused with Tab and shown its focus ring.
///
/// Checks that the navigation trail is a labelled navigation landmark whose
/// links are each a Tab stop in order (no roving focus), that Enter follows
/// the focused link, and that the current page is selected and neither a link
/// nor a Tab stop.
Future<void> expectNavigationPattern(
  WidgetTester tester,
  Finder finder,
) async {
  final nodes = <SemanticsData>[];
  void visit(SemanticsNode node) {
    nodes.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // The landmark may sit on the target's own node or below it.
  visit(tester.getSemantics(finder));
  final landmark = nodes.where((n) => n.role == SemanticsRole.navigation);
  expect(landmark, hasLength(1), reason: 'navigation: one landmark node');
  expect(
    landmark.single.label,
    isNotEmpty,
    reason: 'navigation: the landmark is labelled',
  );
  final stops = nodes
      .where(
        (n) =>
            n.flagsCollection.isFocused != Tristate.none &&
            n.hasAction(SemanticsAction.tap),
      )
      .toList();
  expect(
    stops.where((n) => n.flagsCollection.isLink),
    isNotEmpty,
    reason: 'navigation: links with a tap action',
  );
  final selected = nodes.where(
    (n) => n.flagsCollection.isSelected == Tristate.isTrue,
  );
  expect(selected, hasLength(1), reason: 'navigation: one current page');
  expect(
    selected.single.flagsCollection.isLink ||
        selected.single.flagsCollection.isFocused != Tristate.none,
    isFalse,
    reason: 'navigation: the current page is neither a link nor a tab stop',
  );

  final focused = FocusManager.instance.primaryFocus!.context!;
  final action = Actions.maybeFind<ActivateIntent>(focused);
  expect(
    action != null && action.isEnabled(const ActivateIntent()),
    isTrue,
    reason: 'navigation: Enter follows the focused link',
  );

  bool inside() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    final targets = finder.evaluate().toSet();
    var found = targets.contains(context);
    context.visitAncestorElements((e) {
      found = found || targets.contains(e);
      return !found;
    });
    return found;
  }

  // Every link is its own Tab stop, in order.
  var visited = 1;
  while (true) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (!inside()) break;
    visited++;
  }
  expect(
    visited,
    stops.length,
    reason: 'navigation: Tab visits each shown link once',
  );
  // Back in for the pointer check.
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.pumpAndSettle();
  expect(inside(), isTrue, reason: 'navigation: Shift+Tab returns');
}
