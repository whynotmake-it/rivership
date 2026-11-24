import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Brands a theme might be given, from light (yellow, lime) to deep (navy).
const _brands = {
  'blue': Color(0xFF6B97FF),
  'orange': Color(0xFFF97316),
  'green': Color(0xFF16A34A),
  'purple': Color(0xFF8B5CF6),
  'teal': Color(0xFF14B8A6),
  'yellow': Color(0xFFFACC15),
  'lime': Color(0xFFA3E635),
  'navy': Color(0xFF1E3A8A),
};

/// Warm and cool tinted neutrals as well as pure grey.
const _neutrals = [(hue: 0.0, chroma: 0.0), (hue: 60.0, chroma: 0.03)];

double _ratio(Color a, Color b) => CoilColorMix.contrastRatio(a, b);

/// No more colorful than a tinted neutral (brands sit at chroma 0.13+).
bool _isNeutral(Color color) => CoilColorMix.toOklch(color).c < 0.045;

void main() {
  for (final brightness in Brightness.values) {
    for (final tier in CoilTier.values) {
      test('${brightness.name} ${tier.name}: a selected tab or toggle segment '
          'reads on its brand wash, and hovering one is never colored', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          for (final neutral in _neutrals) {
            final theme = CoilThemeData(
              colors: CoilColors.fromSeed(
                brightness: brightness,
                brand: brand,
                neutralHue: neutral.hue,
                neutralChroma: neutral.chroma,
              ),
              tier: tier,
            );
            final background = theme.colors.background;
            final metrics = theme.metrics.resolve(tier, CoilSize.regular);
            final reason = '$name on ${neutral.hue}°/${neutral.chroma}';

            final tabs = CoilTabsStyle.fallback(theme, metrics);
            final tabLabel = tabs.label!.resolve({WidgetState.selected})!;
            final tabPill = Color.alphaBlend(tabs.pill!, background);
            expect(
              _ratio(tabLabel, tabPill),
              greaterThanOrEqualTo(4.5),
              reason: 'tab, $reason',
            );
            expect(_isNeutral(tabs.hoverPill!), isTrue, reason: reason);
            expect(
              _isNeutral(tabs.label!.resolve({WidgetState.hovered})!),
              isTrue,
              reason: 'hovered tab label, $reason',
            );

            final toggle = CoilToggleGroupStyle.fallback(theme, metrics);
            final segmentLabel = toggle.label!.resolve({WidgetState.selected})!;
            final segment = Color.alphaBlend(toggle.selection!, background);
            expect(
              _ratio(segmentLabel, segment),
              greaterThanOrEqualTo(4.5),
              reason: 'toggle, $reason',
            );
            expect(_isNeutral(toggle.highlight!), isTrue, reason: reason);
          }
        }
      });
    }

    test('${brightness.name}: a yellow or lime reads amber as text, not '
        'olive', () {
      for (final name in ['yellow', 'lime']) {
        final brand = _brands[name]!;
        final ink = CoilColors.fromSeed(
          brightness: brightness,
          brand: brand,
        ).brandInk;
        final brandHue = CoilColorMix.toOklch(brand).h;
        expect(
          CoilColorMix.toOklch(ink).h,
          lessThanOrEqualTo(brandHue + 1),
          reason: name,
        );
      }
    });
  }
}
