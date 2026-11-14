import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/settings_dialog_page.dart';
import 'package:coil_example/src/pages/components/sidebar_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const sidebarEntry = CatalogEntry(
  slug: 'sidebar',
  title: 'Sidebar',
  group: CatalogGroup.shellAndComposites,
  summary: 'Resizes, folds away and peeks back; a drawer on phones.',
  page: SidebarPage.new,
);

class SidebarPage extends StatelessWidget {
  const SidebarPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'Sidebar',
    summary:
        'Drag its edge to resize, click the edge or press [ to fold it, and '
        'on a phone it becomes a drawer.',
    children: [
      _Section(
        title: 'Sidebar',
        description: 'The default: a flush column with a hairline.',
        child: _Frame(child: _Shell(variant: CoilSidebarVariant.sidebar)),
      ),
      _Section(
        title: 'Floating',
        description: 'A raised card, one surface above the page.',
        child: _Frame(child: _Shell(variant: CoilSidebarVariant.floating)),
      ),
      _Section(
        title: 'Inset',
        description: 'The page becomes the card, so the content stands out.',
        child: _Frame(child: _Shell(variant: CoilSidebarVariant.inset)),
      ),
      _Section(
        title: 'On the right',
        description: 'The rail, the drawer and the shortcut ] follow it.',
        child: _Frame(
          child: _Shell(
            variant: CoilSidebarVariant.inset,
            side: CoilSidebarSide.end,
          ),
        ),
      ),
      _Section(
        title: 'Header and footer, vertical',
        description: 'Every part on its own row; actions are menu rows.',
        child: _Frame(child: _HeaderFooter(vertical: true)),
      ),
      _Section(
        title: 'Header and footer, horizontal',
        description: 'The same parts packed into 24 icon buttons.',
        child: _Frame(child: _HeaderFooter(vertical: false)),
      ),
      _Section(
        title: 'Stacked inline callouts',
        description: 'Hover fans the pile out; dismissing one brings the next.',
        child: _Frame(child: _Callouts(banner: false)),
      ),
      _Section(
        title: 'Stacked banners',
        child: _Frame(child: _Callouts(banner: true)),
      ),
      _Section(
        title: 'Peek on hover',
        description:
            'Fold it, then rest the pointer on the left edge or the trigger.',
        child: _Frame(child: _Peek(peek: CoilSidebarPeek.hover, open: true)),
      ),
      _Section(
        title: 'Peek on click',
        description:
            'Press the left edge; Escape or a press elsewhere hides it.',
        child: _Frame(child: _Peek(peek: CoilSidebarPeek.click, open: false)),
      ),
      DemoSection(
        title: 'Inside a dialog',
        description:
            'A sidebar that never folds, as the settings dialog uses it.',
        child: _OpenSettings(),
      ),
    ],
  );
}

/// A titled example on a full-bleed stage, so the shell meets its edges.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.description});

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: RoleText(
            title,
            role: TypeRole.subtitle,
            weight: CoilWeight.semibold,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          RoleText(description, role: TypeRole.caption, muted: true),
        ],
        const SizedBox(height: 12),
        DemoStage(padding: 0, child: child),
      ],
    );
  }
}

/// A bounded frame for one shell.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(CoilTheme.radiiOf(context).container),
      child: SizedBox(
        height: 520,
        child: ColoredBox(color: colors.background, child: child),
      ),
    );
  }
}

/// The app shell: header, navigation and user beside a page.
class _Shell extends StatelessWidget {
  const _Shell({required this.variant, this.side = CoilSidebarSide.start});

  final CoilSidebarVariant variant;
  final CoilSidebarSide side;

  @override
  Widget build(BuildContext context) => CoilSidebarScaffold(
    variant: variant,
    side: side,
    // The examples share the page with the catalog, so drawers start
    // where the frame gets too narrow for a column and a page.
    drawerBreakpoint: 560,
    sidebar: const CoilSidebar(
      header: DemoHeader(),
      footer: UserMenu(),
      children: [WorkspaceGroup()],
    ),
    body: DemoPage(side: side),
  );
}

/// A sidebar that is the subject on its own: beside a page when there is
/// room, alone in the frame when there isn't.
class _RailOnly extends StatelessWidget {
  const _RailOnly({required this.sidebar});

  final Widget sidebar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) return sidebar;
      return CoilSidebarScaffold(
        collapsible: CoilSidebarCollapsible.none,
        sidebar: sidebar,
        body: const SizedBox.expand(),
      );
    },
  );
}

class _HeaderFooter extends StatelessWidget {
  const _HeaderFooter({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) => _RailOnly(
    sidebar: CoilSidebar(
      header: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                const WorkspaceSwitcher(),
                const SidebarSearch(),
                CoilSidebarMenu(
                  items: [
                    CoilSidebarItem(
                      label: 'New thread',
                      icon: const CatalogIcon(Glyph.newThread),
                      trailing: CoilKbd('⇧⌘O'),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            )
          : CoilSidebarBar(
              primary: const WorkspaceSwitcher(),
              actions: [
                CoilSidebarAction(
                  icon: const CatalogIcon(Glyph.search),
                  semanticLabel: 'Search',
                  tooltip: 'Search',
                  shortcut: '⌘K',
                  onPressed: () {},
                ),
                CoilSidebarAction(
                  icon: const CatalogIcon(Glyph.newThread),
                  semanticLabel: 'New thread',
                  tooltip: 'New thread',
                  shortcut: '⇧⌘O',
                  onPressed: () {},
                ),
              ],
            ),
      footer: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                CoilSidebarMenu(
                  items: [
                    CoilSidebarItem(
                      label: 'Settings',
                      icon: const CatalogIcon(Glyph.settings),
                      onPressed: () {},
                    ),
                    CoilSidebarItem(
                      label: "What's new",
                      icon: const CatalogIcon(Glyph.lightbulb),
                      onPressed: () {},
                    ),
                  ],
                ),
                const UserMenu(),
              ],
            )
          : CoilSidebarBar(
              primary: const UserMenu(),
              actions: [
                CoilSidebarAction(
                  icon: const CatalogIcon(Glyph.settings),
                  semanticLabel: 'Settings',
                  tooltip: 'Settings',
                  onPressed: () {},
                ),
              ],
            ),
      children: const [ThreadsGroup(count: 3)],
    ),
  );
}

class _Callouts extends StatefulWidget {
  const _Callouts({required this.banner});

  final bool banner;

  @override
  State<_Callouts> createState() => _CalloutsState();
}

class _CalloutsState extends State<_Callouts> {
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final cards = demoCallouts(
      banner: widget.banner,
      onDismissed: (id) => setState(() => _dismissed.add(id)),
    ).where((card) => !_dismissed.contains((card.key! as ValueKey).value));
    return _RailOnly(
      sidebar: CoilSidebar(
        header: const DemoHeader(),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            if (cards.isEmpty)
              CoilButton(
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                onPressed: () => setState(_dismissed.clear),
                child: const Text('Bring them back'),
              )
            else
              CoilSidebarCalloutStack(
                expand: widget.banner
                    ? CoilSidebarCalloutExpand.never
                    : CoilSidebarCalloutExpand.onHover,
                children: cards.toList(),
              ),
            const UserMenu(),
          ],
        ),
        children: const [ThreadsGroup(count: 3)],
      ),
    );
  }
}

class _Peek extends StatefulWidget {
  const _Peek({required this.peek, required this.open});

  final CoilSidebarPeek peek;
  final bool open;

  @override
  State<_Peek> createState() => _PeekState();
}

class _PeekState extends State<_Peek> {
  late final _controller = CoilSidebarController(open: widget.open);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoilSidebarScaffold(
    controller: _controller,
    variant: CoilSidebarVariant.inset,
    peek: widget.peek,
    drawerBreakpoint: 560,
    sidebar: const CoilSidebar(
      header: DemoHeader(),
      children: [ThreadsGroup()],
    ),
    body: const DemoPage(title: 'Threads'),
  );
}

class _OpenSettings extends StatelessWidget {
  const _OpenSettings();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: CoilButton(
      variant: CoilButtonVariant.secondary,
      leading: const CatalogIcon(Glyph.settings),
      onPressed: () => showDemoSettings(context),
      child: const Text('Open settings'),
    ),
  );
}
