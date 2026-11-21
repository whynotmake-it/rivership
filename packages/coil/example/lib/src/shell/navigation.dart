import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// Shows [entry]'s page in the catalog's [router], or the home page when
/// [entry] is null.
///
/// Pages don't stack: the sidebar is how to move around, so the page takes
/// the place of whatever was shown and there is no Back to a previous one.
Future<void> openCatalogPage(StackRouter router, CatalogEntry? entry) async {
  final name = entry == null ? catalogHomeRouteName : catalogRouteName(entry);
  final stack = router.stackData;
  if (stack.length == 1 && stack.single.name == name) return;
  await router.replaceAll([NamedRoute(name)]);
}

/// The catalog page [router] shows, or null on the home page (or any page
/// the registry doesn't list).
CatalogEntry? currentCatalogEntry(StackRouter router) {
  final stack = router.stackData;
  // A routed dialog sits on its page; the page is the one in the sidebar.
  for (final data in stack.reversed) {
    for (final entry in catalogEntries) {
      if (data.name == catalogRouteName(entry)) return entry;
    }
  }
  return null;
}

/// Opens the command menu over every catalog page: type to jump.
Future<void> showCatalogSearch(BuildContext context, StackRouter router) =>
    showCoilCommandMenu(
      context: context,
      placeholder: const Text('Search components…'),
      semanticLabel: 'Search components',
      empty: const Text('No component by that name'),
      entries: [
        CoilAction(
          label: const Text('Home'),
          searchText: 'Home',
          leading: const CatalogIcon(Glyph.home),
          onPressed: () => unawaited(openCatalogPage(router, null)),
        ),
        for (final group in CatalogGroup.values) ...[
          CoilMenuLabel(Text(group.title)),
          for (final entry in catalogEntries.where((e) => e.group == group))
            CoilAction(
              label: Text(entry.title),
              // The summary too, so "loading" finds Button and "range"
              // finds Slider.
              searchText: '${entry.title} ${entry.summary}',
              onPressed: () => unawaited(openCatalogPage(router, entry)),
            ),
        ],
      ],
    );

class _SearchIntent extends Intent {
  const _SearchIntent();
}

/// The catalog's navigation: coil's own sidebar scaffold, a sidebar on a
/// wide pane and the phone drawer revealed from behind the page on a
/// narrow one. Lists home and every page by group, highlights the one on
/// screen, and opens search with ⌘K or Ctrl+K.
class CatalogNavigation extends StatefulWidget {
  const CatalogNavigation({
    required this.router,
    required this.child,
    super.key,
  });

  /// The catalog's router, whose pages [child] shows.
  final StackRouter router;

  /// The page.
  final Widget child;

  @override
  State<CatalogNavigation> createState() => _CatalogNavigationState();
}

class _CatalogNavigationState extends State<CatalogNavigation> {
  final _sidebar = CoilSidebarController(width: 248);
  final _expanded = {for (final group in CatalogGroup.values) group: true};

  @override
  void dispose() {
    _sidebar.dispose();
    super.dispose();
  }

  void _open(CatalogEntry? entry) =>
      unawaited(openCatalogPage(widget.router, entry));

  @override
  Widget build(BuildContext context) {
    final apple = switch (CoilTheme.platformOf(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return Shortcuts(
      shortcuts: {
        CharacterActivator('k', meta: apple, control: !apple):
            const _SearchIntent(),
      },
      child: Actions(
        actions: {
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) => showCatalogSearch(context, widget.router),
          ),
        },
        child: ListenableBuilder(
          listenable: widget.router,
          builder: (context, _) => CoilSidebarScaffold(
            controller: _sidebar,
            sidebar: _sidebarFor(context),
            body: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _sidebarFor(BuildContext context) {
    final current = currentCatalogEntry(widget.router);
    final onHome =
        current == null &&
        widget.router.stackData.lastOrNull?.name == catalogHomeRouteName;
    final apple = switch (CoilTheme.platformOf(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    return CoilSidebar(
      semanticLabel: 'Catalog',
      header: CoilSidebarMenu(
        items: [
          // Mounted in another app, the drawer leads with the way back to
          // it; on a wide pane the top bar's wordmark is that link.
          if (CatalogHome.of(context) case final onHome?
              when !CatalogChrome.hasTopBarOf(context))
            CoilSidebarItem(
              label: const Text('coil'),
              semanticLabel: CatalogHomeLink.label,
              leading: CoilMark(size: CoilTheme.metricsOf(context).iconSize),
              trailing: const CatalogIcon(Glyph.arrowUpRight),
              onPressed: onHome,
            ),
          CoilSidebarItem(
            label: const Text('Search'),
            leading: const CatalogIcon(Glyph.search),
            // No keys to show on a phone.
            trailing: touch ? null : CoilKbd(apple ? '⌘K' : 'Ctrl K'),
            onPressed: () =>
                unawaited(showCatalogSearch(context, widget.router)),
          ),
          CoilSidebarItem(
            label: const Text('Home'),
            leading: const CatalogIcon(Glyph.home),
            selected: onHome,
            onPressed: () => _open(null),
          ),
        ],
      ),
      children: [
        for (final group in CatalogGroup.values)
          CoilSidebarGroup(
            label: Text(group.title),
            expanded: _expanded[group]!,
            onExpandedChanged: (open) =>
                setState(() => _expanded[group] = open),
            child: CoilSidebarMenu(
              items: [
                for (final entry in catalogEntries.where(
                  (e) => e.group == group,
                ))
                  CoilSidebarItem(
                    label: Text(entry.title),
                    selected: entry == current,
                    onPressed: () => _open(entry),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
