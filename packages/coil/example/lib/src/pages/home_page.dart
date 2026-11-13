import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/nav_row.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

/// Every foundation and component, grouped as in DESIGN.md §14. Components
/// that aren't built yet are listed as planned.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'coil',
    summary:
        'Every foundation and component, live. Open the settings in the '
        'corner to change theme, size tier, text scale, direction, contrast '
        'and motion.',
    children: [
      for (final group in CatalogGroup.values)
        _GroupList(group: group, rows: _rowsFor(group)),
    ],
  );

  /// The group's rows: built entries in DESIGN.md's order, planned ones
  /// in place, and any entry DESIGN.md doesn't name at the end.
  static List<(String, CatalogEntry?)> _rowsFor(CatalogGroup group) {
    final built = {
      for (final e in catalogEntries)
        if (e.group == group) e.title: e,
    };
    final planned = designComponents[group] ?? const [];
    return [
      for (final title in planned) (title, built.remove(title)),
      for (final entry in built.values) (entry.title, entry),
    ];
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.group, required this.rows});

  final CatalogGroup group;
  final List<(String, CatalogEntry?)> rows;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final builtCount = rows.where((r) => r.$2 != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: RoleText(
            group.title,
            role: TypeRole.subtitle,
            weight: CoilWeight.semibold,
          ),
        ),
        if (group != CatalogGroup.foundations) ...[
          const SizedBox(height: 2),
          RoleText(
            '$builtCount of ${rows.length} built',
            role: TypeRole.caption,
            muted: true,
          ),
        ],
        const SizedBox(height: 8),
        DemoStage(
          padding: metrics.popupInset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (title, entry) in rows)
                NavRow(
                  title: title,
                  summary: entry?.summary ?? 'Specified in DESIGN.md §14.',
                  onPressed: entry == null
                      ? null
                      : () => unawaited(
                          context.router.push(
                            NamedRoute(catalogRouteName(entry)),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
