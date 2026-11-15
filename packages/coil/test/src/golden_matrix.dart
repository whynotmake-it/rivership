import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_sheet.dart';

/// One column of the matrix.
enum MatrixVariant {
  scale1('1×'),
  scale15('1.5×'),
  scale2('2×'),
  rtl('RTL'),
  highContrast('high contrast');

  const MatrixVariant(this.label);

  final String label;

  double get scale => switch (this) {
    scale15 => 1.5,
    scale2 => 2,
    _ => 1,
  };
}

/// [story] across the golden matrix: light/dark × pointer/touch, each at
/// text scale 1, 1.5 and 2, in RTL and in high contrast.
class GoldenMatrix extends StatelessWidget {
  /// Creates the matrix.
  const GoldenMatrix(this.story, {super.key});

  /// Builds the component at rest.

  final WidgetBuilder story;

  @override
  Widget build(BuildContext context) {
    final caption = const CoilTypography().style(
      CoilMetrics.pointer.caption,
      color: const Color(0xFF737373),
    );
    Widget cell(CoilThemeData theme, CoilTier tier, MatrixVariant variant) =>
        Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(variant.label, style: caption),
              const SizedBox(height: 4),
              MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(variant.scale),
                  highContrast: variant == MatrixVariant.highContrast,
                ),
                child: Directionality(
                  textDirection: variant == MatrixVariant.rtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: CoilTheme(
                    data: theme.copyWith(tier: tier),
                    child: Builder(
                      builder: (context) => ColoredBox(
                        color: CoilTheme.of(context).colors.background,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Builder(builder: story),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (name, theme) in [
              ('light', CoilThemeData.light),
              ('dark', CoilThemeData.dark),
            ])
              for (final tier in CoilTier.values) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 6),
                  child: Text('$name · ${tier.name}', style: caption),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final variant in MatrixVariant.values)
                      cell(theme, tier, variant),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// A golden test of [story] across the matrix, written to
/// `goldens/matrix/<name>.png` (relative to the calling test file).
void matrixGoldenTest(
  String name,
  WidgetBuilder story, {
  Size surface = const Size(2800, 2800),
}) {
  testWidgets('$name matrix', (tester) async {
    final sheet = await pumpSheet(
      tester,
      GoldenMatrix(story),
      surface: surface,
    );
    await expectSheetGolden(tester, sheet, 'goldens/matrix/$name.png');
  });
}
