import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const badgeEntry = CatalogEntry(
  slug: 'badge',
  title: 'Badge',
  group: CatalogGroup.leafControls,
  summary: 'Status and categories: solid, dot and ghost, in 18 colors.',
  page: BadgePage.new,
);

class BadgePage extends StatefulWidget {
  const BadgePage({super.key});

  @override
  State<BadgePage> createState() => _BadgePageState();
}

class _BadgePageState extends State<BadgePage> {
  var _variant = CoilBadgeVariant.solid;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Badge',
    summary:
        "Badges label status and categories. They aren't interactive, so "
        "they don't grow on touch.",
    children: [
      DemoSection(
        title: 'In context',
        child: DemoColumn(
          spacing: 8,
          children: [
            for (final (name, status, color) in const [
              ('Billing service', 'Healthy', CoilBadgeColor.green),
              ('Search index', 'Degraded', CoilBadgeColor.amber),
              ('Webhooks', 'Down', CoilBadgeColor.red),
              ('Exports', 'Beta', CoilBadgeColor.brand),
            ])
              Row(
                children: [
                  Expanded(child: RoleText(name, role: TypeRole.body)),
                  CoilBadge(
                    variant: CoilBadgeVariant.dot,
                    color: color,
                    child: Text(status),
                  ),
                ],
              ),
          ],
        ),
      ),
      DemoSection(
        title: 'Variants and colors',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Variant'),
              orientation: CoilFieldOrientation.responsive,
              child: CoilSelect<CoilBadgeVariant>(
                value: _variant,
                onChanged: (value) => setState(() => _variant = value),
                options: [
                  for (final v in CoilBadgeVariant.values)
                    CoilOption(
                      value: v,
                      label: Text(v.name),
                      searchText: v.name,
                    ),
                ],
              ),
            ),
            DemoWrap(
              children: [
                for (final color in CoilBadgeColor.values)
                  CoilBadge(
                    variant: _variant,
                    color: color,
                    child: Text(color.name),
                  ),
              ],
            ),
          ],
        ),
      ),
      const DemoSection(
        title: 'Compact',
        child: DemoWrap(
          children: [
            CoilBadge(size: CoilSize.compact, child: Text('Draft')),
            CoilBadge(
              size: CoilSize.compact,
              color: CoilBadgeColor.blue,
              child: Text('v2.1'),
            ),
            CoilBadge(
              size: CoilSize.compact,
              variant: CoilBadgeVariant.dot,
              color: CoilBadgeColor.green,
              child: Text('Live'),
            ),
          ],
        ),
      ),
    ],
  );
}
