import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const badgeEntry = CatalogEntry(
  slug: 'badge',
  title: 'Badge',
  group: CatalogGroup.leafControls,
  summary: 'A small label for a status or a category, in 18 colors.',
  page: BadgePage.new,
);

class BadgePage extends StatefulWidget {
  const BadgePage({super.key});

  @override
  State<BadgePage> createState() => _BadgePageState();
}

class _BadgePageState extends State<BadgePage> {
  var _variant = CoilBadgeVariant.solid;
  var _shape = CoilBadgeShape.item;
  var _compact = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Badge',
    summary:
        'A badge is a short, quiet label for a status or a category. It is '
        'never interactive, so it keeps the same size on touch.',
    hero: const _ServiceStatus(),
    usage: '''
CoilBadge(
  variant: CoilBadgeVariant.dot,
  color: health.color,
  child: Text(health.label),
)''',
    notes: const [
      CatalogNote(
        'Motion',
        'When the label changes, the old text cross-fades into the new text '
            'while the badge springs to its new width.',
      ),
      CatalogNote(
        'Touch',
        'A badge is 24 tall (20 when compact) on every tier, since there is '
            'nothing to press and so no need for a larger touch target.',
      ),
      CatalogNote(
        'Screen readers',
        'A badge is read as its label and the dot is skipped, so put the '
            'status into words rather than relying on color alone.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Use a badge to show a status or a category, and reach for a '
            'secondary button when the label needs to be tapped.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Variant',
              value: _variant,
              values: CoilBadgeVariant.values,
              labelOf: (v) => switch (v) {
                CoilBadgeVariant.solid => 'Solid',
                CoilBadgeVariant.dot => 'Dot',
                CoilBadgeVariant.ghost => 'Ghost',
              },
              onChanged: (v) => setState(() => _variant = v),
            ),
            DemoControl.choice(
              label: 'Shape',
              value: _shape,
              values: CoilBadgeShape.values,
              labelOf: (v) => switch (v) {
                CoilBadgeShape.item => 'Item',
                CoilBadgeShape.pill => 'Pill',
              },
              onChanged: (v) => setState(() => _shape = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
          ],
        ),
        child: DemoWrap(
          children: [
            for (final color in CoilBadgeColor.values)
              CoilBadge(
                variant: _variant,
                shape: _shape,
                size: _compact ? CoilSize.compact : null,
                color: color,
                child: Text(_capitalize(color.name)),
              ),
          ],
        ),
      ),
    ],
  );

  static String _capitalize(String name) =>
      name[0].toUpperCase() + name.substring(1);
}

/// A status list: dot badges name each service's state, and a solid badge
/// counts the healthy ones. Breaking a service changes both labels.
class _ServiceStatus extends StatefulWidget {
  const _ServiceStatus();

  @override
  State<_ServiceStatus> createState() => _ServiceStatusState();
}

class _ServiceStatusState extends State<_ServiceStatus> {
  var _webhooksDown = false;
  var _reindexing = true;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).buttonGap;
    final services = [
      ('Billing', 'Charges and invoices', _Health.healthy),
      (
        'Search index',
        'Rebuilt every night',
        _reindexing ? _Health.degraded : _Health.healthy,
      ),
      (
        'Webhooks',
        'Delivery to your endpoints',
        _webhooksDown ? _Health.down : _Health.healthy,
      ),
    ];
    final healthy = services.where((s) => s.$3 == _Health.healthy).length;
    final allHealthy = healthy == services.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Services', style: text.title)),
            CoilBadge(
              color: allHealthy ? CoilBadgeColor.green : CoilBadgeColor.gray,
              child: Text(
                allHealthy
                    ? 'All healthy'
                    : '$healthy of ${services.length} healthy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (name, detail, health) in services)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.body),
                      Text(detail, style: text.muted.caption),
                    ],
                  ),
                ),
                CoilBadge(
                  variant: CoilBadgeVariant.dot,
                  color: health.color,
                  child: Text(health.label),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              leading: const CatalogIcon(Glyph.zap),
              onPressed: () => setState(() => _webhooksDown = !_webhooksDown),
              child: Text(
                _webhooksDown ? 'Restore webhooks' : 'Break webhooks',
              ),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              onPressed: () => setState(() => _reindexing = !_reindexing),
              child: Text(_reindexing ? 'Finish reindex' : 'Start reindex'),
            ),
          ],
        ),
      ],
    );
  }
}

enum _Health {
  healthy('Healthy', CoilBadgeColor.green),
  degraded('Degraded', CoilBadgeColor.amber),
  down('Down', CoilBadgeColor.red);

  const _Health(this.label, this.color);

  final String label;
  final CoilBadgeColor color;
}
