// End to end: a fresh app depends on this coil, ejects every component
// under its own prefix with the real CLI, still analyzes cleanly, and
// renders its copies, which use each other.
@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import '../src/coil_root.dart';

void main() {
  late Directory app;
  late String flutter;
  late String dart;

  Future<ProcessResult> run(String executable, List<String> args) async {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: app.path,
    );
    expect(
      result.exitCode,
      0,
      reason:
          '${[p.basename(executable), ...args].join(' ')}\n'
          '${result.stdout}\n${result.stderr}',
    );
    return result;
  }

  setUpAll(() async {
    final config = (await findPackageConfig(Directory.current))!;
    final sdk = p.normalize(
      p.join(p.fromUri(config['flutter']!.root), '../..'),
    );
    flutter = p.join(sdk, 'bin', 'flutter');
    dart = p.join(sdk, 'bin', 'dart');
    // Outside the workspace, coil's path dependencies would resolve their
    // own dependencies from pub.dev, so point them all at this checkout
    // (pub writes relative roots only for path and workspace packages).
    final overrides = [
      for (final package in config.packages)
        if (package.relativeRoot)
          '  ${package.name}:\n    path: ${p.fromUri(package.root)}',
    ];
    app = Directory.systemTemp.createTempSync('coil_app');
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture_app
publish_to: none
environment:
  sdk: ">=3.12.0 <4.0.0"
dependencies:
  coil:
    path: ${coilRoot()}
  flutter:
    sdk: flutter
dev_dependencies:
  coil_cli:
    path: ${Directory.current.absolute.path}
  flutter_test:
    sdk: flutter
dependency_overrides:
${overrides.join('\n')}
''');
    File(p.join(app.path, 'test', 'button_test.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(_buttonTest);
    await run(flutter, ['pub', 'get', '--offline']);
  });

  tearDownAll(() => app.deleteSync(recursive: true));

  test('an app ejects everything as Acme, analyzes and renders it', () async {
    final eject = await run(dart, [
      'run',
      'coil_cli:eject',
      '--all',
      '--prefix',
      'Acme',
    ]);
    expect(eject.stdout, contains('Ejected button'));
    expect(
      File(p.join(app.path, 'lib', 'acme', 'button', 'acme_button.dart')),
      _exists,
    );

    await run(dart, ['analyze', '--fatal-infos']);
    await run(flutter, ['test']);
  });
}

final _exists = predicate<File>((f) => f.existsSync(), 'exists');

/// The fixture's own test: the app library's CoilButton is the ejected
/// copy, not coil's, and it is still a button.
const _buttonTest = '''
import 'package:coil/button.dart' as coil;
import 'package:coil_cli/testing.dart';
import 'package:fixture_app/acme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) =>
      AcmeTheme(data: AcmeThemeData.light, child: navigator!),
  onGenerateRoute: (_) => PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => Center(child: child),
  ),
);

void main() {
  testWidgets('AcmeButton renders and is a button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(AcmeButton(onPressed: () => taps++, child: const Text('Save'))),
    );
    final button = find.byType(AcmeButton);
    expect(button, findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(button);
    expect(taps, 1);
    await expectCoilPattern(tester, button, CoilPattern.button);
  });

  testWidgets('AcmeDialog renders and closes with an AcmeButton', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _app(
        AcmeDialog(
          title: const Text('Delete file?'),
          onClose: () => closed++,
          actions: [
            AcmeButton(onPressed: () {}, child: const Text('Delete')),
          ],
        ),
      ),
    );
    expect(find.text('Delete file?'), findsOneWidget);
    final close = find.descendant(
      of: find.byType(AcmeDialog),
      matching: find.bySemanticsLabel('Close'),
    );
    expect(
      find.ancestor(of: close, matching: find.byType(AcmeButton)),
      findsOneWidget,
      reason: "the dialog's close button is the app's copy",
    );
    expect(find.byType(coil.CoilButton), findsNothing);
    await tester.tap(close);
    expect(closed, 1);
  });
}
''';
