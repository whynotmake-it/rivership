import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

/// A row of controls, some in the keyboard-focus state.
class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    WidgetStatesController focused() =>
        WidgetStatesController({WidgetState.focused});
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        CoilButton(
          onPressed: () {},
          variant: CoilButtonVariant.tertiary,
          statesController: focused(),
          child: const Text('Focused'),
        ),
        CoilSwitch(value: false, onChanged: (_) {}, label: const Text('Off')),
        CoilSwitch(
          value: true,
          onChanged: (_) {},
          statesController: focused(),
          semanticLabel: 'On',
        ),
        CoilCheckbox(value: false, onChanged: (_) {}),
        CoilCheckbox(
          value: true,
          onChanged: (_) {},
          statesController: focused(),
        ),
        SizedBox(
          width: 160,
          child: CoilInput(
            controller: TextEditingController(text: 'Ada'),
          ),
        ),
        CoilTabs(
          tabs: const [
            CoilTab(value: 0, label: 'Day'),
            CoilTab(value: 1, label: 'Week'),
          ],
          value: 0,
          onChanged: (_) {},
        ),
      ],
    );
  }
}

Widget _row(String label, {required bool highContrast}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(highContrast: highContrast),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          label,
          style: const CoilTypography().style(
            CoilMetrics.pointer.caption,
            color: CoilTheme.of(context).colors.mutedForeground,
          ),
        ),
        const _Controls(),
      ],
    ),
  ),
);

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
    expect(resolved.focusRingWidth, 2);
    expect(
      CoilColorMix.contrastRatio(c.focusRing, c.background),
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

  testWidgets('golden: normal vs high contrast', (tester) async {
    final sheet = await pumpSheet(
      tester,
      ThemedPair(
        title: 'High contrast',
        direction: Axis.vertical,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 20,
          children: [
            _row('standard', highContrast: false),
            _row('MediaQuery.highContrast', highContrast: true),
          ],
        ),
      ),
    );
    await expectSheetGolden(tester, sheet, 'goldens/high_contrast.png');
  });

  testWidgets('golden: tabs focus ring in high contrast', (tester) async {
    final sheet = await pumpSheet(
      tester,
      SheetPanel(
        title: 'Tabs, keyboard focus, high contrast',
        theme: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: FocusScope(
              autofocus: true,
              child: CoilTabs(
                tabs: const [
                  CoilTab(value: 0, label: 'Day'),
                  CoilTab(value: 1, label: 'Week'),
                ],
                value: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
      surface: const Size(400, 200),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    await expectSheetGolden(
      tester,
      sheet,
      'goldens/high_contrast_tabs_focus.png',
    );
  });
}
