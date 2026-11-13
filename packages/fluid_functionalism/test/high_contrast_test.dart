import 'package:fluid_functionalism/fluid_functionalism.dart';
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
        FluidButton(
          onPressed: () {},
          variant: FluidButtonVariant.tertiary,
          statesController: focused(),
          child: const Text('Focused'),
        ),
        FluidSwitch(value: false, onChanged: (_) {}, label: const Text('Off')),
        FluidSwitch(
          value: true,
          onChanged: (_) {},
          statesController: focused(),
          semanticLabel: 'On',
        ),
        FluidCheckbox(value: false, onChanged: (_) {}),
        FluidCheckbox(
          value: true,
          onChanged: (_) {},
          statesController: focused(),
        ),
        SizedBox(
          width: 160,
          child: FluidInput(
            controller: TextEditingController(text: 'Ada'),
          ),
        ),
        FluidTabs(
          tabs: const [
            FluidTab(label: Text('Day')),
            FluidTab(label: Text('Week')),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
          debugFocusedIndex: 1,
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
          style: FluidTypography.style(
            FluidSizes.desktop.caption,
            color: FluidTheme.of(context).colors.mutedForeground,
          ),
        ),
        const _Controls(),
      ],
    ),
  ),
);

void main() {
  testWidgets('high contrast resolution', (tester) async {
    late FluidThemeData resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: FluidTheme(
          data: FluidThemeData.light,
          child: Builder(
            builder: (context) {
              resolved = FluidTheme.of(context);
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
      FluidColorMix.contrastRatio(c.focusRing, c.background),
      greaterThanOrEqualTo(3),
    );
    expect(
      FluidColorMix.contrastRatio(FluidColors.light.fluidAccent, c.background),
      lessThan(3),
      reason: 'the stock accent fails 3:1 on the light background',
    );
    // The off track gets stronger than the stock one.
    expect(
      FluidColorMix.contrastRatio(c.accent, c.background),
      greaterThan(
        FluidColorMix.contrastRatio(
          FluidColors.light.accent,
          FluidColors.light.background,
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
}
