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
import 'package:coil_glass/coil_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// The renderer's own tests pin this: flutter_tester renders its seeded
// backdrop pass wrongly now and then (glass missing for a few frames).
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
      for (final glass in [true, false]) {
        final look = glass ? 'glass' : 'coil';
        testWidgets(
          '${form}_${look}_$mode',
          variant: TestDevicesVariant({device}),
          (tester) async {
            final menu = CoilPopupController();
            addTearDown(menu.dispose);
            await tester.pumpWidget(
              themed(
                brightness: brightness,
                glass: glass,
                child: AlbumScreen(menu: menu, desktop: !phone),
              ),
            );
            await _settle(tester);
            await snap(
              name: '${form}_${mode}_$look',
              settings: _settings(frame: phone),
            );
            await tester.tap(find.byKey(const ValueKey('more')));
            await _settle(tester);
            await snap(
              name: '${form}_${mode}_${look}_menu',
              settings: _settings(frame: phone),
            );
          },
        );
      }
    }

    for (final glassMode in [CoilGlassMode.frosted, CoilGlassMode.solid]) {
      testWidgets(
        'fallback_${glassMode.name}_$mode',
        variant: TestDevicesVariant({_phone}),
        (tester) async {
          final menu = CoilPopupController();
          addTearDown(menu.dispose);
          await tester.pumpWidget(
            themed(
              brightness: brightness,
              mode: glassMode,
              child: AlbumScreen(menu: menu, desktop: false),
            ),
          );
          await _settle(tester);
          await tester.tap(find.byKey(const ValueKey('more')));
          await _settle(tester);
          await snap(
            name: 'phone_${mode}_fallback_${glassMode.name}_menu',
            settings: _settings(frame: true),
          );
        },
      );
    }

    // A menu opening from a glass button, as frames (encode with ffmpeg):
    // snaptest's video recorder is too slow with real glass in
    // flutter_tester.
    testWidgets(
      'menu_frames_$mode',
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
            // Real time for the renderer's asynchronous GPU work, as a
            // device would have between frames.
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            await snap(
              name: 'menu_${mode}_${(frame++).toString().padLeft(3, '0')}',
              settings: _settings(frame: false, dir: '$_out/frames'),
            );
          }
        }

        await run(4);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('more'))),
        );
        await run(4);
        await gesture.up();
        await run(22);
        menu.close();
        await run(14);
      },
    );
  }
}
