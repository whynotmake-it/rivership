import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

/// The four size sets, as columns.
const _tiers = [
  ('desktop', FluidTier.desktop, FluidDensity.regular),
  ('desktop compact', FluidTier.desktop, FluidDensity.compact),
  ('touch', FluidTier.touch, FluidDensity.regular),
  ('touch compact', FluidTier.touch, FluidDensity.compact),
];

/// Tints the layout box of [child] so the hit area is visible.
class _HitArea extends StatelessWidget {
  const _HitArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FluidTheme.of(context).colors.fluidAccent.withValues(
      alpha: 0.12,
    ),
    child: child,
  );
}

void main() {
  testWidgets('desktop vs touch size comparison', (tester) async {
    final rows = <(String, Widget Function())>[
      (
        'button',
        () => FluidButton(onPressed: () {}, child: const Text('Continue')),
      ),
      (
        'button · icons',
        () => FluidButton(
          onPressed: () {},
          variant: FluidButtonVariant.secondary,
          leading: const FluidIcon(FluidIcons.plus),
          child: const Text('New file'),
        ),
      ),
      (
        'icon button',
        () => FluidButton.icon(
          onPressed: () {},
          variant: FluidButtonVariant.tertiary,
          semanticLabel: 'Search',
          icon: const FluidIcon(FluidIcons.search),
        ),
      ),
      (
        'switch',
        () => FluidSwitch(
          value: true,
          onChanged: (_) {},
          label: const Text('Sync'),
        ),
      ),
      (
        'checkbox',
        () => FluidCheckbox(value: true, onChanged: (_) {}),
      ),
      (
        'tabs',
        () => FluidTabs(
          tabs: const [
            FluidTab(label: Text('Day')),
            FluidTab(label: Text('Week')),
            FluidTab(label: Text('Month')),
          ],
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      ),
      (
        'input',
        () => SizedBox(
          width: 200,
          child: FluidInput(
            controller: TextEditingController(text: 'Ada Lovelace'),
          ),
        ),
      ),
    ];

    const colors = FluidColors.light;
    final caption = FluidTypography.style(
      FluidSizes.desktop.caption,
      color: colors.mutedForeground,
    );
    final sheet = SheetPanel(
      title:
          'Sizes · desktop (web parity) vs touch (44 px hit targets) · '
          'tinted = layout / hit area',
      theme: FluidThemeData.light,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox(),
              for (final (label, tier, density) in _tiers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '$label · '
                    '${FluidSizes.resolve(tier, density).controlHeight.round()}'
                    ' px',
                    style: caption,
                  ),
                ),
            ],
          ),
          for (final (label, build) in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(label, style: caption),
                ),
                for (final (_, tier, density) in _tiers)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FluidSizeScope(
                        tier: tier,
                        density: density,
                        child: _HitArea(child: build()),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
    final finder = await pumpSheet(tester, sheet);
    await expectLater(finder, matchesGoldenFile('goldens/sizes.png'));
  });

  test('touch tier raises every hit target to 44', () {
    for (final density in FluidDensity.values) {
      final sizes = FluidSizes.resolve(FluidTier.touch, density);
      expect(sizes.minHitTarget, 44);
      expect(sizes.field.fontSize, greaterThanOrEqualTo(16));
    }
    expect(FluidSizes.desktop.controlHeight, 36);
    expect(FluidSizes.desktopCompact.controlHeight, 28);
  });
}
