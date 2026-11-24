import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chromatic brands from light (yellow) to deep (navy), and graphite, a
/// grey brand.
const _brands = {
  'blue': Color(0xFF6B97FF),
  'orange': Color(0xFFF97316),
  'green': Color(0xFF16A34A),
  'purple': Color(0xFF8B5CF6),
  'yellow': Color(0xFFFACC15),
  'navy': Color(0xFF1E3A8A),
  'graphite': Color(0xFF71717A),
};

/// The surfaces controls sit on: the page, cards, popovers, sheets and
/// dialogs.
const _levels = [1, 2, 3, 4, 5];

double _ratio(Color a, Color b) => CoilColorMix.contrastRatio(a, b);

CoilMetrics _metrics(CoilThemeData theme) =>
    theme.metrics.resolve(CoilTier.pointer, CoilSize.regular);

void main() {
  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      test('a selected tab or segment label reads at 4.5 : 1 on its wash on '
          'every surface a control sits on', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          for (final colors in [
            CoilColors.fromSeed(brightness: brightness, brand: brand),
            CoilColors.fromSeed(
              brightness: brightness,
              brand: brand,
              brandFill: CoilBrandFill.exact,
            ).highContrast(),
          ]) {
            final theme = CoilThemeData(
              colors: colors,
              tier: CoilTier.pointer,
              brandSelection: true,
            );
            final tabs = CoilTabsStyle.fallback(theme, _metrics(theme));
            final toggle = CoilToggleGroupStyle.fallback(
              theme,
              _metrics(theme),
            );
            for (final level in _levels) {
              final surface = colors.surface(level);
              for (final (label, fill) in [
                (tabs.label!.resolve({WidgetState.selected})!, tabs.pill!),
                (
                  toggle.label!.resolve({WidgetState.selected})!,
                  toggle.selection!,
                ),
              ]) {
                expect(
                  _ratio(label, Color.alphaBlend(fill, surface)),
                  greaterThanOrEqualTo(4.5),
                  reason: '$name on surface($level)',
                );
              }
            }
          }
        }
      });

      test('the focus ring, an on switch and a selected radio dot show at '
          '3 : 1 on every page, card or dialog', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          for (final colors in [
            CoilColors.fromSeed(brightness: brightness, brand: brand),
            CoilColors.fromSeed(
              brightness: brightness,
              brand: brand,
              brandFill: CoilBrandFill.exact,
            ).highContrast(),
          ]) {
            final theme = CoilThemeData(
              colors: colors,
              tier: CoilTier.pointer,
              brandSelection: true,
            );
            final metrics = _metrics(theme);
            final marks = {
              'ring': theme.focusRing.colorOf(colors),
              'switch': CoilSwitchStyle.fallback(
                theme,
                metrics,
              ).track!.resolve({WidgetState.selected})!,
              'dot': CoilRadioGroupStyle.fallback(theme, metrics).dot!,
            };
            for (final level in _levels) {
              for (final MapEntry(key: mark, value: color) in marks.entries) {
                expect(
                  _ratio(color, colors.surface(level)),
                  greaterThanOrEqualTo(3),
                  reason: '$name $mark on surface($level)',
                );
              }
            }
          }
        }
      });

      test('a brand that already shows keeps its own color as a mark, and '
          'the brand itself never changes', () {
        // These clear 3 : 1 on every dark surface as given.
        final showing = brightness == Brightness.dark
            ? ['blue', 'orange', 'green', 'yellow']
            : ['green', 'purple', 'navy', 'graphite'];
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          final colors = CoilColors.fromSeed(
            brightness: brightness,
            brand: brand,
          );
          expect(colors.brand, brand, reason: name);
          expect(colors.highContrast().brand, brand, reason: name);
          if (showing.contains(name)) {
            expect(colors.brandMark, brand, reason: name);
          }
        }
      });

      test('a yellow mark darkens toward amber, not olive', () {
        final yellow = _brands['yellow']!;
        final mark = CoilColors.fromSeed(
          brightness: brightness,
          brand: yellow,
        ).brandMark;
        expect(
          CoilColorMix.toOklch(mark).h,
          lessThanOrEqualTo(CoilColorMix.toOklch(yellow).h + 1),
        );
      });

      test('an exact brand stays exactly as given', () {
        for (final MapEntry(key: name, value: brand) in _brands.entries) {
          final colors = CoilColors.fromSeed(
            brightness: brightness,
            brand: brand,
            brandFill: CoilBrandFill.exact,
          );
          expect(colors.brandMark, brand, reason: name);
          expect(colors.brandInk, brand, reason: name);
        }
      });

      test('a grey brand keeps the neutral selection with brand selection on, '
          'and still fills the brand button', () {
        final colors = CoilColors.fromSeed(
          brightness: brightness,
          brand: _brands['graphite'],
        );
        final on = CoilThemeData(
          colors: colors,
          tier: CoilTier.pointer,
          brandSelection: true,
        );
        final off = on.copyWith(brandSelection: false);
        final metrics = _metrics(on);
        expect(
          CoilTabsStyle.fallback(on, metrics),
          CoilTabsStyle.fallback(off, metrics),
        );
        expect(
          CoilToggleGroupStyle.fallback(on, metrics),
          CoilToggleGroupStyle.fallback(off, metrics),
        );
        expect(
          CoilRadioGroupStyle.fallback(on, metrics).dot,
          CoilRadioGroupStyle.fallback(off, metrics).dot,
        );
        expect(
          CoilInputStyle.fallback(on, metrics).cursorColor,
          CoilInputStyle.fallback(off, metrics).cursorColor,
        );
        expect(
          CoilButtonStyle.fallback(
            on,
            metrics,
            CoilButtonVariant.brand,
          ).fill!.resolve({}),
          colors.brandFill,
        );
      });
    });
  }
}
