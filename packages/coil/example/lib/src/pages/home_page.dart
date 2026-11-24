import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/home/bento.dart';
import 'package:coil_example/src/pages/home/tiles.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';
import 'package:coil_example/src/shell/navigation.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// The catalog's front page: what coil is in a sentence, then a grid of
/// live product surfaces built from its components, each linking to the
/// components it uses, and an index of every page.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// The widest the home page's content gets.
  static const maxWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    final gutter = CatalogLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    // The page draws behind the keyboard; padding its end by the
    // keyboard's height lets the last field scroll above it.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CatalogHeader(title: 'Home'),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CoilScrollArea(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    gutter + padding.left,
                    0,
                    gutter + padding.right,
                    gutter + padding.bottom + 24 + keyboard,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Hero(),
                          BentoGrid(tiles: homeTiles),
                          const SizedBox(height: 48),
                          const _Index(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    final settings = CatalogSettingsScope.of(context);
    final canFrame =
        CatalogChrome.hasTopBarOf(context) &&
        settings.viewport == CatalogViewport.desktop;
    final router = AutoRouter.of(context);
    final components = catalogEntries
        .where((e) => e.group != CatalogGroup.foundations)
        .length;
    final gap = CoilTheme.metricsOf(context).buttonGap;
    return Padding(
      padding: EdgeInsets.only(top: touch ? 16 : 32, bottom: touch ? 32 : 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Refined components, on springs.',
                  style: text.display,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'coil is a design system for pointer and touch, with every '
                'bit of motion driven by a spring. Everything on these pages '
                'is live, so you can hover, press, drag and tab through any '
                'of it.',
                style: text.muted.subtitle,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  CoilButton(
                    leading: const CatalogIcon(Glyph.search),
                    onPressed: () =>
                        unawaited(showCatalogSearch(context, router)),
                    child: const Text('Find a component'),
                  ),
                  if (canFrame)
                    CoilButton(
                      variant: CoilButtonVariant.secondary,
                      leading: const CatalogIcon(Glyph.smartphone),
                      onPressed: () =>
                          settings.viewport = CatalogViewport.mobile,
                      child: const Text('Try it on a phone'),
                    ),
                  CoilButton(
                    variant: CoilButtonVariant.ghost,
                    trailing: const CatalogIcon(Glyph.arrowRight),
                    onPressed: () => unawaited(
                      openCatalogPage(
                        router,
                        catalogEntries.firstWhere(
                          (e) => e.group != CatalogGroup.foundations,
                        ),
                      ),
                    ),
                    child: const Text('Start with Button'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final fact in [
                    '$components components',
                    'Pointer and touch',
                    'Light and dark',
                    'Right to left',
                    'Text up to 2×',
                    'Fixed frame rates',
                  ])
                    CoilBadge(
                      variant: CoilBadgeVariant.ghost,
                      child: Text(fact),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every page, by group, as links: the way in to the components no tile
/// shows.
class _Index extends StatelessWidget {
  const _Index();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final router = AutoRouter.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Every page', style: text.title),
        ),
        const SizedBox(height: 4),
        Text(
          'Each page shows its component in every state and ends with notes '
          'on keyboard, touch and screen readers.',
          style: text.muted.body,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = BentoGrid.columnsFor(constraints.maxWidth);
            final width = (constraints.maxWidth - 24 * (columns - 1)) / columns;
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final group in CatalogGroup.values)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 12,
                            bottom: 4,
                          ),
                          child: Semantics(
                            header: true,
                            child: Text(
                              group.title,
                              style: text.muted.caption,
                            ),
                          ),
                        ),
                        Wrap(
                          children: [
                            for (final entry in catalogEntries.where(
                              (e) => e.group == group,
                            ))
                              CoilButton(
                                variant: CoilButtonVariant.ghost,
                                size: CoilSize.compact,
                                onPressed: () => unawaited(
                                  openCatalogPage(router, entry),
                                ),
                                child: Text(entry.title),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
