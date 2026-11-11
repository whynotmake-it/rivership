import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/font_licenses.dart';

void main() {
  test('registers the OFL for every bundled font', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    for (final (font, authors) in [
      ('Archivo', 'The Archivo Project Authors'),
      ('JetBrains Mono', 'The JetBrains Mono Project Authors'),
    ]) {
      final entry = entries.firstWhere(
        (entry) => entry.packages.contains(font),
      );
      final text = entry.paragraphs.map((paragraph) => paragraph.text).join();
      expect(text, contains('Copyright 2020 $authors'));
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    }
  });
}
