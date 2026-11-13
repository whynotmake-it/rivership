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
}
