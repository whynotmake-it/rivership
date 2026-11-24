import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(CoilThemeData theme) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: theme,
    child: Center(
      child: CoilButton(onPressed: () {}, child: const Text('Save')),
    ),
  ),
);

void main() {
  testWidgets('an app can change control sizes at runtime', (tester) async {
    final theme = CoilThemeData.light.copyWith(tier: CoilTier.pointer);
    await tester.pumpWidget(_app(theme));
    expect(tester.getSize(find.byType(CoilButton)).height, 36);

    await tester.pumpWidget(
      _app(
        theme.copyWith(
          metrics: const CoilMetricsTable().copyWith(
            pointer: CoilMetrics.pointer.copyWith(controlHeight: 40),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(CoilButton)).height, 40);
  });

  testWidgets('an app can define its own corner family', (tester) async {
    const soft = CoilShape(
      pointer: CoilRadii(item: 6, container: 10, focusRing: 8),
      touch: CoilRadii(item: 12, container: 18, focusRing: 14),
    );
    late CoilRadii radii;
    await tester.pumpWidget(
      CoilTheme(
        data: CoilThemeData.light.copyWith(
          shape: soft,
          tier: CoilTier.touch,
        ),
        child: Builder(
          builder: (context) {
            radii = CoilTheme.radiiOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(radii.item, 12);
  });

  testWidgets('an app can set its own font, or the platform font', (
    tester,
  ) async {
    late TextStyle style;
    Future<void> pump(CoilTypography typography) => tester.pumpWidget(
      CoilTheme(
        data: CoilThemeData.light.copyWith(typography: typography),
        child: Builder(
          builder: (context) {
            style = DefaultTextStyle.of(context).style;
            return const SizedBox();
          },
        ),
      ),
    );

    await pump(CoilTypography.from(const TextStyle(fontFamily: 'Brand')));
    expect(style.fontFamily, 'Brand');

    await pump(CoilTypography.platform);
    expect(style.fontFamily, isNull);
  });

  testWidgets('a plain Icon follows the theme in light and dark', (
    tester,
  ) async {
    late Color? color;
    Future<void> pump(CoilThemeData theme) => tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => CoilTheme(
          data: theme,
          child: Builder(
            builder: (context) {
              color = IconTheme.of(context).color;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await pump(CoilThemeData.light);
    expect(color, CoilThemeData.light.colors.foreground);

    await pump(CoilThemeData.dark);
    expect(color, CoilThemeData.dark.colors.foreground);
  });

  group('typography', () {
    double? opsz(TextStyle style) =>
        style.fontVariations?.where((axis) => axis.axis == 'opsz').single.value;

    test('roles of a custom font set opsz to their size', () {
      final text = CoilTypography.from(
        const TextStyle(fontFamily: 'Brand'),
      ).pointer;
      expect(opsz(text.body), 13);
      expect(opsz(text.display), 28);
      expect(text.display.letterSpacing, 0);
    });

    test('Allo rises in opsz half as fast above 14, with letter spacing', () {
      final text = CoilTypography.allo().pointer;
      expect(opsz(text.micro), 11);
      expect(opsz(text.title), 15);
      expect(opsz(text.display), 21);
      expect(text.micro.letterSpacing, 0);
      expect(text.body.letterSpacing, closeTo(13 * 0.005, 1e-9));
      expect(text.title.letterSpacing, closeTo(16 * 0.006, 1e-9));
      expect(text.display.letterSpacing, closeTo(28 * 0.002, 1e-9));
    });

    test('a pinned optical size holds at every size', () {
      final text = CoilTypography.allo(opticalSize: 14).pointer;
      expect(opsz(text.micro), 14);
      expect(opsz(text.display), 14);
    });
  });

  test('focus rings keep following the brand after a theme lerp', () {
    final theme = CoilThemeData.lerp(
      CoilThemeData.light,
      CoilThemeData.dark,
      1,
    );
    const violet = Color(0xFF8B5CF6);
    expect(
      theme.focusRing.colorOf(theme.colors.copyWith(brand: violet)),
      violet,
    );
  });

  test('the scrim is a color token: black 20 % in light, 30 % in dark', () {
    expect(
      CoilColors.light.scrim,
      const Color.from(alpha: 0.2, red: 0, green: 0, blue: 0),
    );
    expect(
      CoilColors.dark.scrim,
      const Color.from(alpha: 0.3, red: 0, green: 0, blue: 0),
    );
    expect(
      CoilColors.lerp(CoilColors.light, CoilColors.dark, 0.5).scrim.a,
      closeTo(0.25, 0.001),
    );
    const custom = Color(0x66000000);
    expect(CoilColors.light.copyWith(scrim: custom).scrim, custom);
    expect(
      CoilColors.fromSeed(
        brightness: Brightness.dark,
        neutralChroma: 0.02,
      ).scrim,
      CoilColors.dark.scrim,
    );
  });
}
