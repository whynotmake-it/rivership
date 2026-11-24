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

/// The colors a selected state shows, as the components resolve them.
({
  Color tabLabel,
  Color tabPill,
  Color segmentLabel,
  Color segment,
  Color dot,
  Color cursor,
  Color tabHover,
  Color segmentHover,
  Color rawTabPill,
  Color rawSegment,
})
_selection(CoilThemeData theme) {
  final metrics = theme.metrics.resolve(theme.tier!, CoilSize.regular);
  final background = theme.colors.background;
  final tabs = CoilTabsStyle.fallback(theme, metrics);
  final toggle = CoilToggleGroupStyle.fallback(theme, metrics);
  return (
    tabLabel: tabs.label!.resolve({WidgetState.selected})!,
    tabPill: Color.alphaBlend(tabs.pill!, background),
    segmentLabel: toggle.label!.resolve({WidgetState.selected})!,
    segment: Color.alphaBlend(toggle.selection!, background),
    dot: CoilRadioGroupStyle.fallback(theme, metrics).dot!,
    cursor: CoilInputStyle.fallback(theme, metrics).cursorColor!,
    tabHover: tabs.hoverPill!,
    segmentHover: toggle.highlight!,
    rawTabPill: tabs.pill!,
    rawSegment: toggle.selection!,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final tier in CoilTier.values) {
      test('${brightness.name} ${tier.name}: selections stay monochrome '
          'unless brand selection is on, and then read on their brand wash '
          'while hover stays neutral', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          for (final neutral in _neutrals) {
            for (final policy in CoilBrandFill.values) {
              final colors = CoilColors.fromSeed(
                brightness: brightness,
                brand: brand,
                brandFill: policy,
                neutralHue: neutral.hue,
                neutralChroma: neutral.chroma,
              );
              final reason =
                  '$name, ${policy.name}, on ${neutral.hue}°/${neutral.chroma}';
              final theme = CoilThemeData(colors: colors, tier: tier);

              // Off: today's neutral tokens, exactly.
              final off = _selection(theme);
              expect(off.dot, colors.foreground, reason: reason);
              expect(off.cursor, colors.foreground, reason: reason);
              expect(off.rawTabPill, colors.active, reason: reason);
              expect(off.tabLabel, colors.foreground, reason: reason);
              expect(off.rawSegment, colors.active, reason: reason);
              expect(off.segmentLabel, colors.foreground, reason: reason);

              final on = _selection(theme.copyWith(brandSelection: true));
              expect(on.dot, colors.brandMark, reason: reason);
              expect(on.cursor, colors.brandMark, reason: reason);
              expect(_isNeutral(on.tabHover), isTrue, reason: reason);
              expect(_isNeutral(on.segmentHover), isTrue, reason: reason);
              if (policy == CoilBrandFill.accessible) {
                for (final (label, ground) in [
                  (on.tabLabel, on.tabPill),
                  (on.segmentLabel, on.segment),
                  (colors.brandInk, colors.background),
                ]) {
                  expect(
                    _ratio(label, ground),
                    greaterThanOrEqualTo(4.5),
                    reason: reason,
                  );
                }
              }
            }
          }
        }
      });
    }

    test('${brightness.name}: high contrast keeps brand text readable even '
        'with an exact brand', () {
      for (final MapEntry(key: name, value: brand) in _brands.entries) {
        final colors = CoilColors.fromSeed(
          brightness: brightness,
          brand: brand,
          brandFill: CoilBrandFill.exact,
        ).highContrast();
        expect(colors.brand, brand, reason: name);
        final wash = Color.alphaBlend(colors.brandWash, colors.background);
        for (final ground in [wash, colors.background]) {
          expect(
            _ratio(colors.brandInk, ground),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        }
      }
    });

    test('${brightness.name}: an exact brand stays exact as text and wash '
        'when the brand changes', () {
      final seeded = CoilColors.fromSeed(
        brightness: brightness,
        brandFill: CoilBrandFill.exact,
      );
      for (final MapEntry(key: name, value: brand) in _brands.entries) {
        final colors = seeded.copyWith(brand: brand);
        expect(colors.brandInk, brand, reason: name);
        expect(colors.brandWash.withValues(alpha: 1), brand, reason: name);
      }
    });

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

  testWidgets('a nested theme turns brand selection on for its subtree only', (
    tester,
  ) async {
    late CoilThemeData outside;
    late CoilThemeData inside;
    await tester.pumpWidget(
      CoilTheme(
        data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
        child: Column(
          children: [
            Builder(
              builder: (context) {
                outside = CoilTheme.of(context);
                return const SizedBox();
              },
            ),
            CoilTheme.override(
              transform: (t) => t.copyWith(brandSelection: true),
              child: Builder(
                builder: (context) {
                  inside = CoilTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
    final colors = CoilThemeData.light.colors;
    final out = _selection(outside);
    final ins = _selection(inside);
    expect(out.dot, colors.foreground);
    expect(out.rawTabPill, colors.active);
    expect(out.rawSegment, colors.active);
    expect(ins.dot, colors.brandMark);
    expect(ins.rawTabPill, colors.brandWash);
    expect(ins.tabLabel, colors.brandInk);
    expect(ins.rawSegment, colors.brandWash);
  });
}
