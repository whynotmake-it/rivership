// coil:eject and coil:update on a temp app, against a copy of coil that the
// tests change to play "upstream". Needs git for the merges.
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:coil/src/eject/cli.dart';
import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/manifest.dart';
import 'package:coil/src/eject/operations.dart';
import 'package:coil/src/eject/transform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/src/temp_app.dart';

const _line = '  /// The surface color. Default motion: `fade`.';
const _acme = EjectOptions(prefix: 'Acme');

void main() {
  late Directory temp;
  late String upstream;
  late String app;
  late EjectWorkspace workspace;

  File upstreamFile(String path) => File(p.join(upstream, 'lib', path));
  File appFile(String path) => File(p.join(app, path));
  String read(String path) => appFile(path).readAsStringSync();
  void edit(String path, String Function(String) change) =>
      appFile(path).writeAsStringSync(change(read(path)));
  Map<String, EjectedFile> files(String component) =>
      Manifest.read(app).components[component]!.files;

  /// Publishes [version] upstream with [change] applied to [path].
  void release(String version, String path, String Function(String) change) {
    upstreamFile(
      path,
    ).writeAsStringSync(change(upstreamFile(path).readAsStringSync()));
    File(
      p.join(upstream, 'pubspec.yaml'),
    ).writeAsStringSync('name: coil\nversion: $version\n');
  }

  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('coil_update');
    upstream = p.join(temp.path, 'coil');
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File) continue;
      final out = File(p.join(upstream, file.path));
      out.parent.createSync(recursive: true);
      file.copySync(out.path);
    }
    final appDir = await createTempApp(coilRoot: upstream);
    app = appDir.path;
    workspace = await EjectWorkspace.open(CoilSource('.'), app);
  });

  setUp(() {
    // A fresh app and coil 1.0.0 as it is in this checkout.
    for (final dir in ['lib', '.coil']) {
      if (Directory(p.join(app, dir)).existsSync()) {
        Directory(p.join(app, dir)).deleteSync(recursive: true);
      }
    }
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is File) {
        file.copySync(p.join(upstream, file.path));
      }
    }
    File(
      p.join(upstream, 'pubspec.yaml'),
    ).writeAsStringSync('name: coil\nversion: 1.0.0\n');
    workspace.coil = CoilSource(upstream);
  });

  tearDownAll(() => temp.deleteSync(recursive: true));

  group('without renames', () {
    setUp(() => eject(workspace, ['button']));

    test('eject copies the component, its base and an app library', () {
      final button = read('lib/coil/button/src/button.dart');
      expect(button, contains("import 'package:coil/foundation.dart';"));
      expect(button, isNot(contains('package:coil/src/')));
      // Relative imports last, as directives_ordering wants.
      expect(
        button.indexOf("import 'button_style.dart';"),
        greaterThan(button.indexOf("import 'package:motor/motor.dart';")),
      );
      expect(read('.coil/base/button/src/button.dart'), button);
      expect(files('button').map((k, v) => MapEntry(k, v.version)), {
        'button.dart': '1.0.0',
        'src/button.dart': '1.0.0',
        'src/button_style.dart': '1.0.0',
        'src/button_variant.dart': '1.0.0',
      });
      expect(
        read('lib/coil.dart'),
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

    test('eject refuses to replace an earlier eject unless forced', () async {
      appFile('lib/coil/button/src/button.dart').writeAsStringSync('// mine');
      await expectLater(
        eject(workspace, ['button']),
        throwsA(isA<EjectException>()),
      );
      expect(read('lib/coil/button/src/button.dart'), '// mine');

      await eject(
        workspace,
        ['button'],
        options: const EjectOptions(force: true),
      );
      expect(read('lib/coil/button/src/button.dart'), contains('class'));
    });

    test('update merges upstream changes into an edited copy', () async {
      edit(
        'lib/coil/button/src/button.dart',
        (s) => s.replaceFirst(_line, '  /// Our fill.'),
      );
      release('1.1.0', 'src/components/button/button.dart', (s) {
        return '$s\n// Upstream addition.\n';
      });

      final result = await update(workspace, 'button');

      expect(result.files['src/button.dart'], FileUpdate.merged);
      expect(result.needsAttention, isEmpty);
      expect(
        read('lib/coil/button/src/button.dart'),
        allOf(contains('/// Our fill.'), contains('// Upstream addition.')),
      );
      expect(files('button')['src/button.dart']!.version, '1.1.0');
      expect(
        read('.coil/base/button/src/button.dart'),
        contains('// Upstream addition.'),
      );
    });

    test(
      'a conflict leaves markers and keeps that file on its old base',
      () async {
        final before = read('.coil/base/button/src/button.dart');
        edit(
          'lib/coil/button/src/button.dart',
          (s) => s.replaceFirst(_line, '  /// Ours.'),
        );
        release('1.1.0', 'src/components/button/button.dart', (s) {
          return s.replaceFirst(_line, '  /// Theirs.');
        });
        release('1.1.0', 'src/components/button/button_style.dart', (s) {
          return '$s\n// Upstream style change.\n';
        });

        final result = await update(workspace, 'button');

        expect(result.files['src/button.dart'], FileUpdate.conflict);
        expect(result.files['src/button_style.dart'], FileUpdate.merged);
        expect(
          read('lib/coil/button/src/button.dart'),
          allOf(
            contains('\n<<<<<<< app\n  /// Ours.\n=======\n  /// Theirs.\n'),
            contains('\n>>>>>>> coil 1.1.0\n'),
          ),
        );
        expect(files('button')['src/button.dart']!.version, '1.0.0');
        expect(read('.coil/base/button/src/button.dart'), before);
        expect(files('button')['src/button_style.dart']!.version, '1.1.0');
      },
    );

    test(
      'update adds and removes files that upstream added and removed',
      () async {
        const export = "export 'src/components/button/button_size.dart';";
        upstreamFile(
          'src/components/button/button_size.dart',
        ).writeAsStringSync('enum CoilButtonSize { small, large }\n');
        release('1.1.0', 'button.dart', (s) => '$s$export\n');

        final added = await update(workspace, 'button');

        expect(added.files['src/button_size.dart'], FileUpdate.added);
        expect(
          appFile('lib/coil/button/src/button_size.dart').existsSync(),
          isTrue,
        );
        expect(files('button')['src/button_size.dart']!.version, '1.1.0');
        expect(read('lib/coil.dart'), contains('CoilButtonSize'));

        upstreamFile('src/components/button/button_size.dart').deleteSync();
        release('1.2.0', 'button.dart', (s) => s.replaceFirst('$export\n', ''));

        final removed = await update(workspace, 'button');

        expect(removed.files['src/button_size.dart'], FileUpdate.removed);
        expect(
          appFile('lib/coil/button/src/button_size.dart').existsSync(),
          isFalse,
        );
        expect(
          appFile('.coil/base/button/src/button_size.dart').existsSync(),
          isFalse,
        );
        expect(files('button').keys, isNot(contains('src/button_size.dart')));
      },
    );

    test('--dry-run shows the change and writes nothing', () async {
      release('1.1.0', 'src/components/button/button.dart', (s) {
        return s.replaceFirst(_line, '  /// Theirs.');
      });
      final copy = read('lib/coil/button/src/button.dart');
      final manifest = read(Manifest.path);

      final result = await update(workspace, 'button', dryRun: true);

      expect(result.files['src/button.dart'], FileUpdate.merged);
      expect(result.diff, contains('+  /// Theirs.'));
      expect(read('lib/coil/button/src/button.dart'), copy);
      expect(read(Manifest.path), manifest);
    });
  });

  group('with a prefix', () {
    setUp(() => eject(workspace, ['button'], options: _acme));

    test('renames declarations, references, doc links and files', () {
      final button = read('lib/acme/button/src/acme_button.dart');
      expect(button, contains('class AcmeButton extends StatefulWidget'));
      expect(button, contains('State<AcmeButton> createState()'));
      expect(button, contains('this.variant = AcmeButtonVariant.primary'));
      expect(button, contains("import 'acme_button_style.dart';"));
      expect(button, contains('[AcmeButtonTrack]'));
      // Strings, private names and members stay as they are.
      expect(button, contains("debugLabel: 'CoilButton.fill'"));
      expect(button, contains('class _CoilButtonState'));
      // Outside strings and `code` spans, no reference to coil's name is left.
      expect(
        button.replaceAll(RegExp(r"'[^'\n]*'|`[^`\n]*`"), ''),
        isNot(contains(RegExp(r'\bCoilButton\b'))),
      );
      expect(
        read('lib/acme/button/acme_button.dart'),
        contains("export 'src/acme_button.dart';"),
      );
      expect(Manifest.read(app).naming.renames, {
        'CoilButton': 'AcmeButton',
        'CoilButtonStyle': 'AcmeButtonStyle',
        'CoilButtonTrack': 'AcmeButtonTrack',
        'CoilButtonVariant': 'AcmeButtonVariant',
      });
      expect(
        read('lib/acme.dart'),
        allOf(
          contains("export 'acme/button/acme_button.dart';"),
          contains('typedef AcmeTheme = CoilTheme;'),
        ),
      );
    });

    test('an upstream change merges cleanly into the renamed copy', () async {
      edit(
        'lib/acme/button/src/acme_button.dart',
        (s) => s.replaceFirst(_line, '  /// Our fill.'),
      );
      release('1.1.0', 'src/components/button/button.dart', (s) {
        // A change that mentions the renamed names, far from our edit.
        return '$s\n/// See [CoilButton].\nconst coilButtonDefault = '
            'CoilButtonVariant.primary;\n';
      });

      final result = await update(workspace, 'button');

      expect(result.files['src/button.dart'], FileUpdate.merged);
      expect(
        read('lib/acme/button/src/acme_button.dart'),
        allOf(
          contains('/// Our fill.'),
          contains('/// See [AcmeButton].'),
          contains('const coilButtonDefault = AcmeButtonVariant.primary;'),
        ),
      );
    });

    test('a conflicting edit to the renamed copy still gets markers', () async {
      edit(
        'lib/acme/button/src/acme_button.dart',
        (s) => s.replaceFirst(_line, '  /// Ours.'),
      );
      release('1.1.0', 'src/components/button/button.dart', (s) {
        return s.replaceFirst(_line, '  /// Theirs.');
      });

      final result = await update(workspace, 'button');

      expect(result.files['src/button.dart'], FileUpdate.conflict);
      expect(
        read('lib/acme/button/src/acme_button.dart'),
        contains('\n<<<<<<< app\n  /// Ours.\n=======\n  /// Theirs.\n'),
      );
      expect(files('button')['src/button.dart']!.version, '1.0.0');
    });

    test('renaming is idempotent across updates', () async {
      final copy = read('lib/acme/button/src/acme_button.dart');
      final manifest = read(Manifest.path);
      for (var i = 0; i < 2; i++) {
        final result = await update(workspace, 'button');
        expect(result.files.values, everyElement(FileUpdate.unchanged));
      }
      expect(read('lib/acme/button/src/acme_button.dart'), copy);
      expect(read('.coil/base/button/src/acme_button.dart'), copy);
      expect(read(Manifest.path), manifest);
    });

    test('a later eject points earlier copies at the new one', () async {
      // Button first, then Dialog: Dialog's copy uses AcmeButton at once.
      await eject(workspace, ['dialog']);
      final dialog = read('lib/acme/dialog/src/acme_dialog.dart');
      expect(dialog, contains("import '../../button/acme_button.dart';"));
      expect(dialog, contains('AcmeButton.icon('));
      expect(Manifest.read(app).components['dialog']!.uses, {'button'});

      // The same set ejected the other way round comes out identical.
      final together = {
        for (final f in files('dialog').values)
          f.path: read('lib/acme/dialog/${f.path}'),
      };
      Directory(p.join(app, 'lib')).deleteSync(recursive: true);
      Directory(p.join(app, '.coil')).deleteSync(recursive: true);
      await eject(workspace, ['dialog'], options: _acme);
      expect(
        read('lib/acme/dialog/src/acme_dialog.dart'),
        contains('CoilButton.icon('),
      );
      await eject(workspace, ['button']);
      for (final MapEntry(key: path, value: content) in together.entries) {
        expect(read('lib/acme/dialog/$path'), content, reason: path);
        expect(read('.coil/base/dialog/$path'), content, reason: path);
      }
      expect(Manifest.read(app).components['dialog']!.uses, {'button'});
    });
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
