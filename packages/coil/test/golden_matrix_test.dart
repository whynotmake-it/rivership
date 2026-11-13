// Every component across the golden matrix: light/dark × pointer/touch, each
// at text scale 1, 1.5 and 2, in RTL and in high contrast. Real fonts
// (Inter, loaded in flutter_test_config.dart), rendered at 2x.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/select_harness.dart';
import 'src/test_icons.dart';

/// One column of the matrix.
enum _Variant {
  scale1('1×'),
  scale15('1.5×'),
  scale2('2×'),
  rtl('RTL'),
  highContrast('high contrast');

  const _Variant(this.label);

  final String label;

  double get scale => switch (this) {
    scale15 => 1.5,
    scale2 => 2,
    _ => 1,
  };
}

/// The component stories. Each builds the component at rest.
final Map<String, WidgetBuilder> _stories = {
  'button': (context) => Wrap(
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
  'checkbox': (context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CoilCheckbox(value: true, onChanged: (_) {}),
      const SizedBox(width: 12),
      CoilCheckbox(value: false, onChanged: (_) {}),
      const SizedBox(width: 12),
      CoilCheckbox(value: null, tristate: true, onChanged: (_) {}),
      const SizedBox(width: 12),
      const CoilCheckbox(value: false, onChanged: null),
    ],
  ),
  'switch': (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CoilSwitch(value: true, onChanged: (_) {}, label: const Text('Wi-Fi')),
      CoilSwitch(value: false, onChanged: (_) {}, label: const Text('Sync')),
    ],
  ),
  'tabs': (context) => CoilTabs(
    tabs: const [
      CoilTab(label: 'Overview', icon: TestIcon(TestGlyph.home)),
      CoilTab(label: 'Analytics', icon: TestIcon(TestGlyph.heart)),
      CoilTab(label: 'Settings', icon: TestIcon(TestGlyph.settings)),
    ],
    value: 1,
    onChanged: (_) {},
  ),
  'input': (context) => SizedBox(
    width: 240,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoilInput(
          placeholder: Text('Search'),
          leading: TestIcon(TestGlyph.search),
        ),
        const SizedBox(height: 8),
        CoilInput(
          controller: TextEditingController(text: 'ada@example.com'),
          invalid: true,
        ),
      ],
    ),
  ),
  'selection_groups': (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 220,
        child: CoilCheckboxGroup(
          values: const {0, 1},
          onChanged: (_) {},
          children: const [Text('Email'), Text('Push'), Text('SMS')],
        ),
      ),
      const SizedBox(height: 8),
      CoilToggleGroup(
        values: const {0, 1},
        onChanged: (_) {},
        children: const [Text('Bold'), Text('Italic'), Text('Underline')],
      ),
    ],
  ),
  'select': (context) => SizedBox(
    width: 220,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoilSelect<String>(options: fruits, value: 'banana', onChanged: (_) {}),
        const SizedBox(height: 8),
        CoilSelect<String>(options: fruits, value: null, onChanged: (_) {}),
      ],
    ),
  ),
};

class _Matrix extends StatelessWidget {
  const _Matrix(this.story);

  final WidgetBuilder story;

  @override
  Widget build(BuildContext context) {
    final caption = const CoilTypography().style(
      CoilMetrics.pointer.caption,
      color: const Color(0xFF737373),
    );
    Widget cell(CoilThemeData theme, CoilTier tier, _Variant variant) =>
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
                  highContrast: variant == _Variant.highContrast,
                ),
                child: Directionality(
                  textDirection: variant == _Variant.rtl
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
                    for (final variant in _Variant.values)
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

void main() {
  for (final MapEntry(key: name, value: story) in _stories.entries) {
    testWidgets('$name matrix', (tester) async {
      final sheet = await pumpSheet(
        tester,
        _Matrix(story),
        surface: const Size(2800, 1800),
      );
      await expectSheetGolden(tester, sheet, 'goldens/matrix/$name.png');
    });
  }

  // The open select in both presentations, light and dark.
  for (final (name, colors) in [
    ('light', CoilColors.light),
    ('dark', CoilColors.dark),
  ]) {
    testWidgets('select popover open ($name, pointer)', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(),
          tier: CoilTier.pointer,
          colors: colors,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('select')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/matrix/select_popover_$name.png'),
      );
    });

    testWidgets('select sheet open ($name, touch)', (tester) async {
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
        matchesGoldenFile('goldens/matrix/select_sheet_$name.png'),
      );
    });
  }
}
