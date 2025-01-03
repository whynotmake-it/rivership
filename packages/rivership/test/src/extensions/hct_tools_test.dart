import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('HctTools', () {
    setUp(() {});

    const black = Color(0xFF000000);

    group('toHct', () {
      test('idempotent for black', () {
        final hct = black.toHct();
        expect(hct.toColor(), black);
      });

      test('keeps opacity information', () async {
        final semiTransparent = black.withValues(alpha: 0.5);
        final hct = semiTransparent.toHct();
        final color = hct.toColor();
        const tolerance = 0.002;
        expect(color.a, closeTo(semiTransparent.a, tolerance));
        expect(color.r, closeTo(semiTransparent.r, tolerance));
        expect(color.g, closeTo(semiTransparent.g, tolerance));
        expect(color.b, closeTo(semiTransparent.b, tolerance));
      });
    });
  });
}
