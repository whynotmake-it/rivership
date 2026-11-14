import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The root of the coil package this checkout resolves, from the package
/// config `flutter test` runs with.
String coilRoot() {
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    final file = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    if (file.existsSync()) {
      final config = jsonDecode(file.readAsStringSync()) as Map;
      for (final package in config['packages'] as List) {
        if ((package as Map)['name'] == 'coil') {
          return p.normalize(
            p.fromUri(file.uri.resolve(package['rootUri'] as String)),
          );
        }
      }
    }
    if (dir.parent.path == dir.path) throw StateError('coil not found');
  }
}
