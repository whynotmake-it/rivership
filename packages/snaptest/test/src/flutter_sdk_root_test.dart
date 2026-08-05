import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/src/flutter_sdk_root.dart';

void main() {
  group('flutterSdkRootFromExecutable', () {
    test('derives a POSIX SDK root from flutter_tester', () {
      expect(
        flutterSdkRootFromExecutable(
          '/opt/flutter/bin/cache/artifacts/engine/linux-x64/flutter_tester',
          windows: false,
        ).path,
        '/opt/flutter',
      );
    });

    test('derives a Windows SDK root with either separator style', () {
      expect(
        flutterSdkRootFromExecutable(
          r'C:\tools\flutter\bin\cache\artifacts\engine\windows-x64\flutter_tester.exe',
          windows: true,
        ).path,
        r'C:\tools\flutter',
      );
      expect(
        flutterSdkRootFromExecutable(
          'C:/tools/flutter/bin/cache/artifacts/engine/windows-x64/flutter_tester.exe',
          windows: true,
        ).path,
        r'C:\tools\flutter',
      );
    });

    test('rejects executables outside a Flutter SDK cache', () {
      expect(
        () => flutterSdkRootFromExecutable(
          '/usr/local/bin/dart',
          windows: false,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
