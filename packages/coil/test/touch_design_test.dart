// The touch-tier design board (research/08-touch-tier.md): the touch
// components next to their pointer counterparts, and the open select in its
// touch presentations, light and dark. Rendered before and after the touch
// token pass; `test/goldens/touch_design/compare_*.png` puts them side by
// side.
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/select_harness.dart';
import 'src/test_icons.dart';

const _stage = String.fromEnvironment('stage', defaultValue: 'after');

String _path(String name) => 'goldens/touch_design/${_stage}_$name.png';

class _Board extends StatelessWidget {
  const _Board({required this.colors});

  final CoilColors colors;

  @override
  Widget build(BuildContext context) {
    final caption = const CoilTypography().style(
      CoilMetrics.pointer.caption,
      color: colors.mutedForeground,
    );
    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: caption),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    Widget column(CoilTier tier) => CoilTheme(
      data: CoilThemeData(colors: colors).copyWith(tier: tier),
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tier.name, style: caption),
            const SizedBox(height: 16),
            section(
              'buttons',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CoilButton(
                    onPressed: () {},
                    leading: const TestIcon(TestGlyph.plus),
                    child: const Text('New file'),
                  ),
                  CoilButton(
                    onPressed: () {},
                    variant: CoilButtonVariant.secondary,
                    child: const Text('Cancel'),
                  ),
                  CoilButton(
                    onPressed: () {},
                    variant: CoilButtonVariant.tertiary,
                    trailing: const TestIcon(TestGlyph.arrowRight),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
            section(
              'merged selection',
              CoilCheckboxGroup(
                values: const {0, 1, 3},
                onChanged: (_) {},
                options: const [
                  CoilOption(
                    value: 0,
                    label: Text('Email'),
                    searchText: 'Email',
                  ),
                  CoilOption(
                    value: 1,
                    label: Text('Push notifications'),
                    searchText: 'Push notifications',
                  ),
                  CoilOption(value: 2, label: Text('SMS'), searchText: 'SMS'),
                  CoilOption(
                    value: 3,
                    label: Text('Weekly digest'),
                    searchText: 'Weekly digest',
                  ),
                ],
              ),
            ),
            section(
              'toggle group',
              CoilToggleGroup(
                values: const {0, 1},
                onChanged: (_) {},
                options: const [
                  CoilOption(value: 0, label: Text('Bold'), searchText: 'Bold'),
                  CoilOption(
                    value: 1,
                    label: Text('Italic'),
                    searchText: 'Italic',
                  ),
                  CoilOption(
                    value: 2,
                    label: Text('Underline'),
                    searchText: 'Underline',
                  ),
                ],
              ),
            ),
            section(
              'tabs',
              CoilTabs(
                tabs: const [
                  CoilTab(
                    value: 0,
                    label: Text('Overview'),
                    icon: TestIcon(TestGlyph.home),
                  ),
                  CoilTab(
                    value: 1,
                    label: Text('Activity'),
                    icon: TestIcon(TestGlyph.heart),
                  ),
                  CoilTab(
                    value: 2,
                    label: Text('Settings'),
                    icon: TestIcon(TestGlyph.settings),
                  ),
                ],
                value: 1,
                onChanged: (_) {},
              ),
            ),
            section(
              'input',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoilInput(
                    placeholder: Text('Search'),
                    leading: TestIcon(TestGlyph.search),
                  ),
                  const SizedBox(height: 8),
                  CoilInput(
                    controller: TextEditingController(text: 'ada@example.com'),
                  ),
                ],
              ),
            ),
            section(
              'switch, checkbox',
              Row(
                children: [
                  CoilSwitch(
                    value: true,
                    onChanged: (_) {},
                    label: const Text('Wi-Fi'),
                  ),
                  const SizedBox(width: 16),
                  CoilCheckbox(value: true, onChanged: (_) {}),
                  const SizedBox(width: 8),
                  CoilCheckbox(value: false, onChanged: (_) {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            column(CoilTier.pointer),
            const SizedBox(width: 32),
            column(CoilTier.touch),
          ],
        ),
      ),
    );
  }
}

void main() {
  for (final (name, colors) in [
    ('light', CoilColors.light),
    ('dark', CoilColors.dark),
  ]) {
    testWidgets('board ($name)', (tester) async {
      final sheet = await pumpSheet(
        tester,
        _Board(colors: colors),
        surface: const Size(900, 960),
      );
      await expectSheetGolden(tester, sheet, _path('board_$name'));
    });

    testWidgets('sheet ($name)', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(options: moreFruits),
          tier: CoilTier.touch,
          colors: colors,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('select')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile(_path('sheet_$name')),
      );
    });

    testWidgets('multi-select sheet ($name)', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(
            options: moreFruits,
            multiple: true,
            initialValues: {'banana', 'blueberry', 'cherry', 'orange'},
          ),
          tier: CoilTier.touch,
          colors: colors,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('select')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile(_path('multi_sheet_$name')),
      );
    });

    testWidgets('touch popover ($name)', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(),
          tier: CoilTier.touch,
          colors: colors,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('select')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile(_path('popover_$name')),
      );
    });
  }
}
