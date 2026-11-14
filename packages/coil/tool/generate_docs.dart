// Regenerates doc/llms.txt and doc/components/ from DESIGN.md.
// Run from the package root: dart run tool/generate_docs.dart
import 'dart:io';

import 'package:coil_cli/coil_cli.dart';
import 'src/component_docs.dart';

void main() {
  final docs = generatedDocs(
    CoilSource('.'),
    File('DESIGN.md').readAsStringSync(),
  );
  final dir = Directory('doc/components');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  for (final MapEntry(key: path, value: content) in docs.entries) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
  stdout.writeln('Wrote ${docs.length} files.');
}
