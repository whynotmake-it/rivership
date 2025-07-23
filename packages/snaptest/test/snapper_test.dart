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
          settings: SnaptestSettings.rendered(devices: [Devices.ios.iPhone16]),
        );
      });

      snapTest(
        'captures basic widget snapshot',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Hello Snapper!'),
                ),
              ),
            ),
          );

          final files = await snap(matchToGolden: true);
          expect(files, hasLength(1));
          expect(files.first.existsSync(), isTrue);
        },
      );

      snapTest(
        'captures widget with multiple devices',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Multi Device Test'),
                ),
              ),
            ),
          );

          final files = await snap(
            name: 'multi_device',
            settings: SnaptestSettings(
              devices: [
                const WidgetTesterDevice(),
                Devices.ios.iPhone16Pro,
                Devices.android.samsungGalaxyS20,
              ],
            ),
            matchToGolden: true,
          );

          expect(files, hasLength(3));
        },
      );

      snapTest(
        'captures specific widget using finder',
        (tester) async {
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

          final files = await snap(
            name: 'specific_widget',
            from: find.byKey(const Key('test-card')),
          );

          expect(files, hasLength(1));
          expect(files.first.existsSync(), isTrue);
        },
      );

      snapTest(
        'handles custom path prefix',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Custom Path Test'),
                ),
              ),
            ),
          );

          final files = await snap(
            name: 'custom_path',
            settings: const SnaptestSettings(pathPrefix: 'custom_screenshots/'),
          );

          expect(files, hasLength(1));
          expect(files.first.path, contains('custom_screenshots'));
          expect(files.first.existsSync(), isTrue);
        },
      );

      snapTest(
        'respects appendDeviceName setting',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Device Name Test'),
                ),
              ),
            ),
          );

          final filesWithDeviceName = await snap(
            name: 'with_device_name',
            settings: SnaptestSettings(
              devices: [
                Devices.ios.iPhone16Pro,
                Devices.android.samsungGalaxyS20,
              ],
            ),
          );

          final filesWithoutDeviceName = await snap(
            name: 'without_device_name',
            settings: SnaptestSettings(
              devices: [Devices.ios.iPhone16Pro],
            ),
          );

          expect(filesWithDeviceName.first.path, contains('iPhone 16 Pro'));
          expect(
            filesWithoutDeviceName.first.path,
            isNot(contains('iPhone 16 Pro')),
          );
        },
      );

      snapTest(
        'orientation is not appended for widget tester only',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: Center(child: Text('Hello Snapper!'))),
            ),
          );
          final files = await snap(
            settings: const SnaptestSettings(
              devices: [WidgetTesterDevice()],
              orientations: {
                Orientation.portrait,
                Orientation.landscape,
              },
            ),
          );

          expect(files, hasLength(1));
          expect(files.first.path, isNot(contains('portrait')));
          expect(files.first.path, isNot(contains('landscape')));
        },
      );
    });

    group('SnaptestSettings', () {
      test('has correct default values', () {
        SnaptestSettings.resetGlobal();
        expect(SnaptestSettings.global.renderShadows, isFalse);
        expect(SnaptestSettings.global.renderImages, isFalse);
        expect(SnaptestSettings.global.blockText, isTrue);
        expect(SnaptestSettings.global.devices, hasLength(1));
        expect(
          SnaptestSettings.global.devices.first,
          isA<WidgetTesterDevice>(),
        );
      });

      test('can modify global settings', () {
        SnaptestSettings.global = SnaptestSettings(
          renderShadows: false,
          devices: [Devices.ios.iPhone16Pro],
        );

        expect(SnaptestSettings.global.renderShadows, isFalse);
        expect(SnaptestSettings.global.devices, hasLength(1));
        expect(
          SnaptestSettings.global.devices.first,
          equals(Devices.ios.iPhone16Pro),
        );
      });

      test('reset restores default values', () {
        SnaptestSettings.global = SnaptestSettings(
          renderShadows: false,
          devices: [Devices.ios.iPhone16Pro],
        );

        SnaptestSettings.resetGlobal();

        expect(SnaptestSettings.global, equals(const SnaptestSettings()));
      });
    });

    group('setTestViewToFakeDevice', () {
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

        final restore = setTestViewToFakeDevice(
          newDevice,
          Orientation.portrait,
        );

        expect(
          implicitView.physicalSize,
          equals(newDevice.screenSize * newDevice.pixelRatio),
        );
        expect(
          implicitView.devicePixelRatio,
          equals(newDevice.pixelRatio),
        );

        restore();

        expect(implicitView.physicalSize, equals(originalSize));
        expect(implicitView.devicePixelRatio, equals(originalPixelRatio));
      });

      testWidgets('handles WidgetTesterDevice specially', (tester) async {
        final binding = TestWidgetsFlutterBinding.instance;
        final implicitView = binding.platformDispatcher.implicitView!;

        final originalSize = implicitView.physicalSize;
        final originalPixelRatio = implicitView.devicePixelRatio;

        final restore = setTestViewToFakeDevice(
          const WidgetTesterDevice(),
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
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text(
                      'Custom Font Text',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 24,
                      ),
                    ),
                    Icon(Icons.check),
                  ],
                ),
              ),
            ),
          );

          await snap(name: 'real_rendering');
        },
        settings: SnaptestSettings.rendered(
          devices: [
            const WidgetTesterDevice(),
            Devices.ios.iPhone16Pro,
            Devices.android.samsungGalaxyS20,
          ],
        ),
      );

      snapTest(
        'captures widget with device frame when enabled',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Device Frame Test'),
                ),
              ),
            ),
          );

          final files = await snap(name: 'device_frame_test');
          expect(files, hasLength(1));
          expect(files.first.existsSync(), isTrue);
        },
        settings: const SnaptestSettings(
          includeDeviceFrame: true,
          devices: [
            WidgetTesterDevice(),
          ],
        ),
      );

      snapTest(
        'captures widget with device frame for real devices',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: ColoredBox(
                  color: Colors.red,
                  child: SafeArea(
                    child: ColoredBox(
                      color: Colors.yellow,
                      child: Center(child: Text('Real Device Frame Test')),
                    ),
                  ),
                ),
              ),
            ),
          );

          final files = await snap(
            name: 'real_device_frame_test',
            matchToGolden: true,
          );
          expect(files, hasLength(2));
          expect(files.first.existsSync(), isTrue);
        },
        settings: SnaptestSettings(
          includeDeviceFrame: true,
          devices: [
            Devices.ios.iPhone16Pro,
          ],
          orientations: {
            Orientation.portrait,
            Orientation.landscape,
          },
        ),
      );
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

        final defaultFiles = await snap(
          name: 'global_settings_0',
          matchToGolden: true,
        );
        expect(defaultFiles, hasLength(1));

        SnaptestSettings.global = SnaptestSettings(
          blockText: false,
          includeDeviceFrame: true,
          devices: [
            Devices.ios.iPhone16,
          ],
        );

        final files = await snap(name: 'global_settings_1');
        expect(files, hasLength(1));

        SnaptestSettings.global = SnaptestSettings(
          devices: [
            Devices.ios.iPhone16,
          ],
        );

        final files2 = await snap(
          name: 'global_settings_2',
          matchToGolden: true,
        );
        expect(files2, hasLength(1));
      });
    });
  });
}
