import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Brands a theme might be given: coil's blue, the common hues, a light
/// yellow and lime that need a dark label, and a deep navy.
const _brands = {
  'blue': Color(0xFF6B97FF),
  'orange': Color(0xFFF97316),
  'green': Color(0xFF16A34A),
  'purple': Color(0xFF8B5CF6),
  'red': Color(0xFFEF4444),
  'teal': Color(0xFF14B8A6),
  'yellow': Color(0xFFFACC15),
  'lime': Color(0xFFA3E635),
  'navy': Color(0xFF1E3A8A),
};

const _states = {
  'rest': <WidgetState>{},
  'hovered': {WidgetState.hovered},
  'pressed': {WidgetState.hovered, WidgetState.pressed},
  'held open': {WidgetState.selected},
};

void main() {
  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      test('a brand button label reads at 4.5 : 1 in every state', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          for (final tier in CoilTier.values) {
            final theme = CoilThemeData(
              colors: CoilColors.fromSeed(
                brightness: brightness,
                brand: brand,
              ),
              tier: tier,
            );
            final style = CoilButtonStyle.fallback(
              theme,
              theme.metrics.resolve(tier, CoilSize.regular),
              CoilButtonVariant.brand,
            );
            for (final MapEntry(key: state, value: states) in _states.entries) {
              final fill = style.fill!.resolve(states)!;
              final label = style.foreground!.resolve(states)!;
              expect(
                CoilColorMix.contrastRatio(label, fill),
                greaterThanOrEqualTo(4.5),
                reason: '$name, $state, ${tier.name}',
              );
            }
          }
        }
      });

      test('a lit brand button keeps its highlights and shades in its own '
          'hue, and a yellow shades toward amber, not olive', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          final fill = CoilColors.fromSeed(
            brightness: brightness,
            brand: brand,
          ).brandFill;
          final fillHue = CoilColorMix.toOklch(fill).h;
          final fillLightness = CoilColorMix.toOklch(fill).l;
          for (final (press, hover) in [(0.0, 0.0), (0.0, 1.0), (1.0, 0.0)]) {
            final plain = const CoilPlasticity(amount: 1).resolve(
              CoilReliefRole.filled,
              brightness,
              hover: hover,
              press: press,
            )!;
            final lit = plain.tintedOver(fill);
            List<Color> layers(CoilRelief r) => [
              r.sheenTop,
              r.sheenBottom,
              r.rimTop,
              r.rimBottom,
              r.edgeTop,
              r.edgeBottom,
            ];
            for (final (i, layer) in layers(lit).indexed) {
              if (layer.a == 0) continue;
              // What shows: each layer painted over the fill.
              final shown = CoilColorMix.toOklch(Color.alphaBlend(layer, fill));
              // Near-white and near-black can't hold a hue.
              if (shown.c < 0.03 || shown.l > 0.97) continue;
              if (shown.l < fillLightness && fillHue > 75 && fillHue < 150) {
                expect(
                  shown.h,
                  inInclusiveRange(55, fillHue + 2),
                  reason: '$name layer $i',
                );
              } else {
                expect(
                  (shown.h - fillHue + 540) % 360 - 180,
                  closeTo(0, 2),
                  reason: '$name layer $i',
                );
              }
            }
            for (final shadow in lit.shadows) {
              final (:l, :c, :h) = CoilColorMix.toOklch(shadow.color);
              expect(c, greaterThan(0), reason: '$name shadow');
              if (fillHue <= 75 || fillHue >= 150) {
                expect(
                  (h - fillHue + 540) % 360 - 180,
                  closeTo(0, 2),
                  reason: '$name shadow',
                );
              }
            }
          }
        }
      });
    });
  }
}
