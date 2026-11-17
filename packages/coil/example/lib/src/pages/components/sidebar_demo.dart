// The pieces the sidebar examples share: an AI workspace like FF's demos,
// with a workspace switcher, search, navigation, threads, callouts and the
// signed-in user.
import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

const workspaceNav = [
  ('Chat', Glyph.message),
  ('Agents', Glyph.bot),
  ('Knowledge', Glyph.book),
  ('Runs', Glyph.workflow),
  ('Evals', Glyph.flask),
];

const demoThreads = [
  'Sidebar API review',
  'Fix login redirect',
  'Quarterly roadmap',
  'Onboarding emails',
  'Pricing page copy',
];

/// A 20 tile with a letter, for workspaces.
class WorkspaceTile extends StatelessWidget {
  const WorkspaceTile(this.letter, {super.key});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final text = CoilTheme.textOf(context);
    return SizedBox.square(
      dimension: 20,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: theme.colors.brand,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Center(
          child: Text(
            letter,
            style: text.micro.copyWith(
              fontWeight: text.emphasis,
              color: const Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's brand row: the workspace switcher.
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context) => CoilDropdown(
    entries: [
      const CoilMenuLabel(Text('Workspaces')),
      CoilAction(
        label: const Text('Acme AI'),
        searchText: 'Acme AI',
        leading: const WorkspaceTile('A'),
        selected: true,
        mark: CoilActionMark.check,
        onPressed: () {},
      ),
      CoilAction(
        label: const Text('Side project'),
        searchText: 'Side project',
        leading: const WorkspaceTile('S'),
        onPressed: () {},
      ),
      const CoilMenuSeparator(),
      CoilAction(
        label: const Text('New workspace'),
        searchText: 'New workspace',
        leading: const CatalogIcon(Glyph.plus),
        onPressed: () {},
      ),
    ],
    builder: (context, menu) => CoilSidebarMenu(
      items: [
        CoilSidebarItem(
          label: const Text('Acme AI'),
          leading: const WorkspaceTile('A'),
          trailing: const CatalogIcon(Glyph.chevronsUpDown),
          onPressed: menu.open,
        ),
      ],
    ),
  );
}

/// The header's search field, with its shortcut.
class SidebarSearch extends StatelessWidget {
  const SidebarSearch({super.key});

  @override
  Widget build(BuildContext context) => CoilInput(
    size: CoilSize.compact,
    leading: const CatalogIcon(Glyph.search),
    placeholder: const Text('Search'),
    trailing: CoilKbd('⌘K'),
  );
}

/// The signed-in user, opening their menu.
class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) => CoilDropdown(
    entries: [
      CoilAction(
        label: const Text('Profile'),
        searchText: 'Profile',
        leading: const CatalogIcon(Glyph.user),
        onPressed: () {},
      ),
      CoilAction(
        label: const Text('Settings'),
        searchText: 'Settings',
        leading: const CatalogIcon(Glyph.settings),
        onPressed: () {},
      ),
      CoilAction(
        label: const Text('Log out'),
        searchText: 'Log out',
        leading: const CatalogIcon(Glyph.logOut),
        onPressed: () {},
      ),
    ],
    builder: (context, menu) => CoilSidebarMenu(
      items: [
        CoilSidebarItem(
          label: const Text('Ada Lovelace'),
          leading: const _Avatar(),
          trailing: const CatalogIcon(Glyph.chevronsUpDown),
          onPressed: menu.open,
        ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return SizedBox.square(
      dimension: 20,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.accent,
          shape: const CircleBorder(),
        ),
        child: Center(
          child: Text(
            'A',
            style: CoilTheme.textOf(context).micro.copyWith(
              fontSize: 10,
              height: 12 / 10,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// The product's top-level navigation under a collapsible label.
class WorkspaceGroup extends StatefulWidget {
  const WorkspaceGroup({super.key});

  @override
  State<WorkspaceGroup> createState() => _WorkspaceGroupState();
}

class _WorkspaceGroupState extends State<WorkspaceGroup> {
  var _current = 'Chat';
  var _open = true;

  @override
  Widget build(BuildContext context) => CoilSidebarGroup(
    label: const Text('Workspace'),
    expanded: _open,
    onExpandedChanged: (open) => setState(() => _open = open),
    child: CoilSidebarMenu(
      items: [
        for (final (label, glyph) in workspaceNav)
          CoilSidebarItem(
            label: Text(label),
            leading: CatalogIcon(glyph),
            selected: label == _current,
            onPressed: () => setState(() => _current = label),
          ),
      ],
    ),
  );
}

/// Recent threads: a status dot for each, a count of new messages, and up
/// to three actions that show on hover (always on touch).
class ThreadsGroup extends StatefulWidget {
  const ThreadsGroup({
    super.key,
    this.count = 5,
    this.rowActions = 0,
    this.groupActions = 1,
  });

  final int count;

  /// How many actions each row carries, 0 to 3.
  final int rowActions;

  /// How many actions the label row carries, 0 to 3.
  final int groupActions;

  @override
  State<ThreadsGroup> createState() => _ThreadsGroupState();
}

class _ThreadsGroupState extends State<ThreadsGroup> {
  var _current = demoThreads.first;
  var _open = true;

  static const _statuses = [
    CoilSidebarStatus.idle,
    CoilSidebarStatus.unread,
    CoilSidebarStatus.idle,
    CoilSidebarStatus.unread,
    CoilSidebarStatus.idle,
  ];

  List<CoilMenuEntry> _rowActions(String thread) => [
    CoilAction(
      label: const Text('Branch thread'),
      searchText: 'Branch thread',
      leading: const CatalogIcon(Glyph.branch),
      onPressed: () {},
    ),
    CoilAction(
      label: const Text('Share thread'),
      searchText: 'Share thread',
      leading: const CatalogIcon(Glyph.link),
      onPressed: () {},
    ),
    // The overflow menu stays rightmost at every count, like FF's.
    CoilSubmenu(
      label: const Text('More options'),
      searchText: 'More options',
      leading: const CatalogIcon(Glyph.more),
      entries: [
        CoilAction(
          label: const Text('Rename'),
          searchText: 'Rename',
          leading: const CatalogIcon(Glyph.pencil),
          onPressed: () {},
        ),
        CoilAction(
          label: const Text('Delete'),
          searchText: 'Delete',
          leading: const CatalogIcon(Glyph.trash),
          tone: CoilActionTone.destructive,
          onPressed: () {},
        ),
      ],
    ),
  ].sublist(3 - widget.rowActions);

  @override
  Widget build(BuildContext context) => CoilSidebarGroup(
    label: const Text('Threads'),
    expanded: _open,
    onExpandedChanged: (open) => setState(() => _open = open),
    actions: [
      CoilSidebarAction(
        icon: const CatalogIcon(Glyph.plus),
        semanticLabel: 'New thread',
        tooltip: const Text('New thread'),
        shortcut: CoilKbd('⇧⌘O'),
        onPressed: () {},
      ),
      CoilSidebarAction(
        icon: const CatalogIcon(Glyph.sliders),
        semanticLabel: 'Filter threads',
        tooltip: const Text('Filter'),
        onPressed: () {},
      ),
      CoilSidebarAction(
        icon: const CatalogIcon(Glyph.more),
        semanticLabel: 'Section options',
        tooltip: const Text('More options'),
        onPressed: () {},
      ),
    ].sublist(0, widget.groupActions),
    child: CoilSidebarMenu(
      items: [
        for (final (i, thread) in demoThreads.take(widget.count).indexed)
          CoilSidebarItem(
            label: Text(thread),
            status: thread == _current
                ? CoilSidebarStatus.active
                : _statuses[i],
            trailing: i.isOdd ? Text('${i + 1}') : null,
            actions: _rowActions(thread),
            onPressed: () => setState(() => _current = thread),
          ),
      ],
    ),
  );
}

/// The product's navigation two levels deep: each section opens its
/// pages, one starts open, and the current page is lit with its section.
class NestedGroup extends StatefulWidget {
  const NestedGroup({super.key});

  @override
  State<NestedGroup> createState() => _NestedGroupState();
}

class _NestedGroupState extends State<NestedGroup> {
  static const _pages = {
    'Chat': ['Recent', 'Starred', 'Archived'],
    'Agents': ['Research', 'Support', 'Release notes'],
    'Knowledge': ['Docs', 'Playbooks'],
    'Runs': ['Scheduled', 'History'],
  };
  static const _badges = {'Support': '3', 'Scheduled': '2'};

  final _open = {'Agents'};
  var _current = 'Research';

  @override
  Widget build(BuildContext context) => CoilSidebarGroup(
    label: const Text('Workspace'),
    child: CoilSidebarMenu(
      items: [
        for (final (label, glyph) in workspaceNav.take(4))
          CoilSidebarItem(
            label: Text(label),
            leading: CatalogIcon(glyph),
            expanded: _open.contains(label),
            onExpandedChanged: (open) => setState(
              () => open ? _open.add(label) : _open.remove(label),
            ),
            children: [
              for (final page in _pages[label]!)
                CoilSidebarItem(
                  label: Text(page),
                  selected: page == _current,
                  trailing: _badges[page] == null ? null : Text(_badges[page]!),
                  actions: [
                    CoilAction(
                      label: Text('New in $page'),
                      searchText: 'New in $page',
                      leading: const CatalogIcon(Glyph.plus),
                      onPressed: () {},
                    ),
                  ],
                  onPressed: () => setState(() => _current = page),
                ),
            ],
          ),
      ],
    ),
  );
}

/// The header most examples share: the switcher above search.
class DemoHeader extends StatelessWidget {
  const DemoHeader({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [WorkspaceSwitcher(), SidebarSearch()],
  );
}

/// The page beside the sidebar: a top bar with the trigger and a title.
class DemoPage extends StatelessWidget {
  const DemoPage({
    super.key,
    this.title = 'Chat',
    this.side = CoilSidebarSide.start,
  });

  final String title;
  final CoilSidebarSide side;

  @override
  Widget build(BuildContext context) {
    final trigger = CoilSidebarTrigger(
      icon: CatalogIcon(
        side == CoilSidebarSide.start ? Glyph.panelLeft : Glyph.panelRight,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            spacing: 8,
            children: [
              if (side == CoilSidebarSide.start) trigger,
              Expanded(
                child: Text(
                  title,
                  style: CoilTheme.textOf(context).muted.body,
                ),
              ),
              if (side == CoilSidebarSide.end) trigger,
            ],
          ),
        ),
      ],
    );
  }
}

/// The callouts the footer examples pile up.
List<Widget> demoCallouts({
  required bool banner,
  required void Function(String id) onDismissed,
}) => [
  for (final (id, title, line, glyph) in const [
    ('agents', 'Agents are here', 'Automate the busywork.', Glyph.sparkles),
    ('evals', 'Evals beta', 'Score every run.', Glyph.flask),
    ('docs', 'New docs', 'Guides for every part.', Glyph.book),
  ])
    CoilCard(
      key: ValueKey(id),
      variant: banner ? CoilCardVariant.stacked : CoilCardVariant.inline,
      size: CoilSize.compact,
      title: Text(title),
      description: Text(line),
      icon: banner ? null : CatalogIcon(glyph),
      media: banner ? const _BannerArt() : null,
      onPressed: () {},
      onDismissed: () => onDismissed(id),
    ),
];

class _BannerArt extends StatelessWidget {
  const _BannerArt();

  @override
  Widget build(BuildContext context) {
    final brand = CoilTheme.of(context).colors.brand;
    return AspectRatio(
      aspectRatio: 2.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brand, brand.withValues(alpha: 0.35)],
          ),
        ),
      ),
    );
  }
}

/// A phone layout with a sidebar on each side: workspace navigation on the
/// start side and threads on the end side. Two nested scaffolds; below
/// their breakpoint each one's sidebar becomes a drawer the page slides
/// aside to reveal. Drag the page sideways anywhere (the cards scroll
/// first and hand over at their ends), or press a trigger.
class PhoneSidebars extends StatelessWidget {
  const PhoneSidebars({super.key});

  @override
  Widget build(BuildContext context) => const CoilSidebarScaffold(
    autofocus: false,
    drawerLabel: 'Navigation',
    sidebar: CoilSidebar(
      header: DemoHeader(),
      footer: UserMenu(),
      children: [WorkspaceGroup()],
    ),
    body: CoilSidebarScaffold(
      autofocus: false,
      side: CoilSidebarSide.end,
      drawerLabel: 'Threads',
      sidebar: CoilSidebar(children: [ThreadsGroup(count: 4)]),
      body: _PhonePage(),
    ),
  );
}

class _PhonePage extends StatelessWidget {
  const _PhonePage();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            spacing: 8,
            children: [
              const CoilSidebarTrigger(
                side: CoilSidebarSide.start,
                icon: CatalogIcon(Glyph.panelLeft),
                openLabel: Text('Open navigation'),
                closeLabel: Text('Close navigation'),
              ),
              Expanded(
                child: Text(
                  'Chat',
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(fontWeight: text.emphasis),
                ),
              ),
              const CoilSidebarTrigger(
                side: CoilSidebarSide.end,
                icon: CatalogIcon(Glyph.panelRight),
                openLabel: Text('Open threads'),
                closeLabel: Text('Close threads'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Pinned', style: text.muted.caption),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => SizedBox(
              width: 160,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.muted,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      CoilTheme.radiiOf(context).container,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Text('Card ${i + 1}', style: text.body),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Drag the page sideways anywhere to reveal a sidebar. The '
              'cards scroll first and hand over at their ends.',
              style: text.muted.body,
            ),
          ),
        ),
      ],
    );
  }
}
