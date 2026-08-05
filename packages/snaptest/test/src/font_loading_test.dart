import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/src/font_loading.dart';
import 'package:snaptest/src/snap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontBinaryLoader', () {
    test(
      'uses the filesystem for existing paths and bundle otherwise',
      () async {
        final reads = <String>[];
        final registrations = <(String, List<int>)>[];
        final loader = FontBinaryLoader(
          fileExists: (path) => path == '/fonts/on-disk.ttf',
          readFile: (path) async {
            reads.add('file:$path');
            return _bytes(1);
          },
          readBundle: (path) async {
            reads.add('bundle:$path');
            return _bytes(2);
          },
          register: (family, fonts) async {
            registrations.add((
              family,
              fonts.map((data) => data.getUint8(0)).toList(),
            ));
          },
          runAsync: <T>(operation) => operation(),
        );

        await loader.load('Example', [
          '/fonts/on-disk.ttf',
          'assets/in-bundle.otf',
        ]);

        expect(reads, [
          'file:/fonts/on-disk.ttf',
          'bundle:assets/in-bundle.otf',
        ]);
        expect(registrations, hasLength(1));
        expect(registrations.single.$1, 'Example');
        expect(registrations.single.$2, [1, 2]);
      },
    );

    test('does nothing for an empty path list', () async {
      var enteredAsyncScope = false;
      var registered = false;
      final loader = FontBinaryLoader(
        fileExists: (_) => false,
        readFile: (_) => throw UnimplementedError(),
        readBundle: (_) => throw UnimplementedError(),
        register: (_, _) async => registered = true,
        runAsync: <T>(operation) async {
          enteredAsyncScope = true;
          return operation();
        },
      );

      await loader.load('Empty', const []);

      expect(enteredAsyncScope, isFalse);
      expect(registered, isFalse);
    });

    testWidgets('can execute while already inside runAsync', (tester) async {
      var registered = false;
      final loader = FontBinaryLoader(
        fileExists: (_) => false,
        readFile: (_) => throw UnimplementedError(),
        readBundle: (_) async => _bytes(7),
        register: (_, fonts) async {
          registered = fonts.single.getUint8(0) == 7;
        },
        runAsync: maybeRunAsync,
      );

      await tester.runAsync(
        () => loader.load('Nested', const ['assets/font.ttf']),
      );

      expect(registered, isTrue);
    });
  });

  group('material font discovery', () {
    test('selects supported Roboto, condensed, and icon files only', () {
      final fonts = discoverMaterialFonts([
        '/sdk/Roboto-Regular.ttf',
        '/sdk/Roboto-Bold.OTF',
        '/sdk/Roboto.txt',
        '/sdk/RobotoCondensed-Regular.ttf',
        '/sdk/MaterialIcons-Regular.otf',
        '/sdk/MaterialIconsOutlined-Regular.ttf',
        '/sdk/Other.ttf',
      ]);

      expect(fonts.roboto, [
        '/sdk/Roboto-Regular.ttf',
        '/sdk/Roboto-Bold.OTF',
      ]);
      expect(fonts.robotoCondensed, [
        '/sdk/RobotoCondensed-Regular.ttf',
      ]);
      expect(fonts.materialIcons, [
        '/sdk/MaterialIcons-Regular.otf',
        '/sdk/MaterialIconsOutlined-Regular.ttf',
      ]);
    });
  });

  group('FontManifest', () {
    test('keeps app families and aliases package families', () {
      final entries = decodeFontManifest('''
[
  {
    "family": "AppFont",
    "fonts": [{"asset": "assets/app.ttf"}]
  },
  {
    "family": "PackageFont",
    "fonts": [{"asset": "packages/toolkit/fonts/package.ttf"}]
  },
  {
    "family": "packages/widgets/QualifiedFont",
    "fonts": [{"asset": "packages/widgets/fonts/qualified.ttf"}]
  }
]
''');

      expect(fontRegistrationsForManifest(entries), [
        const FontRegistration('AppFont', ['assets/app.ttf']),
        const FontRegistration(
          'PackageFont',
          ['packages/toolkit/fonts/package.ttf'],
        ),
        const FontRegistration(
          'packages/toolkit/PackageFont',
          ['packages/toolkit/fonts/package.ttf'],
        ),
        const FontRegistration(
          'QualifiedFont',
          ['packages/widgets/fonts/qualified.ttf'],
        ),
        const FontRegistration(
          'packages/widgets/QualifiedFont',
          ['packages/widgets/fonts/qualified.ttf'],
        ),
      ]);
    });

    test('finds both app and package-qualified family names', () {
      const entries = [
        FontManifestEntry('Custom', ['assets/custom.ttf']),
        FontManifestEntry(
          'packages/theme/Custom',
          ['packages/theme/custom-bold.ttf'],
        ),
      ];

      expect(fontAssetsForFamily(entries, 'Custom'), [
        'assets/custom.ttf',
        'packages/theme/custom-bold.ttf',
      ]);
    });
  });

  group('FontLoadingOrchestrator', () {
    test('is idempotent after a successful load', () async {
      final harness = _Harness();
      final orchestrator = harness.create();

      await orchestrator.load();
      final firstLoad = List.of(harness.loads);
      await orchestrator.load();

      expect(harness.loads, firstLoad);
      expect(harness.manifestReads, 1);
      expect(harness.directoryReads, 1);
    });

    test('applies a custom Cupertino override from the manifest', () async {
      final harness = _Harness(
        manifest: '''
[
  {
    "family": "Inter",
    "fonts": [{"asset": "assets/inter.ttf"}]
  }
]
''',
      );

      await harness.create().load(
        const CupertinoFontConfig.override(fontFamily: 'Inter'),
      );

      expect(
        harness.loads,
        contains(
          const FontRegistration('CupertinoSystemText', ['assets/inter.ttf']),
        ),
      );
      expect(
        harness.loads,
        contains(
          const FontRegistration('CupertinoSystemDisplay', [
            'assets/inter.ttf',
          ]),
        ),
      );
    });

    test(
      'uses the configured fallback when macOS fonts are unavailable',
      () async {
        final harness = _Harness(
          manifest: '''
[
  {
    "family": "Fallback",
    "fonts": [{"asset": "assets/fallback.ttf"}]
  }
]
''',
        );

        await harness.create().load(
          const CupertinoFontConfig.fromMacOsSystemFonts(
            fallbackOverride: 'Fallback',
          ),
        );

        expect(
          harness.loads,
          containsAll([
            const FontRegistration(
              'CupertinoSystemText',
              ['assets/fallback.ttf'],
            ),
            const FontRegistration(
              'CupertinoSystemDisplay',
              ['assets/fallback.ttf'],
            ),
          ]),
        );
      },
    );

    test('registers matching macOS text and display families', () async {
      final harness = _Harness(isMacOS: true);

      await harness.create().load(
        const CupertinoFontConfig.fromMacOsSystemFonts(),
      );

      expect(
        harness.loads,
        containsAll([
          const FontRegistration(
            'CupertinoSystemText',
            ['/Library/Fonts/SF-Pro-Text-Regular.otf'],
          ),
          const FontRegistration(
            'CupertinoSystemDisplay',
            ['/Library/Fonts/SF-Pro-Display-Regular.otf'],
          ),
        ]),
      );
    });

    test('throws without a Cupertino fallback off macOS', () async {
      final harness = _Harness();

      await expectLater(
        harness.create().load(
          const CupertinoFontConfig.fromMacOsSystemFonts(),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

ByteData _bytes(int value) => Uint8List.fromList([value]).buffer.asByteData();

class _Harness {
  _Harness({
    this.manifest = '[]',
    this.isMacOS = false,
  });

  final String manifest;
  final bool isMacOS;
  final loads = <FontRegistration>[];
  int manifestReads = 0;
  int directoryReads = 0;

  FontLoadingOrchestrator create() => FontLoadingOrchestrator(
    sdkRoot: () => Directory('/fake/flutter'),
    isMacOS: isMacOS,
    readManifest: () async {
      manifestReads++;
      return manifest;
    },
    listFontFiles: (directory, {required recursive}) {
      directoryReads++;
      if (directory.path.endsWith('material_fonts')) {
        return [
          '${directory.path}/Roboto-Regular.ttf',
          '${directory.path}/RobotoCondensed-Regular.ttf',
          '${directory.path}/MaterialIcons-Regular.otf',
        ];
      }
      if (isMacOS && directory.path == '/Library/Fonts') {
        return const [
          '/Library/Fonts/SF-Pro-Text-Regular.otf',
          '/Library/Fonts/SF-Pro-Display-Regular.otf',
        ];
      }
      return const [];
    },
    loadFamily: (family, paths) async {
      loads.add(FontRegistration(family, paths));
    },
    log: (_) {},
  );
}
