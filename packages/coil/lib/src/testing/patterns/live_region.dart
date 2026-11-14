import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `CoilPattern.liveRegion` checks, run by `expectCoilPattern`.
///
/// A live region is a semantics node that screen readers announce when it
/// appears or its text changes: it has the live-region flag (or the web's
/// `status` / `alert` role, which Flutter doesn't allow together with the
/// flag), carries the region's text as its label, and isn't a focus stop
/// itself.
Future<void> expectLiveRegionPattern(
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

  visit(tester.getSemantics(finder));
  final regions = nodes.where(
    (n) =>
        n.flagsCollection.isLiveRegion ||
        n.role == SemanticsRole.status ||
        n.role == SemanticsRole.alert,
  );
  expect(regions, isNotEmpty, reason: 'liveRegion: a live region node');
  for (final region in regions) {
    expect(
      region.label.trim(),
      isNotEmpty,
      reason: 'liveRegion: the region announces its text',
    );
    expect(
      region.flagsCollection.isFocused,
      Tristate.none,
      reason: 'liveRegion: the region is not a tab stop',
    );
  }
}
