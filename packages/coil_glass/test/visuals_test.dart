// Renders the exploration's screenshots and frame sequences.
//
// Real glass needs Impeller and Flutter GPU in the test engine:
//
//   flutter test --enable-impeller --enable-flutter-gpu \
//     --dart-define=COIL_GLASS_VISUALS=<output dir> test/visuals_test.dart
//
// Without the flags the renderer falls back to FakeGlass (no refraction).
@Tags(['visuals'])
library;

import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// The renderer's own tests pin this: flutter_tester renders its seeded
// backdrop pass wrongly now and then.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'package:liquid_glass_renderer/src/internal/backdrop_seed.dart';
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

SnaptestSettings _settings({required bool frame, String dir = _out}) =>
    SnaptestSettings(
      blockText: false,
      renderShadows: true,
      includeDeviceFrame: frame,
      pathPrefix: dir,
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
  setUp(() {
    final override = SeededBackdropPassLayer.debugModeOverride;
    SeededBackdropPassLayer.debugModeOverride = BackdropSeed.none;
    addTearDown(() => SeededBackdropPassLayer.debugModeOverride = override);
  });

  for (final brightness in Brightness.values) {
    final mode = _mode(brightness);
    for (final (device, phone) in [(_phone, true), (_desktop, false)]) {
      final form = phone ? 'phone' : 'desktop';
      testWidgets(
        '${form}_rest_$mode',
        variant: TestDevicesVariant({device}),
        (tester) async {
          final menu = CoilPopupController();
          addTearDown(menu.dispose);
          await tester.pumpWidget(
            themed(
              brightness: brightness,
              child: AlbumScreen(menu: menu, desktop: !phone),
            ),
          );
          await _settle(tester);
          await snap(
            name: '${form}_${mode}_rest',
            settings: _settings(frame: phone),
          );
        },
      );
    }

    // Press Share, hold, drag it toward Favorite, hold, release. As frames
    // (encode with ffmpeg): snaptest's video recorder is too slow with real
    // glass in flutter_tester.
    testWidgets(
      'drag_frames_$mode',
      variant: TestDevicesVariant({_phone}),
      (tester) async {
        final menu = CoilPopupController();
        addTearDown(menu.dispose);
        await tester.pumpWidget(
          themed(
            brightness: brightness,
            child: AlbumScreen(menu: menu, desktop: false),
          ),
        );
        await _settle(tester);
        var frame = 0;
        Future<void> run(int frames) async {
          for (var i = 0; i < frames; i++) {
            await tester.pump(const Duration(milliseconds: 33));
            await snap(
              name: 'drag_${mode}_${(frame++).toString().padLeft(3, '0')}',
              settings: _settings(frame: false, dir: '$_out/frames'),
            );
          }
        }

        await run(3);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('Share'))),
        );
        await run(8); // pressed, not moving: swells and glows, no blend
        // A short pull, as a thumb does: the finger stays over the button
        // (and its glow on it) while the stretch reaches the neighbor.
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(4, 0));
          await run(1);
        }
        await run(8); // held near Favorite: blended
        await gesture.up();
        await run(24); // springs apart, blend back to 0
      },
    );
  }
}
