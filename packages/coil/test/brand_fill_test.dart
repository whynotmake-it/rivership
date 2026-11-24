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

double _ratio(Color a, Color b) => CoilColorMix.contrastRatio(a, b);

void main() {
  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      test('the brand stays exactly as given, in high contrast too', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          for (final policy in CoilBrandFill.values) {
            final colors = CoilColors.fromSeed(
              brightness: brightness,
              brand: brand,
              brandFill: policy,
            );
            expect(colors.brand, brand, reason: name);
            expect(colors.highContrast().brand, brand, reason: name);
          }
        }
      });

      test('an accessible brand fill keeps its label readable, hovered '
          'and pressed too, however the brand is set', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          final base = brightness == Brightness.dark
              ? CoilColors.dark
              : CoilColors.light;
          final exact = CoilColors.fromSeed(
            brightness: brightness,
            brand: brand,
            brandFill: CoilBrandFill.exact,
          );
          for (final (how, colors) in [
            (
              'fromSeed',
              CoilColors.fromSeed(brightness: brightness, brand: brand),
            ),
            ('copyWith', base.copyWith(brand: brand)),
            ('high contrast', exact.highContrast()),
          ]) {
            final (:l, :c, :h) = CoilColorMix.toOklch(colors.brandFill);
            const shift = CoilColors.brandStateShift;
            for (final fill in [
              colors.brandFill,
              CoilColorMix.oklch(l + shift, c, h),
              CoilColorMix.oklch(l - shift, c, h),
            ]) {
              expect(
                _ratio(colors.onBrandFill, fill),
                greaterThanOrEqualTo(4.5),
                reason: '$name via $how',
              );
            }
            // The fill stays the brand's hue.
            if (c > 0.05) {
              final brandHue = CoilColorMix.toOklch(brand).h;
              expect(h, closeTo(brandHue, 3), reason: '$name via $how');
            }
          }
        }
      });

      test('an exact brand fill is the brand under its better label', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          final colors = CoilColors.fromSeed(
            brightness: brightness,
            brand: brand,
            brandFill: CoilBrandFill.exact,
          );
          expect(colors.brandFill, brand, reason: name);
          final other = colors.onBrandFill == const Color(0xFFFFFFFF)
              ? CoilColors.light.foreground
              : const Color(0xFFFFFFFF);
          expect(
            CoilColorMix.apcaContrast(colors.onBrandFill, brand).abs(),
            greaterThan(CoilColorMix.apcaContrast(other, brand).abs()),
            reason: name,
          );
        }
      });

      test('a light brand keeps its color under a dark label', () {
        for (final name in ['yellow', 'lime']) {
          final colors = CoilColors.fromSeed(
            brightness: brightness,
            brand: _brands[name],
          );
          expect(colors.brandFill, _brands[name], reason: name);
          expect(
            CoilColorMix.toOklch(colors.onBrandFill).l,
            lessThan(0.3),
            reason: name,
          );
        }
      });
    });
  }

  test('a deep brand fill is lifted off the dark page', () {
    final navy = _brands['navy']!;
    final light = CoilColors.fromSeed(
      brightness: Brightness.light,
      brand: navy,
    );
    final dark = CoilColors.fromSeed(brightness: Brightness.dark, brand: navy);
    expect(light.brandFill, navy);
    expect(
      _ratio(dark.brandFill, dark.background),
      greaterThan(_ratio(navy, dark.background)),
    );
  });
}
