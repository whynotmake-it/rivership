// coil:eject and coil:update on a temp app, against a copy of coil's Button
// that the tests change to play "upstream". Needs git for the merges.
@TestOn('vm')
library;

import 'dart:io';

import 'package:coil/src/eject/cli.dart';
import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/manifest.dart';
import 'package:coil/src/eject/operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _appLine = '  /// The surface color. Default motion: `fade`.';

void main() {
  late Directory temp;
  late String upstream;
  late String app;

  CoilSource coil() => CoilSource(upstream);
  File upstreamFile(String path) => File(p.join(upstream, 'lib', path));
  File appFile(String path) => File(p.join(app, 'lib/coil/button', path));
  File baseFile(String path) => File(p.join(app, '.coil/base/button', path));
  Map<String, String> versions() =>
      Manifest.read(app).components['button']!.files;

  /// Publishes a new upstream version with [edit] applied to [path].
  void release(String version, String path, String Function(String) edit) {
    upstreamFile(path).writeAsStringSync(
      edit(upstreamFile(path).readAsStringSync()),
    );
    File(
      p.join(upstream, 'pubspec.yaml'),
    ).writeAsStringSync('name: coil\nversion: $version\n');
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coil_eject');
    upstream = p.join(temp.path, 'coil');
    app = p.join(temp.path, 'app');
    for (final path in [
      'button.dart',
      'foundation.dart',
      'primitives.dart',
      for (final file in Directory(
        'lib/src/components/button',
      ).listSync().whereType<File>())
        p.relative(file.path, from: 'lib'),
    ]) {
      File(p.join('lib', path)).copySync(
        (upstreamFile(path)..createSync(recursive: true)).path,
      );
    }
    File(p.join(upstream, 'pubspec.yaml')).writeAsStringSync(
      'name: coil\nversion: 1.0.0\n',
    );
    File(p.join(app, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: app\n');
    eject(coil(), app, 'button');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('eject copies the component, its base and an app library', () {
    expect(
      appFile('button.dart').readAsStringSync(),
      contains("export 'src/button.dart';"),
    );
    expect(
      appFile('src/button.dart').readAsStringSync(),
      allOf(
        contains("import 'button_style.dart';"),
        contains("import 'package:coil/foundation.dart';"),
        isNot(contains('package:coil/src/')),
      ),
    );
    expect(
      baseFile('src/button.dart').readAsStringSync(),
      appFile('src/button.dart').readAsStringSync(),
    );
    expect(versions(), {
      'button.dart': '1.0.0',
      'src/button.dart': '1.0.0',
      'src/button_style.dart': '1.0.0',
      'src/button_variant.dart': '1.0.0',
    });
    expect(
      File(p.join(app, 'lib/coil.dart')).readAsStringSync(),
      allOf(
        contains(
          "export 'package:coil/coil.dart'\n"
          '    hide CoilButton, CoilButtonStyle, CoilButtonTrack, '
          'CoilButtonVariant;',
        ),
        contains("export 'coil/button/button.dart';"),
      ),
    );
  });

  test('eject refuses to replace an earlier eject unless forced', () {
    appFile('src/button.dart').writeAsStringSync('// mine');
    expect(() => eject(coil(), app, 'button'), throwsA(isA<EjectException>()));
    expect(appFile('src/button.dart').readAsStringSync(), '// mine');

    eject(coil(), app, 'button', force: true);
    expect(appFile('src/button.dart').readAsStringSync(), contains('class'));
  });

  test('update merges upstream changes into an edited copy', () {
    appFile('src/button.dart').writeAsStringSync(
      appFile(
        'src/button.dart',
      ).readAsStringSync().replaceFirst(_appLine, '  /// Our fill.'),
    );
    release('1.1.0', 'src/components/button/button.dart', (s) {
      return '$s\n// Upstream addition.\n';
    });

    final result = update(coil(), app, 'button');

    expect(result.files['src/button.dart'], FileUpdate.merged);
    expect(result.needsAttention, isEmpty);
    expect(
      appFile('src/button.dart').readAsStringSync(),
      allOf(contains('/// Our fill.'), contains('// Upstream addition.')),
    );
    expect(versions()['src/button.dart'], '1.1.0');
    expect(
      baseFile('src/button.dart').readAsStringSync(),
      contains('// Upstream addition.'),
    );
  });

  test('a conflict leaves markers and keeps that file on its old base', () {
    final before = baseFile('src/button.dart').readAsStringSync();
    appFile('src/button.dart').writeAsStringSync(
      appFile(
        'src/button.dart',
      ).readAsStringSync().replaceFirst(_appLine, '  /// Ours.'),
    );
    release('1.1.0', 'src/components/button/button.dart', (s) {
      return s.replaceFirst(_appLine, '  /// Theirs.');
    });
    release('1.1.0', 'src/components/button/button_style.dart', (s) {
      return '$s\n// Upstream style change.\n';
    });

    final result = update(coil(), app, 'button');

    expect(result.files['src/button.dart'], FileUpdate.conflict);
    expect(result.files['src/button_style.dart'], FileUpdate.merged);
    expect(
      appFile('src/button.dart').readAsStringSync(),
      allOf(
        contains('\n<<<<<<< app\n  /// Ours.\n=======\n  /// Theirs.\n'),
        contains('\n>>>>>>> coil 1.1.0\n'),
      ),
    );
    expect(versions()['src/button.dart'], '1.0.0');
    expect(baseFile('src/button.dart').readAsStringSync(), before);
    expect(versions()['src/button_style.dart'], '1.1.0');
  });

  test('update adds and removes files that upstream added and removed', () {
    const export = "export 'src/components/button/button_size.dart';";
    upstreamFile(
      'src/components/button/button_size.dart',
    ).writeAsStringSync('enum CoilButtonSize { small, large }\n');
    release('1.1.0', 'button.dart', (s) => '$s$export\n');

    final added = update(coil(), app, 'button');

    expect(added.files['src/button_size.dart'], FileUpdate.added);
    expect(appFile('src/button_size.dart').existsSync(), isTrue);
    expect(versions()['src/button_size.dart'], '1.1.0');
    expect(
      File(p.join(app, 'lib/coil.dart')).readAsStringSync(),
      contains('CoilButtonSize'),
    );

    upstreamFile('src/components/button/button_size.dart').deleteSync();
    release('1.2.0', 'button.dart', (s) => s.replaceFirst('$export\n', ''));

    final removed = update(coil(), app, 'button');

    expect(removed.files['src/button_size.dart'], FileUpdate.removed);
    expect(appFile('src/button_size.dart').existsSync(), isFalse);
    expect(baseFile('src/button_size.dart').existsSync(), isFalse);
    expect(versions().keys, isNot(contains('src/button_size.dart')));
  });

  test('--dry-run shows the change and writes nothing', () async {
    release('1.1.0', 'src/components/button/button.dart', (s) {
      return s.replaceFirst(_appLine, '  /// Theirs.');
    });
    final copy = appFile('src/button.dart').readAsStringSync();
    final manifest = File(p.join(app, Manifest.path)).readAsStringSync();

    final result = update(coil(), app, 'button', dryRun: true);

    expect(result.files['src/button.dart'], FileUpdate.merged);
    expect(result.diff, contains('+  /// Theirs.'));
    expect(appFile('src/button.dart').readAsStringSync(), copy);
    expect(File(p.join(app, Manifest.path)).readAsStringSync(), manifest);
  });

  test('--list shows every component', () async {
    final out = StringBuffer();
    expect(await ejectCommand(['--list'], appRoot: '.', out: out), 0);
    final components = [
      for (final dir in Directory('lib/src/components').listSync())
        if (dir is Directory) p.basename(dir.path),
    ];
    final listed = [
      for (final line in out.toString().split('\n').skip(1))
        if (line.trim().isNotEmpty) line.substring(2).split(' ').first,
    ];
    expect(listed, unorderedEquals(components));
  });
}
