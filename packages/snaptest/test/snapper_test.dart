// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  group('Snapper', () {
    setUp(SnaptestSettings.resetGlobal);

    group('snap function', () {
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

          final files = await snap();
          expect(files, hasLength(1));
          expect(files.first.existsSync(), isTrue);

          await tester.runAsync(() async {
            final image = await files.first.readAsBytes();
            await expectLater(
              image,
              matchesGoldenFile('golden/basic_widget.png'),
            );
          });
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
          );

          expect(files, hasLength(3));
          for (final file in files) {
            expect(file.existsSync(), isTrue);

            await tester.runAsync(() async {
              final image = await file.readAsBytes();
              final name = file.path.split('/').last;
              await expectLater(
                image,
                matchesGoldenFile('golden/$name'),
              );
            });
          }
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
            pathPrefix: 'custom_screenshots/',
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
              devices: [Devices.ios.iPhone16Pro],
            ),
            appendDeviceName: true,
          );

          final filesWithoutDeviceName = await snap(
            name: 'without_device_name',
            settings: SnaptestSettings(
              devices: [Devices.ios.iPhone16Pro],
            ),
            appendDeviceName: false,
          );

          expect(filesWithDeviceName.first.path, contains('iPhone 16 Pro'));
          expect(
            filesWithoutDeviceName.first.path,
            isNot(contains('iPhone 16 Pro')),
          );
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

        final restore = setTestViewToFakeDevice(newDevice);

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

        final restore = setTestViewToFakeDevice(const WidgetTesterDevice());

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
        settings: SnaptestSettings.full([
          const WidgetTesterDevice(),
          Devices.ios.iPhone16Pro,
          Devices.android.samsungGalaxyS20,
        ]),
      );
    });
  });
}
