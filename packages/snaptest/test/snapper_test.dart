// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  group('Snapper', () {
    setUp(SnaptestSettings.resetGlobal);

    group('snap function', () {
      testWidgets('my widget test', (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar.large(
                largeTitle: Text("Snaptest"),
              ),
              child: Center(
                child: CupertinoButton(
                  child: const Text("Wow!"),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        await snap(
          device: Devices.ios.iPhone16,
          settings: const SnaptestSettings.rendered(),
        );
      });

      snapTest('captures basic widget snapshot', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Hello Snapper!'))),
          ),
        );

        final ([file], [goldenFile]) = await snap.andGolden();
        expect(file.existsSync(), isTrue);
        expect(goldenFile.existsSync(), isTrue);
      });

      snapTest('captures widget with explicit device', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Device Test'))),
          ),
        );

        final [file] = await snap(
          name: 'explicit_device',
          device: Devices.ios.iPhone16Pro,
        );

        expect(file.existsSync(), isTrue);
        expect(file.path, contains('iPhone 16 Pro'));
      });

      snapTest('captures specific widget using finder', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('App Bar')),
              body: const Center(
                child: RepaintBoundary(
                  child: Card(
                    key: Key('test-card'),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Card Content'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final [file] = await snap(
          name: 'specific_widget',
          from: find.byKey(const Key('test-card')),
        );

        expect(file.existsSync(), isTrue);
      });

      snapTest('handles custom path prefix', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Custom Path Test'))),
          ),
        );

        final [file] = await snap(
          name: 'custom_path',
          settings: const SnaptestSettings(pathPrefix: 'custom_screenshots/'),
        );

        expect(file.path, contains('custom_screenshots'));
        expect(file.existsSync(), isTrue);
      });

      snapTest('appends device name when device is explicit', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Device Name Test'))),
          ),
        );

        final [fileWithDevice] = await snap(
          name: 'with_device_name',
          device: Devices.ios.iPhone16Pro,
        );

        final [fileWithoutDevice] = await snap(
          name: 'without_device_name',
        );

        expect(fileWithDevice.path, contains('iPhone 16 Pro'));
        expect(
          fileWithoutDevice.path,
          isNot(contains('iPhone 16 Pro')),
        );
      });

      testWidgets('works from within runAsync', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Async Snap Test'))),
          ),
        );

        await tester.runAsync(() async {
          final [file] = await snap(
            name: 'run_async_snap',
            settings: const SnaptestSettings(),
          );

          expect(file.existsSync(), isTrue);
        });
      });

      snapTest(
        'appends counter when snap is called multiple times',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Test 1'),
                ),
              ),
            ),
          );

          // First call - no counter
          final [file1] = await snap();
          expect(
            file1.path,
            contains('appends counter when snap is called multiple times.png'),
          );

          // Update the widget
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Test 2'),
                ),
              ),
            ),
          );

          // Second call - counter suffix _2
          final [file2] = await snap();
          expect(
            file2.path,
            contains(
              'appends counter when snap is called multiple times_2.png',
            ),
          );

          // Update the widget again
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Test 3'),
                ),
              ),
            ),
          );

          // Third call - counter suffix _3
          final [file3] = await snap();
          expect(
            file3.path,
            contains(
              'appends counter when snap is called multiple times_3.png',
            ),
          );

          // Verify all files exist and are different
          expect(file1.existsSync(), isTrue);
          expect(file2.existsSync(), isTrue);
          expect(file3.existsSync(), isTrue);
          expect(file1.path, isNot(equals(file2.path)));
          expect(file2.path, isNot(equals(file3.path)));
        },
      );

      snapTest(
        'counter works with explicit device suffix',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Multi-device test'),
                ),
              ),
            ),
          );

          // First call with explicit device
          final [file1] = await snap(device: Devices.ios.iPhone16Pro);
          expect(
            file1.path,
            contains(
              'counter works with explicit device suffix_iPhone 16 Pro.png',
            ),
          );

          // Second call - counter should come before device name
          final [file2] = await snap(device: Devices.ios.iPhone16Pro);
          expect(
            file2.path,
            contains(
              'counter works with explicit device suffix_2_iPhone 16 Pro.png',
            ),
          );
        },
      );

      snapTest(
        'counter does not affect named snaps',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Named snap'),
                ),
              ),
            ),
          );

          // First call with custom name
          final [file1] = await snap(name: 'custom_name');
          expect(file1.path, contains('custom_name.png'));

          // Second call with the same custom name
          final [file2] = await snap(name: 'custom_name');
          expect(file2.path, contains('custom_name_2.png'));

          // Third call with different name - should not have counter
          final [file3] = await snap(name: 'another_name');
          expect(file3.path, contains('another_name.png'));
        },
      );
    });

    group('SnaptestSettings', () {
      test('has correct default values', () {
        SnaptestSettings.resetGlobal();
        expect(SnaptestSettings.global.renderShadows, isTrue);
        expect(SnaptestSettings.global.blockText, isFalse);
      });

      test('can modify global settings', () {
        SnaptestSettings.global = const SnaptestSettings(
          renderShadows: false,
        );

        expect(SnaptestSettings.global.renderShadows, isFalse);
      });

      test('reset restores default values', () {
        SnaptestSettings.global = const SnaptestSettings(
          renderShadows: false,
        );

        SnaptestSettings.resetGlobal();

        expect(
          SnaptestSettings.global,
          equals(const SnaptestSettings.rendered()),
        );
      });
    });

    group('setTestViewForDevice', () {
      testWidgets('sets and restores device view', (tester) async {
        final binding = TestWidgetsFlutterBinding.instance;
        final implicitView = binding.platformDispatcher.implicitView!;

        final originalSize = implicitView.physicalSize;
        final originalPixelRatio = implicitView.devicePixelRatio;

        final newDevice = DeviceInfo.genericPhone(
          platform: TargetPlatform.iOS,
          id: 'test',
          name: 'test',
          screenSize:
              (originalSize / originalPixelRatio) + const Offset(100, 100),
          pixelRatio: originalPixelRatio * 2,
        );

        final restore = setTestViewForDevice(
          newDevice,
          Orientation.portrait,
        );

        expect(
          implicitView.physicalSize,
          equals(newDevice.screenSize * newDevice.pixelRatio),
        );
        expect(implicitView.devicePixelRatio, equals(newDevice.pixelRatio));

        restore();

        expect(implicitView.physicalSize, equals(originalSize));
        expect(implicitView.devicePixelRatio, equals(originalPixelRatio));
      });

      testWidgets('handles null device specially', (tester) async {
        final binding = TestWidgetsFlutterBinding.instance;
        final implicitView = binding.platformDispatcher.implicitView!;

        final originalSize = implicitView.physicalSize;
        final originalPixelRatio = implicitView.devicePixelRatio;

        final restore = setTestViewForDevice(
          null,
          Orientation.portrait,
        );

        expect(implicitView.physicalSize, equals(originalSize));
        expect(implicitView.devicePixelRatio, equals(originalPixelRatio));

        restore();
      });
    });

    group('real rendering', () {
      snapTest(
        'enables real rendering for fonts and images',
        devices: {Devices.ios.iPhone16Pro, Devices.android.samsungGalaxyS20},
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text(
                      'Custom Font Text',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 24),
                    ),
                    Icon(Icons.check),
                  ],
                ),
              ),
            ),
          );

          await snap(name: 'real_rendering');
        },
        settings: const SnaptestSettings.rendered(),
      );

      snapTest(
        'captures widget with device frame when enabled',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: Center(child: Text('Device Frame Test'))),
            ),
          );

          final [file] = await snap(name: 'device_frame_test');
          expect(file.existsSync(), isTrue);
        },
        settings: const SnaptestSettings(includeDeviceFrame: true),
      );

      snapTest(
        'captures widget with device frame for real devices',
        devices: {Devices.ios.iPhone16Pro},
        orientations: {Orientation.portrait, Orientation.landscape},
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: ColoredBox(
                  color: Colors.red,
                  child: SafeArea(
                    child: ColoredBox(
                      color: Colors.yellow,
                      child: Center(
                        child: Text(
                          'Real Device Frame Test',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          final ([file], _) = await snap.andGolden(
            name: 'real_device_frame_test',
          );
          expect(file.existsSync(), isTrue);
        },
        settings: const SnaptestSettings(includeDeviceFrame: true),
      );
    });

    group('blocked text', () {
      snapTest('blocks text with different fonts', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      'Roboto',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 32),
                    ),
                    Text(
                      'Serif',
                      style: TextStyle(fontFamily: 'RobotoSerif', fontSize: 32),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final ([file], _) = await snap.andGolden(
          name: 'blocked_text_fonts',
          settings: const SnaptestSettings.rendered(),
        );

        expect(file.existsSync(), isTrue);
      });

      snapTest('blocks rich text with colors and special characters', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Red',
                        style: TextStyle(color: Colors.red),
                      ),
                      TextSpan(
                        text: ' Blue',
                        style: TextStyle(color: Colors.blue),
                      ),
                      TextSpan(
                        text:
                            ' Ñoño café über '
                            'Ελληνικά Кириллица '
                            '© ® ™ € £ ¥ '
                            '¼ ½ ¾ ± × ÷ '
                            'ÆØÅ ñ ß þ ð',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final ([file], _) = await snap.andGolden(
          name: 'blocked_text_rich',
          settings: const SnaptestSettings.rendered(),
        );
        expect(file.existsSync(), isTrue);
      });

      snapTest('blocks text with different font sizes', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Small', style: TextStyle(fontSize: 12)),
                    Text('Large', style: TextStyle(fontSize: 32)),
                  ],
                ),
              ),
            ),
          ),
        );

        final ([file], _) = await snap.andGolden(
          name: 'blocked_text_sizes',
        );
        expect(file.existsSync(), isTrue);
      });
    });

    group('global settings', () {
      testWidgets('works back and forth', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(child: Text('Hello Snapper!')),
                  Center(child: Icon(Icons.check)),
                ],
              ),
            ),
          ),
        );

        final ([defaultFile], _) = await snap.andGolden(
          name: 'global_settings_default',
        );
        expect(defaultFile.existsSync(), isTrue);

        SnaptestSettings.global = const SnaptestSettings(
          blockText: false,
          includeDeviceFrame: true,
        );

        final [file1] = await snap(
          name: 'global_settings_real_text_and_device_frame',
          device: Devices.ios.iPhone16,
        );
        expect(file1.existsSync(), isTrue);

        SnaptestSettings.global = const SnaptestSettings();

        final ([file2], _) = await snap.andGolden(
          name: 'global_settings_default',
          device: Devices.ios.iPhone16,
        );
        expect(file2.existsSync(), isTrue);
      });
    });

    group('snap from', () {
      testWidgets('snaps closest repaint boundary', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(child: Text('Hello Snapper!')),
                  Center(
                    child: RepaintBoundary(
                      child: Padding(
                        key: Key('check-icon'),
                        padding: EdgeInsets.all(16),
                        child: SizedBox.square(
                          dimension: 24,
                          child: ColoredBox(color: Colors.green),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final ([file], _) = await snap.andGolden(
          name: 'snap_from',
          from: find.byKey(const Key('check-icon')),
        );
        expect(file.existsSync(), isTrue);
      });
    });
  });
}
