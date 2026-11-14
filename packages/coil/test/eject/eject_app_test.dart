// End to end: a fresh app depends on this coil, ejects Button with the real
// CLI, still analyzes cleanly, and renders its own copy.
@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

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
    path: ${Directory.current.absolute.path}
  flutter:
    sdk: flutter
dev_dependencies:
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

  test('an app ejects Button, analyzes cleanly and renders its copy', () async {
    final eject = await run(dart, ['run', 'coil:eject', 'button']);
    expect(eject.stdout, contains('Ejected button'));
    expect(
      File(p.join(app.path, 'lib', 'coil', 'button', 'button.dart')),
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
import 'package:coil/button.dart' as package;
import 'package:coil/testing.dart';
import 'package:fixture_app/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the ejected CoilButton renders and is a button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => Center(
            child: CoilButton(
              onPressed: () => taps++,
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(CoilButton);
    expect(button, findsOneWidget);
    expect(find.byType(package.CoilButton), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(button);
    expect(taps, 1);
    await expectCoilPattern(tester, button, CoilPattern.button);
  });
}
''';
