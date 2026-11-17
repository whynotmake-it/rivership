// Renders the exploration's screenshots and recordings.
//
// Real glass needs Impeller and Flutter GPU in the test engine:
//
//   flutter test --enable-impeller --enable-flutter-gpu \
//     --dart-define=COIL_GLASS_VISUALS=<output dir> test/visuals_test.dart
//
// Without the flags the renderer falls back to FakeGlass (no refraction).
@Tags(['visuals'])
library;

import 'dart:ui' as ui;

import 'package:coil/foundation.dart';
import 'package:coil_glass/coil_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

import 'src/scenes.dart';

const _out = String.fromEnvironment('COIL_GLASS_VISUALS');

final _phone = Devices.ios.iPhone16Pro;

/// A 1280×800 window. Without a device, snaptest renders at its default
/// 800×600 test view.
final _desktop = DeviceInfo.genericDesktopMonitor(
  platform: TargetPlatform.macOS,
  name: 'Desktop',
  id: 'desktop',
  screenSize: const Size(1280, 800),
  windowPosition: const Rect.fromLTWH(0, 0, 1280, 800),
);

SnaptestSettings _settings({required bool frame}) => SnaptestSettings(
  blockText: false,
  renderShadows: true,
  includeDeviceFrame: frame,
  pathPrefix: _out,
);

Future<void> _settle(WidgetTester tester) async {
  // Glass resources load asynchronously on first use.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

String _mode(Brightness b) => b == Brightness.dark ? 'dark' : 'light';

void main() {
  if (_out.isEmpty) {
    test(
      'visuals',
      () {},
      skip: 'pass --dart-define=COIL_GLASS_VISUALS=<output directory>',
    );
    return;
  }
  setUpAll(() {
    // ignore: avoid_print
    print('real glass: ${ui.ImageFilter.isShaderFilterSupported}');
  });

  for (final brightness in Brightness.values) {
    final mode = _mode(brightness);
    for (final variant in Variant.values) {
      final name = '${variant.index + 1}_${variant.name}';

      testWidgets(
        '${name}_phone_$mode',
        variant: TestDevicesVariant({_phone}),
        (tester) async {
          await tester.pumpWidget(
            themed(
              brightness: brightness,
              tier: CoilTier.touch,
              child: PhoneScene(variant, menu: variant == Variant.chrome),
            ),
          );
          await _settle(tester);
          await snap(
            name: '${name}_phone_$mode',
            settings: _settings(frame: true),
          );
          if (variant == Variant.controls || variant == Variant.transient) {
            // Mid-travel: the lens lifts off the platter.
            await tester.tap(find.text('Map'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 110));
            await snap(
              name: '${name}_phone_${mode}_moving',
              settings: _settings(frame: true),
            );
          }
        },
      );

      testWidgets(
        '${name}_desktop_$mode',
        variant: TestDevicesVariant({_desktop}),
        (tester) async {
          await tester.pumpWidget(
            themed(
              brightness: brightness,
              tier: CoilTier.pointer,
              child: DesktopScene(variant, menu: variant == Variant.chrome),
            ),
          );
          await _settle(tester);
          await snap(
            name: '${name}_desktop_$mode',
            settings: _settings(frame: false),
          );
          if (variant == Variant.controls || variant == Variant.transient) {
            await tester.tap(find.text('All'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 110));
            await snap(
              name: '${name}_desktop_${mode}_moving',
              settings: _settings(frame: false),
            );
          }
        },
      );
    }

    // Fallbacks for the recommended variant.
    for (final glassMode in [CoilGlassMode.frosted, CoilGlassMode.solid]) {
      testWidgets(
        'fallback_${glassMode.name}_phone_$mode',
        variant: TestDevicesVariant({_phone}),
        (tester) async {
          await tester.pumpWidget(
            themed(
              brightness: brightness,
              tier: CoilTier.touch,
              mode: glassMode,
              child: const PhoneScene(Variant.controls, menu: true),
            ),
          );
          await _settle(tester);
          await snap(
            name: '5_fallback_${glassMode.name}_phone_$mode',
            settings: _settings(frame: true),
          );
        },
      );
    }
  }

  // The morph as a frame sequence (encode with ffmpeg): snaptest's video
  // recorder is too slow with real glass in flutter_tester.
  for (final brightness in Brightness.values) {
    final mode = _mode(brightness);
    testWidgets(
      'morph_frames_$mode',
      variant: TestDevicesVariant({_phone}),
      (tester) async {
        await tester.pumpWidget(
          themed(
            brightness: brightness,
            tier: CoilTier.touch,
            child: const PhoneScene(Variant.controls),
          ),
        );
        await _settle(tester);
        var frame = 0;
        Future<void> capture() => snap(
          name: 'morph_${mode}_${(frame++).toString().padLeft(3, '0')}',
          settings: const SnaptestSettings(
            blockText: false,
            renderShadows: true,
            pathPrefix: '$_out/frames',
          ),
        );
        Future<void> run(int frames) async {
          for (var i = 0; i < frames; i++) {
            await tester.pump(const Duration(milliseconds: 33));
            await capture();
          }
        }

        await run(4);
        for (final label in ['Map', 'For You']) {
          await tester.tap(find.text(label));
          await run(18);
        }
        // Scrub across the top segmented control and let go.
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Years')),
        );
        await run(4);
        for (var i = 0; i < 16; i++) {
          await gesture.moveBy(const Offset(14, 0));
          await run(1);
        }
        await gesture.up();
        await run(20);
      },
    );
  }
}
