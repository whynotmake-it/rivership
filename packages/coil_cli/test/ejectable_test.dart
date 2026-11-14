// Every component must stay ejectable: `dart run coil_cli:eject` copies its
// folder and public libraries, so they may reach the rest of coil only
// through public libraries.
@TestOn('vm')
library;

import 'dart:io';

import 'package:coil_cli/src/coil_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/coil_root.dart';

void main() {
  final root = coilRoot();
  final coil = CoilSource(root);

  test('every public component library belongs to one component', () {
    final libraries = {
      for (final component in coil.components.values) ...component.libraries,
    };
    final public = [
      for (final file in Directory('$root/lib').listSync())
        if (file is File && file.path.endsWith('.dart'))
          file.uri.pathSegments.last,
    ];
    expect(
      public.where((l) => !libraries.contains(l)),
      unorderedEquals([
        'coil.dart',
        'foundation.dart',
        'primitives.dart',
      ]),
    );
  });

  for (final component in coil.components.values) {
    test('${component.name} ejects with public imports only', () {
      expect(coil.problemsOf(component), isEmpty);
      expect(coil.exportedNames(component), isNotEmpty);
    });
  }
}
