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

      test('Looses opacity information', () async {
        final semiTransparent = black.withOpacity(0.5);
        final hct = semiTransparent.toHct();
        expect(hct.toColor(), semiTransparent);
      });
    });
  });
}
