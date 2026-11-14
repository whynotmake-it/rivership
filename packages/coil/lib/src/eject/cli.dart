import 'dart:io';

import 'package:args/args.dart';
import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/manifest.dart';
import 'package:coil/src/eject/operations.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// `dart run coil:eject`. Returns the exit code.
Future<int> ejectCommand(
  List<String> arguments, {
  String? appRoot,
  StringSink? out,
}) => _run(out ?? stdout, () async {
  final parser = ArgParser()
    ..addFlag('list', abbr: 'l', negatable: false, help: 'List components.')
    ..addOption(
      'into',
      defaultsTo: 'lib/coil',
      help: 'Folder for the copy, relative to the app root.',
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'Replace an earlier eject, discarding your edits.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  final o = out ?? stdout;
  final root = appRoot ?? Directory.current.path;
  if (args.flag('help') || (!args.flag('list') && args.rest.isEmpty)) {
    o
      ..writeln('Copies coil components into your app to edit them.')
      ..writeln()
      ..writeln('Usage: dart run coil:eject <component>... [options]')
      ..writeln('       dart run coil:eject --list')
      ..writeln()
      ..writeln(parser.usage);
    return args.flag('help') ? 0 : 64;
  }
  final coil = await resolveCoil(root);
  if (args.flag('list')) {
    final ejected = Manifest.read(root).components;
    o.writeln('coil ${coil.version} components (* = ejected):');
    for (final component in coil.components.values) {
      final libraries = component.libraries
          .map(p.basenameWithoutExtension)
          .where((l) => l != component.name);
      o.writeln(
        '${ejected.containsKey(component.name) ? '*' : ' '} '
        '${component.name}'
        '${libraries.isEmpty ? '' : ' (also ${libraries.join(', ')})'}',
      );
    }
    return 0;
  }
  for (final name in args.rest) {
    final ejected = eject(
      coil,
      root,
      name,
      into: args.option('into')!,
      force: args.flag('force'),
    );
    final manifest = Manifest.read(root);
    o.writeln(
      'Ejected $ejected from coil ${coil.version} to '
      '${manifest.components[ejected]!.path}.',
    );
  }
  final library = Manifest.read(
    root,
  ).library.replaceFirst('lib/', 'package:${_appName(root)}/');
  o.writeln(
    'Import $library '
    'instead of package:coil/coil.dart. Commit ${Manifest.path} and '
    '.coil/base/: they are the base for `dart run coil:update`.',
  );
  return 0;
});

/// `dart run coil:update`. Returns the exit code: 0 when everything merged,
/// 1 when files need attention.
Future<int> updateCommand(
  List<String> arguments, {
  String? appRoot,
  StringSink? out,
}) => _run(out ?? stdout, () async {
  final parser = ArgParser()
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Show what would change without writing anything.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  final o = out ?? stdout;
  final root = appRoot ?? Directory.current.path;
  if (args.flag('help')) {
    o
      ..writeln(
        "Merges coil's changes into your ejected components "
        '(all of them if none are named).',
      )
      ..writeln()
      ..writeln('Usage: dart run coil:update [<component>...] [options]')
      ..writeln()
      ..writeln(parser.usage);
    return 0;
  }
  final coil = await resolveCoil(root);
  final names = args.rest.isEmpty
      ? Manifest.read(root).components.keys.toList()
      : args.rest;
  if (names.isEmpty) {
    o.writeln('Nothing is ejected.');
    return 0;
  }
  final dryRun = args.flag('dry-run');
  var attention = false;
  for (final name in names) {
    final result = update(coil, root, name, dryRun: dryRun);
    o.writeln(
      '${result.component}: ${result.from.join(', ')} → ${result.to}'
      '${dryRun ? ' (dry run)' : ''}',
    );
    for (final MapEntry(key: file, value: outcome) in result.files.entries) {
      if (outcome != FileUpdate.unchanged) {
        o.writeln('  ${_describe(outcome, dryRun)}: $file');
      }
    }
    if (result.files.values.every((f) => f == FileUpdate.unchanged)) {
      o.writeln('  up to date');
    }
    if (dryRun && result.diff.isNotEmpty) o.write(result.diff);
    if (result.needsAttention.isNotEmpty) {
      attention = true;
      if (!dryRun) {
        o.writeln(
          '  Resolve the conflict markers, then run coil:update again. These '
          'files keep their old base until they merge cleanly.',
        );
      }
    }
  }
  return attention ? 1 : 0;
});

String _describe(FileUpdate outcome, bool dryRun) => switch (outcome) {
  FileUpdate.unchanged => 'unchanged',
  FileUpdate.merged => dryRun ? 'would merge' : 'merged',
  FileUpdate.added => dryRun ? 'would add' : 'added',
  FileUpdate.removed => dryRun ? 'would remove' : 'removed',
  FileUpdate.conflict => 'CONFLICT',
  FileUpdate.removedButEdited => 'removed upstream, kept your edits',
  FileUpdate.deletedButChanged => 'changed upstream, you deleted it',
};

/// The coil package the app at [appRoot] resolves to, found through its
/// package config, so path, git and hosted dependencies all work.
Future<CoilSource> resolveCoil(String appRoot) async {
  if (!File(p.join(appRoot, 'pubspec.yaml')).existsSync()) {
    throw EjectException("Run this from your app's root (no pubspec.yaml).");
  }
  final config = await findPackageConfig(Directory(appRoot));
  final coil = config?['coil'];
  if (coil == null) {
    throw EjectException(
      "Couldn't find coil in the package config. Add it to your "
      'dependencies and run `flutter pub get`.',
    );
  }
  return CoilSource(p.fromUri(coil.root));
}

String _appName(String appRoot) {
  final match = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File(p.join(appRoot, 'pubspec.yaml')).readAsStringSync());
  return match?.group(1) ?? 'your_app';
}

Future<int> _run(StringSink out, Future<int> Function() body) async {
  try {
    return await body();
  } on EjectException catch (e) {
    (out == stdout ? stderr : out).writeln(e.message);
    return 1;
  } on FormatException catch (e) {
    (out == stdout ? stderr : out).writeln(e.message);
    return 64;
  }
}
