/// @docImport 'package:coil_cli/src/testing/coil_pattern.dart';
library;

import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the [CoilPattern.liveRegion] contract for [expectCoilPattern].
///
/// Checks that the live region exposes a semantics node with the live-region
/// flag (or [SemanticsRole.status] / [SemanticsRole.alert], which Flutter does
/// not allow together with the flag), announces its text as its label, and is
/// not itself a focus stop.
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
