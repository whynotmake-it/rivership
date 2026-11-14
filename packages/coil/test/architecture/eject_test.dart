// Every component must stay ejectable: `dart run coil:eject` copies its
// folder and public libraries, so they may reach the rest of coil only
// through public libraries.
@TestOn('vm')
library;

import 'dart:io';

import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/component_docs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coil = CoilSource('.');

  test('every public component library belongs to one component', () {
    final libraries = {
      for (final component in coil.components.values) ...component.libraries,
    };
    final public = [
      for (final file in Directory('lib').listSync())
        if (file is File && file.path.endsWith('.dart'))
          file.uri.pathSegments.last,
    ];
    expect(
      public.where((l) => !libraries.contains(l)),
      unorderedEquals([
        'coil.dart',
        'foundation.dart',
        'primitives.dart',
        'testing.dart',
      ]),
    );
  });

  for (final component in coil.components.values) {
    test('${component.name} ejects with public imports only', () {
      expect(coil.problemsOf(component), isEmpty);
      expect(coil.exportedNames(component), isNotEmpty);
    });
  }

  test('doc/ is regenerated from DESIGN.md', () {
    // Run `dart run tool/generate_docs.dart` after changing DESIGN.md §14
    // or a component's exports.
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
