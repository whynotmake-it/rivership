import 'dart:convert';
import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// A throwaway app that depends on this checkout's coil: a pubspec and a
/// package config with every package this workspace resolves, coil's root
/// replaced by [coilRoot] when given. Eject can resolve its files without
/// `pub get`.
Future<Directory> createTempApp({String? coilRoot}) async {
  final config = (await findPackageConfig(Directory.current))!;
  final app = Directory.systemTemp.createTempSync('coil_app');
  File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
  final packages = [
    for (final package in config.packages)
      {
        'name': package.name,
        'rootUri': package.name == 'coil' && coilRoot != null
            ? Directory(coilRoot).absolute.uri.toString()
            : package.root.toString(),
        'packageUri': package.packageUriRoot.toString().substring(
          package.root.toString().length,
        ),
        if (package.languageVersion case final version?)
          'languageVersion': '$version',
      },
    {
      'name': 'app',
      'rootUri': '../',
      'packageUri': 'lib/',
      'languageVersion': '3.12',
    },
  ];
  File(p.join(app.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'configVersion': 2, 'packages': packages}),
    );
  return app;
}
