import 'package:coil/coil.dart';
import 'package:flutter_test/flutter_test.dart';

/// coil's built-in sizes.
const _table = CoilMetricsTable();

void main() {
  test('touch tier raises every hit target to 44', () {
    for (final size in CoilSize.values) {
      expect(
        _table.resolve(CoilTier.touch, size).minHitTarget,
        44,
      );
    }
  });
}
