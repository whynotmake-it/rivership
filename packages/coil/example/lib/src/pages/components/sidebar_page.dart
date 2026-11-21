import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/sidebar_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const sidebarEntry = CatalogEntry(
  slug: 'sidebar',
  title: 'Sidebar',
  group: CatalogGroup.shellAndComposites,
  summary:
      'Resizes, folds away and peeks back; on phones, the page slides aside '
      'to reveal it.',
  page: SidebarPage.new,
);

class SidebarPage extends StatefulWidget {
  const SidebarPage({super.key});

  @override
  State<SidebarPage> createState() => _SidebarPageState();
}

String _variantName(CoilSidebarVariant variant) => switch (variant) {
  CoilSidebarVariant.sidebar => 'Sidebar',
  CoilSidebarVariant.floating => 'Floating',
  CoilSidebarVariant.inset => 'Inset',
};

String _peekName(CoilSidebarPeek peek) => switch (peek) {
  CoilSidebarPeek.none => 'None',
  CoilSidebarPeek.hover => 'Hover',
  CoilSidebarPeek.click => 'Click',
};

class _SidebarPageState extends State<SidebarPage> {
  var _bar = _Bar.horizontal;
  var _callouts = _Callout.inline;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Sidebar',
    summary:
        'Drag its edge to resize, press [ to fold it and rest the pointer on '
        'the edge to peek. On a phone the page slides aside to reveal it '
        'from behind.',
    hero: const _Shell(),
    usage: '''
CoilSidebarScaffold(
  variant: CoilSidebarVariant.inset,
  peek: CoilSidebarPeek.hover,
  sidebar: CoilSidebar(
    header: const WorkspaceSwitcher(),
    footer: const UserMenu(),
    children: [
      CoilSidebarGroup(
        label: const Text('Workspace'),
        child: CoilSidebarMenu(
          items: [
            CoilSidebarItem(
              label: const Text('Chat'),
              leading: const Icon(LucideIcons.messageSquare),
              selected: section == 'Chat',
              onPressed: () => setState(() => section = 'Chat'),
            ),
          ],
        ),
      ),
    ],
  ),
  body: Page(section: section),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        '[ folds the sidebar, ] when it sits on the right; ⌘B or Ctrl+B '
            'too, never while typing in a field. Arrows roam the rows, Right '
            'and Left open and close sub-trees.',
      ),
      CatalogNote(
        'Pointer',
        'Drag the rail to resize between 160 and 360; 56 past the minimum '
            'folds it. There is no icon-only rail on purpose: peek brings the '
            'real sidebar back instead.',
      ),
      CatalogNote(
        'Touch',
        'Below 768 the sidebar is a drawer. On touch the page slides aside '
            'to reveal it from behind; drag the page sideways anywhere. A row '
            'shows only its last action, and a long press opens them all.',
      ),
      CatalogNote(
        'Accessibility',
        'A labeled sidebar is a navigation landmark and the active row is '
            'selected. While the drawer is open the page is hidden from '
            'screen readers except for its dismiss action.',
      ),
    ],
    children: [
      const DemoSection(
        title: 'Navigation depth',
        description:
            'A section opens its pages, and the current page is lit beside '
            'its section.',
        padding: 0,
        child: _Frame(
          child: _RailOnly(
            sidebar: CoilSidebar(
              header: DemoHeader(),
              children: [NestedGroup()],
            ),
          ),
        ),
      ),
      const DemoSection(
        title: 'Actions and badges',
        description:
            'Up to three actions per row show on hover, only the last on '
            'touch; the badge keeps the last slot. The section label has its '
            'own.',
        padding: 0,
        child: _Frame(
          child: _RailOnly(
            sidebar: CoilSidebar(
              header: DemoHeader(),
              children: [ThreadsGroup(rowActions: 3, groupActions: 3)],
            ),
          ),
        ),
      ),
      DemoSection(
        title: 'Header and footer',
        description:
            'Stacked, every part gets its own row and actions are menu rows. '
            'Horizontal packs them into 24 icon buttons.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Parts',
              value: _bar,
              values: _Bar.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _bar = v),
            ),
          ],
        ),
        padding: 0,
        child: _Frame(
          child: _HeaderFooter(vertical: _bar == _Bar.vertical),
        ),
      ),
      DemoSection(
        title: 'Callouts',
        description:
            'Hover fans an inline pile out into a list; dismissing one '
            'brings the next. Banners never fan.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Style',
              value: _callouts,
              values: _Callout.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _callouts = v),
            ),
          ],
        ),
        padding: 0,
        child: _Frame(
          child: _Callouts(
            key: ValueKey(_callouts),
            banner: _callouts == _Callout.banner,
          ),
        ),
      ),
      const DemoSection(
        title: 'Both sides on a phone',
        description:
            'Two nested scaffolds, one sidebar per side. Drag the page '
            'sideways anywhere: the cards scroll first and hand over at '
            'their ends.',
        child: _PhoneFrame(),
      ),
    ],
  );
}

enum _Bar {
  horizontal('Horizontal'),
  vertical('Stacked');

  const _Bar(this.label);

  final String label;
}

enum _Callout {
  inline('Inline'),
  banner('Banner');

  const _Callout(this.label);

  final String label;
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
        height: 480,
        child: ColoredBox(color: colors.background, child: child),
      ),
    );
  }
}

/// A phone-sized frame on the touch tier, centered on the stage.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(44),
          child: SizedBox(
            width: 375,
            height: 680,
            child: ColoredBox(
              color: colors.background,
              child: const CoilAdaptiveScope(
                tier: CoilTier.touch,
                child: PhoneSidebars(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero: an app shell with the sidebar's options in a playground above
/// it, and a page that shows the section picked in the navigation.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _controller = CoilSidebarController();
  var _variant = CoilSidebarVariant.inset;
  var _side = CoilSidebarSide.start;
  var _peek = CoilSidebarPeek.hover;
  var _folds = true;
  var _section = 'Chat';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoControls(
        children: [
          DemoControl.choice(
            label: 'Variant',
            value: _variant,
            values: CoilSidebarVariant.values,
            labelOf: _variantName,
            onChanged: (v) => setState(() => _variant = v),
          ),
          DemoControl.choice(
            label: 'Side',
            value: _side,
            values: CoilSidebarSide.values,
            labelOf: (v) => v == CoilSidebarSide.start ? 'Start' : 'End',
            onChanged: (v) => setState(() => _side = v),
          ),
          DemoControl.choice(
            label: 'Peek',
            value: _peek,
            values: CoilSidebarPeek.values,
            labelOf: _peekName,
            onChanged: (v) => setState(() => _peek = v),
          ),
          DemoControl.toggle(
            label: 'Folds',
            value: _folds,
            onChanged: (v) => setState(() => _folds = v),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Frame(
        child: CoilSidebarScaffold(
          autofocus: false,
          controller: _controller,
          variant: _variant,
          side: _side,
          peek: _peek,
          collapsible: _folds
              ? CoilSidebarCollapsible.offcanvas
              : CoilSidebarCollapsible.none,
          // The frame shares the page with the catalog, so the drawer
          // starts where it gets too narrow for a column and a page.
          drawerBreakpoint: 560,
          sidebar: CoilSidebar(
            header: const DemoHeader(),
            footer: const UserMenu(),
            children: [
              WorkspaceGroup(
                onChanged: (section) => setState(() => _section = section),
              ),
              const ThreadsGroup(count: 3),
            ],
          ),
          body: WorkspacePage(
            section: _section,
            side: _side,
            showTrigger: _folds,
          ),
        ),
      ),
    ],
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
        autofocus: false,
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
                      label: const Text('New thread'),
                      leading: const CatalogIcon(Glyph.newThread),
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
                  tooltip: const Text('Search'),
                  shortcut: CoilKbd('⌘K'),
                  onPressed: () {},
                ),
                CoilSidebarAction(
                  icon: const CatalogIcon(Glyph.newThread),
                  semanticLabel: 'New thread',
                  tooltip: const Text('New thread'),
                  shortcut: CoilKbd('⇧⌘O'),
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
                      label: const Text('Settings'),
                      leading: const CatalogIcon(Glyph.settings),
                      onPressed: () {},
                    ),
                    CoilSidebarItem(
                      label: const Text("What's new"),
                      leading: const CatalogIcon(Glyph.lightbulb),
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
                  tooltip: const Text('Settings'),
                  onPressed: () {},
                ),
              ],
            ),
      children: const [ThreadsGroup(count: 3)],
    ),
  );
}

class _Callouts extends StatefulWidget {
  const _Callouts({required this.banner, super.key});

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
