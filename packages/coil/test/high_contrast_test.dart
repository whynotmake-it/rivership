import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('high contrast resolution', (tester) async {
    late CoilThemeData resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: CoilTheme(
          data: CoilThemeData.light,
          child: Builder(
            builder: (context) {
              resolved = CoilTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final c = resolved.colors;
    expect(c.borderAlpha, 0.4);
    expect(resolved.focusRing.width, 2);
    expect(
      CoilColorMix.contrastRatio(resolved.focusRing.colorOf(c), c.background),
      greaterThanOrEqualTo(3),
    );
    expect(
      CoilColorMix.contrastRatio(CoilColors.light.brand, c.background),
      lessThan(3),
      reason: 'the stock accent fails 3:1 on the light background',
    );
    // The off track gets stronger than the stock one.
    expect(
      CoilColorMix.contrastRatio(c.accent, c.background),
      greaterThan(
        CoilColorMix.contrastRatio(
          CoilColors.light.accent,
          CoilColors.light.background,
        ),
      ),
    );
  });
}
