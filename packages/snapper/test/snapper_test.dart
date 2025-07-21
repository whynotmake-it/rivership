// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapper/snapper.dart';

void main() {
  group('Snapper', () {
    setUp(SnapSettings.reset);

    group('snap function', () {
      screenshotTest(
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

          final files = await snap(name: 'basic_widget');
          expect(files, hasLength(1));
          expect(files.first.existsSync(), isTrue);
        },
      );

      screenshotTest(
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
            devices: [
              const WidgetTesterDevice(),
              Devices.ios.iPhone16Pro,
              Devices.android.samsungGalaxyS20,
            ],
          );

          expect(files, hasLength(3));
          for (final file in files) {
            expect(file.existsSync(), isTrue);
          }
        },
      );

      screenshotTest(
        'captures specific widget using finder',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                appBar: AppBar(title: const Text('App Bar')),
                body: const Center(
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
          );

          final files = await snap(
            name: 'specific_widget',
            from: find.byKey(const Key('test-card')),
          );

          expect(files, hasLength(1));
          expect(files.first.existsSync(), isTrue);
        },
      );

      screenshotTest(
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

      screenshotTest(
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
            devices: [Devices.ios.iPhone16Pro],
            appendDeviceName: true,
          );

          final filesWithoutDeviceName = await snap(
            name: 'without_device_name',
            devices: [Devices.ios.iPhone16Pro],
            appendDeviceName: false,
          );

          expect(filesWithDeviceName.first.path, contains('iPhone16Pro'));
          expect(
            filesWithoutDeviceName.first.path,
            isNot(contains('iPhone16Pro')),
          );
        },
      );
    });

    group('SnapSettings', () {
      test('has correct default values', () {
        SnapSettings.reset();
        expect(SnapSettings.renderShadows, isTrue);
        expect(SnapSettings.devices, hasLength(1));
        expect(SnapSettings.devices.first, isA<WidgetTesterDevice>());
      });

      test('can modify global settings', () {
        SnapSettings.renderShadows = false;
        SnapSettings.devices = [Devices.ios.iPhone16Pro];

        expect(SnapSettings.renderShadows, isFalse);
        expect(SnapSettings.devices, hasLength(1));
        expect(SnapSettings.devices.first, equals(Devices.ios.iPhone16Pro));
      });

      test('reset restores default values', () {
        SnapSettings.renderShadows = false;
        SnapSettings.devices = [Devices.ios.iPhone16Pro];

        SnapSettings.reset();

        expect(SnapSettings.renderShadows, isTrue);
        expect(SnapSettings.devices, hasLength(1));
        expect(SnapSettings.devices.first, isA<WidgetTesterDevice>());
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
      screenshotTest(
        'enables real rendering for fonts and images',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const Text(
                      'Custom Font Text',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 24,
                      ),
                    ),
                    Image.asset(
                      'assets/test_image.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey,
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );

          await snap(name: 'real_rendering');
        },
        withRealRendering: true,
      );
    });
  });
}
