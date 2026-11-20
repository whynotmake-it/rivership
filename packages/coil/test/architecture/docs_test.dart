// doc/llms.txt and doc/components/ are generated from DESIGN.md §14 and the
// components' exports. Run `dart run tool/generate_docs.dart` after
// changing either.
@TestOn('vm')
library;

import 'dart:io';

import 'package:coil_cli/coil_cli.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/component_docs.dart';

void main() {
  final coil = CoilSource('.');

  test('doc/ is regenerated from DESIGN.md', () {
    final docs = generatedDocs(coil, File('DESIGN.md').readAsStringSync());
    for (final MapEntry(key: path, value: content) in docs.entries) {
      final file = File(path);
      expect(
        file.existsSync() ? file.readAsStringSync() : null,
        content,
        reason: '$path is stale',
      );
    }
    expect(
      [
        for (final file in Directory('doc/components').listSync())
          'doc/components/${file.uri.pathSegments.last}',
      ],
      unorderedEquals(docs.keys.where((k) => k.startsWith('doc/components'))),
    );
  });
}
