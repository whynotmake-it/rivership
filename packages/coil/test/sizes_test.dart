import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

/// The four size sets, as columns.
const _tiers = [
  ('desktop', CoilTier.pointer, CoilSize.regular),
  ('desktop compact', CoilTier.pointer, CoilSize.compact),
  ('touch', CoilTier.touch, CoilSize.regular),
  ('touch compact', CoilTier.touch, CoilSize.compact),
];

/// Tints the layout box of [child] so the hit area is visible.
class _HitArea extends StatelessWidget {
  const _HitArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CoilTheme.of(context).colors.brand.withValues(
      alpha: 0.12,
    ),
    child: child,
  );
}

/// coil's built-in sizes.
const _table = CoilMetricsTable();

void main() {
  testWidgets('desktop vs touch size comparison', (tester) async {
    final rows = <(String, Widget Function())>[
      (
        'button',
        () => CoilButton(onPressed: () {}, child: const Text('Continue')),
      ),
      (
        'button · icons',
        () => CoilButton(
          onPressed: () {},
          variant: CoilButtonVariant.secondary,
          leading: const TestIcon(TestGlyph.plus),
          child: const Text('New file'),
        ),
      ),
      (
        'icon button',
        () => CoilButton.icon(
          onPressed: () {},
          variant: CoilButtonVariant.tertiary,
          semanticLabel: 'Search',
          icon: const TestIcon(TestGlyph.search),
        ),
      ),
      (
        'switch',
        () => CoilSwitch(
          value: true,
          onChanged: (_) {},
          label: const Text('Sync'),
        ),
      ),
      (
        'checkbox',
        () => CoilCheckbox(value: true, onChanged: (_) {}),
      ),
      (
        'tabs',
        () => CoilTabs(
          tabs: const [
            CoilTab(value: 0, label: Text('Day')),
            CoilTab(value: 1, label: Text('Week')),
            CoilTab(value: 2, label: Text('Month')),
          ],
          value: 1,
          onChanged: (_) {},
        ),
      ),
      (
        'input',
        () => SizedBox(
          width: 200,
          child: CoilInput(
            controller: TextEditingController(text: 'Ada Lovelace'),
          ),
        ),
      ),
    ];

    const colors = CoilColors.light;
    final caption = const CoilTypography().style(
      CoilMetrics.pointer.caption,
      color: colors.mutedForeground,
    );
    final sheet = SheetPanel(
      title:
          'Sizes · desktop (web parity) vs touch (44 px hit targets) · '
          'tinted = layout / hit area',
      theme: CoilThemeData.light,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox(),
              for (final (label, tier, size) in _tiers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '$label · '
                    '${_table.resolve(tier, size).controlHeight.round()} px',
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
                for (final (_, tier, size) in _tiers)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CoilAdaptiveScope(
                        tier: tier,
                        size: size,
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
    await expectSheetGolden(tester, finder, 'goldens/sizes.png');
  });

  test('touch tier raises every hit target to 44', () {
    for (final size in CoilSize.values) {
      expect(
        _table.resolve(CoilTier.touch, size).minHitTarget,
        44,
      );
    }
  });
}
