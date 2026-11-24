// Mock-screen boards for the accent exploration, written to `.snaptest/`.
// Off by default; run with:
//   flutter test test/exploration/screens_test.dart --dart-define=EXPLORE=true
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

import 'harness.dart';
import 'screens.dart';

const _enabled = bool.fromEnvironment('EXPLORE');

const _phoneWidth = 393.0;
const _desktopWidth = 720.0;

enum _Screen { settings, upgrade }

typedef _Variant = ({String caption, bool accent, bool touches});

const _variants = <_Variant>[
  (caption: 'Current', accent: false, touches: false),
  (caption: 'Accent button', accent: true, touches: false),
  (caption: 'Accent + touches', accent: true, touches: true),
];

Widget _screen(_Screen screen, _Variant variant) => switch (screen) {
  _Screen.settings => SettingsScreen(
    accent: variant.accent,
    touches: variant.touches,
  ),
  _Screen.upgrade => UpgradeScreen(
    accent: variant.accent,
    touches: variant.touches,
  ),
};

void main() {
  testWidgets('screens', skip: !_enabled, (tester) async {
    for (final seed in seeds) {
      for (final brightness in Brightness.values) {
        for (final phone in [false, true]) {
          for (final screen in _Screen.values) {
            final tier = phone ? CoilTier.touch : CoilTier.pointer;
            final base = themeFor(seed, brightness, tier: tier);
            final width = phone ? _phoneWidth : _desktopWidth;
            final board = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final variant in _variants)
                  Panel(
                    theme: variant.touches ? withBrandTouches(base) : base,
                    caption: variant.caption,
                    child: SizedBox(
                      width: width,
                      child: _screen(screen, variant),
                    ),
                  ),
              ],
            );
            final finder = await pumpBoard(
              tester,
              board,
              surface: Size(
                (width + 48) * _variants.length * 2,
                (phone ? 1500 : 1600) * 2,
              ),
            );
            await snap(
              name:
                  'screen_${screen.name}_${seed.name}_${brightness.name}_'
                  '${phone ? 'phone' : 'desktop'}',
              from: finder,
            );
          }
        }
      }
    }
  });
}
