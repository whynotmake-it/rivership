// Every component must stay ejectable: `dart run coil:eject` copies its
// folder and public libraries, so they may reach the rest of coil only
// through public libraries.
@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/component_docs.dart';
import 'package:coil/src/eject/dart_source.dart';
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
      final files = coil.ejectedFiles(component);
      for (final MapEntry(key: path, value: source) in files.entries) {
        for (final directive in directivesOf(source)) {
          for (final uri in directive.uris) {
            expect(
              uri,
              isNot(startsWith('package:coil/src/')),
              reason: '$path keeps a private coil import',
            );
          }
        }
      }
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

  test('the name scanner finds what the analyzer finds', () {
    // The app library hides these names from package:coil/coil.dart, so a
    // missed name would make the ejected copy clash with coil's.
    for (final component in coil.components.values) {
      for (final file in component.sources) {
        final source = File('lib/$file').readAsStringSync();
        final unit = parseString(content: source).unit;
        final expected = {
          for (final member in unit.declarations)
            for (final name in _names(member))
              if (!name.startsWith('_')) name,
        };
        expect(declaredNames(source), expected, reason: file);
      }
    }
  });
}

Iterable<String> _names(CompilationUnitMember member) => switch (member) {
  TopLevelVariableDeclaration(:final variables) => [
    for (final v in variables.variables) v.name.lexeme,
  ],
  ClassDeclaration(:final namePart) ||
  EnumDeclaration(:final namePart) ||
  ExtensionTypeDeclaration(:final namePart) => [namePart.typeName.lexeme],
  MixinDeclaration(:final name) ||
  FunctionDeclaration(:final name) ||
  TypeAlias(:final name) => [name.lexeme],
  ExtensionDeclaration(:final name) => [?name?.lexeme],
  _ => throw UnsupportedError('${member.runtimeType}'),
};
