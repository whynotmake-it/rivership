import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every color token, by name.
Map<String, Color> _tokens(CoilColors c) => {
  for (var i = 1; i <= 8; i++) 'surface($i)': c.surface(i),
  'foreground': c.foreground,
  'muted': c.muted,
  'mutedForeground': c.mutedForeground,
  'accent': c.accent,
  'selected': c.selected,
  'input': c.input,
  'border': c.border,
  'destructive': c.destructive,
  'destructiveLight': c.destructiveLight,
  'info': c.info,
  'success': c.success,
  'warning': c.warning,
  'brand': c.brand,
  'focusRing': c.focusRing,
  'overlay': c.overlay,
  'hover': c.hover,
  'active': c.active,
  'tint': c.tint,
  'tintHover': c.tintHover,
  'red': c.red,
  'redLabel': c.redLabel,
  'shadowColor': c.shadowColor,
};

const _statusTokens = [
  'destructive',
  'info',
  'success',
  'warning',
  'red',
  'redLabel',
];

double _ratio(Color a, Color b) => CoilColorMix.contrastRatio(a, b);

void main() {
  const defaults = {
    Brightness.light: CoilColors.light,
    Brightness.dark: CoilColors.dark,
  };
  // Warm, green, cool and magenta tints, from a hint to strongly tinted.
  const seeds = [
    (hue: 60.0, chroma: 0.01),
    (hue: 60.0, chroma: 0.04),
    (hue: 145.0, chroma: 0.03),
    (hue: 250.0, chroma: 0.02),
    (hue: 250.0, chroma: 0.06),
    (hue: 330.0, chroma: 0.05),
  ];

  for (final MapEntry(key: brightness, value: expected) in defaults.entries) {
    group(brightness.name, () {
      test('the default seeds reproduce the default palette', () {
        final generated = CoilColors.fromSeed(brightness: brightness);
        final want = _tokens(expected);
        for (final MapEntry(key: name, value: color) in _tokens(
          generated,
        ).entries) {
          final target = want[name]!;
          for (final (got, exp) in [
            (color.r, target.r),
            (color.g, target.g),
            (color.b, target.b),
            (color.a, target.a),
          ]) {
            expect((got - exp).abs(), lessThanOrEqualTo(1 / 255), reason: name);
          }
        }
        expect(generated.borderAlpha, expected.borderAlpha);
        expect(generated.brightness, brightness);
      });

      for (final seed in seeds) {
        group('neutral ${seed.hue}° at ${seed.chroma}', () {
          final colors = CoilColors.fromSeed(
            brightness: brightness,
            neutralHue: seed.hue,
            neutralChroma: seed.chroma,
          );

          test('is tinted', () {
            final (l: _, :c, :h) = CoilColorMix.toOklch(colors.muted);
            expect(c, greaterThan(0.005));
            expect(h, closeTo(seed.hue, 2));
          });

          test('every text and status color keeps its contrast floor', () {
            for (var level = 1; level <= 8; level++) {
              expect(
                _ratio(colors.foreground, colors.surface(level)),
                greaterThanOrEqualTo(4.5),
                reason: 'foreground on surface($level)',
              );
            }
            for (var level = 1; level <= 3; level++) {
              expect(
                _ratio(colors.mutedForeground, colors.surface(level)),
                greaterThanOrEqualTo(4.5),
                reason: 'mutedForeground on surface($level)',
              );
            }
            final generated = _tokens(colors);
            final reference = _tokens(expected);
            for (final name in _statusTokens) {
              expect(
                _ratio(generated[name]!, colors.background),
                greaterThanOrEqualTo(
                  _ratio(reference[name]!, expected.background),
                ),
                reason: name,
              );
              expect(
                CoilColorMix.toOklch(generated[name]!).h,
                closeTo(CoilColorMix.toOklch(reference[name]!).h, 2),
                reason: '$name keeps its hue',
              );
            }
          });

          test('keeps the surfaces in the same lightness order', () {
            double lightness(int level) =>
                CoilColorMix.toOklch(colors.surface(level)).l;
            for (var level = 1; level < 8; level++) {
              expect(
                lightness(level + 1),
                greaterThanOrEqualTo(lightness(level) - 1e-9),
                reason: 'surface(${level + 1}) vs surface($level)',
              );
            }
          });

          test('high contrast still layers on top', () {
            final high = colors.highContrast();
            expect(high.borderAlpha, 0.4);
            expect(
              _ratio(high.focusRing, high.background),
              greaterThanOrEqualTo(3),
            );
            expect(high.surfaces, colors.surfaces);
          });
        });
      }
    });
  }

  test('a brand seed sets the brand and the focus ring', () {
    const teal = Color(0xFF14B8A6);
    final colors = CoilColors.fromSeed(
      brightness: Brightness.light,
      brand: teal,
    );
    expect(colors.brand, teal);
    expect(colors.focusRing, teal);
  });

  test('oklch maps out-of-gamut colors at the same lightness and hue', () {
    final color = CoilColorMix.oklch(0.97, 0.3, 30);
    final (:l, :c, :h) = CoilColorMix.toOklch(color);
    expect(l, closeTo(0.97, 0.002));
    expect(c, lessThan(0.3));
    expect(h, closeTo(30, 2));
  });
}
