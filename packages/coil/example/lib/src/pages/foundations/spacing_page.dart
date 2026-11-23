import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const spacingEntry = CatalogEntry(
  slug: 'spacing',
  title: 'Spacing and sizes',
  group: CatalogGroup.foundations,
  summary: 'The CoilMetrics ladder for pointer and touch, regular and compact.',
  page: SpacingPage.new,
);

typedef _Metric = (String name, String Function(CoilMetrics m) read);

String _n(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

final _metrics = <_Metric>[
  ('controlHeight', (m) => _n(m.controlHeight)),
  ('minHitTarget', (m) => _n(m.minHitTarget)),
  ('controlPaddingX', (m) => _n(m.controlPaddingX)),
  ('itemPaddingX', (m) => _n(m.itemPaddingX)),
  ('popupInset', (m) => _n(m.popupInset)),
  ('gap', (m) => _n(m.gap)),
  ('iconSize', (m) => _n(m.iconSize)),
  ('buttonPaddingX', (m) => _n(m.buttonPaddingX)),
  ('buttonIconPaddingX', (m) => _n(m.buttonIconPaddingX)),
  ('buttonGap', (m) => _n(m.buttonGap)),
  ('checkboxSize', (m) => _n(m.checkboxSize)),
  ('checkboxRadius', (m) => _n(m.checkboxRadius)),
  (
    'switch track',
    (m) =>
        '${_n(m.switchMetrics.trackWidth)}×'
        '${_n(m.switchMetrics.trackHeight)}',
  ),
  ('switch thumb', (m) => _n(m.switchMetrics.thumbSize)),
  ('segmentPadding', (m) => _n(m.segmentPadding)),
];

const _columns = [
  ('P', CoilTier.pointer, CoilSize.regular),
  ('Pc', CoilTier.pointer, CoilSize.compact),
  ('T', CoilTier.touch, CoilSize.regular),
  ('Tc', CoilTier.touch, CoilSize.compact),
];

class SpacingPage extends StatelessWidget {
  const SpacingPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'Spacing and sizes',
    summary:
        'Heights are minimums: they grow with text. Gaps and paddings '
        "don't scale.",
    children: [
      DemoSection(
        title: 'Control heights',
        description:
            'Pointer, pointer compact, touch and touch compact, '
            'drawn to scale.',
        child: _Heights(),
      ),
      DemoSection(
        title: 'The ladder',
        description:
            'CoilMetrics per tier and size step. The current tier is '
            'highlighted. Popup rows line up with triggers: controlPaddingX = '
            'popupInset + itemPaddingX.',
        child: _Ladder(),
      ),
      DemoSection(
        title: 'Spacing scale',
        description: 'Every spacing value comes from this set.',
        child: _Scale(),
      ),
    ],
  );
}

class _Heights extends StatelessWidget {
  const _Heights();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    final text = CoilTheme.textOf(context);
    return DemoWrap(
      spacing: 16,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final (label, tier, size) in _columns)
          Builder(
            builder: (context) {
              final m = CoilTheme.of(context).metrics.resolve(tier, size);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: m.controlHeight,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.active,
                        shape: RoundedSuperellipseBorder(borderRadius: radius),
                      ),
                      child: Center(
                        child: Text(
                          _n(m.controlHeight),
                          style: text.caption,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: text.muted.caption),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Ladder extends StatelessWidget {
  const _Ladder();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final current = CoilTheme.tierOf(context);
    final text = CoilTheme.textOf(context);
    final header = text.muted.caption.copyWith(fontWeight: text.emphasis);
    final cell = text.caption.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final name = text.muted.caption;
    final highlight = ShapeDecoration(
      color: colors.hover,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(4)),
    );
    Widget at(Widget child, CoilTier tier) => DecoratedBox(
      decoration: tier == current ? highlight : const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: child,
      ),
    );
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text('Token', style: header),
            ),
            for (final (label, tier, _) in _columns)
              at(Text(label, style: header), tier),
          ],
        ),
        for (final (metric, read) in _metrics)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(metric, style: name),
              ),
              for (final (_, tier, size) in _columns)
                at(
                  Text(
                    read(CoilTheme.of(context).metrics.resolve(tier, size)),
                    style: cell,
                  ),
                  tier,
                ),
            ],
          ),
      ],
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale();

  static const _values = [2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 48];

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return DemoWrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final v in _values)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: v.toDouble(),
                height: v.toDouble(),
                child: ColoredBox(color: colors.brand),
              ),
              const SizedBox(height: 4),
              Text('$v', style: text.muted.micro),
            ],
          ),
      ],
    );
  }
}
