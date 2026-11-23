import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const dataTableEntry = CatalogEntry(
  slug: 'data-table',
  title: 'DataTable',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A table whose search, sorting, selection and paging all live in a '
      'headless controller.',
  page: DataTablePage.new,
);

enum _Status {
  active('Active', CoilBadgeColor.green),
  invited('Invited', CoilBadgeColor.amber),
  suspended('Suspended', CoilBadgeColor.gray);

  const _Status(this.label, this.color);

  final String label;
  final CoilBadgeColor color;
}

typedef _Member = ({String name, String role, _Status status, String seen});

const _members = <_Member>[
  (name: 'Ada Lovelace', role: 'Owner', status: _Status.active, seen: 'Today'),
  (name: 'Alan Turing', role: 'Admin', status: _Status.active, seen: 'Today'),
  (
    name: 'Barbara Liskov',
    role: 'Admin',
    status: _Status.active,
    seen: 'Yesterday',
  ),
  (
    name: 'Claude Shannon',
    role: 'Member',
    status: _Status.active,
    seen: 'Nov 18',
  ),
  (
    name: 'Donald Knuth',
    role: 'Member',
    status: _Status.invited,
    seen: 'Never',
  ),
  (
    name: 'Edsger Dijkstra',
    role: 'Member',
    status: _Status.suspended,
    seen: 'Oct 2',
  ),
  (
    name: 'Frances Allen',
    role: 'Member',
    status: _Status.active,
    seen: 'Nov 20',
  ),
  (name: 'Grace Hopper', role: 'Admin', status: _Status.active, seen: 'Today'),
  (
    name: 'Hedy Lamarr',
    role: 'Viewer',
    status: _Status.invited,
    seen: 'Never',
  ),
  (
    name: 'John McCarthy',
    role: 'Member',
    status: _Status.active,
    seen: 'Nov 12',
  ),
  (
    name: 'Katherine Johnson',
    role: 'Viewer',
    status: _Status.active,
    seen: 'Nov 19',
  ),
  (
    name: 'Linus Torvalds',
    role: 'Member',
    status: _Status.active,
    seen: 'Nov 9',
  ),
];

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<DataTablePage> createState() => _DataTablePageState();
}

class _DataTablePageState extends State<DataTablePage> {
  final _controller = CoilDataTableController<_Member>(
    pageSize: 6,
    matches: (m, query) =>
        m.name.toLowerCase().contains(query) ||
        m.role.toLowerCase().contains(query),
    rows: _members,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replace(_Member member, _Member? next) => _controller.rows = [
    for (final m in _controller.rows)
      if (m != member) m else if (next != null) next,
  ];

  Widget _actions(BuildContext context, _Member member) => CoilDropdown(
    entries: [
      CoilAction(
        label: Text(
          member.status == _Status.suspended ? 'Reactivate' : 'Suspend',
        ),
        searchText: 'Suspend Reactivate',
        leading: const CatalogIcon(Glyph.lock),
        onPressed: () => _replace(member, (
          name: member.name,
          role: member.role,
          status: member.status == _Status.suspended
              ? _Status.active
              : _Status.suspended,
          seen: member.seen,
        )),
      ),
      CoilAction(
        label: const Text('Remove'),
        searchText: 'Remove',
        leading: const CatalogIcon(Glyph.trash),
        tone: CoilActionTone.destructive,
        onPressed: () => _replace(member, null),
      ),
    ],
    builder: (context, menu) => CoilButton.icon(
      variant: CoilButtonVariant.ghost,
      size: CoilSize.compact,
      semanticLabel: 'Actions for ${member.name}',
      icon: const CatalogIcon(Glyph.more),
      onPressed: menu.open,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final table = CoilDataTable<_Member>(
      controller: _controller,
      semanticLabel: 'Team',
      empty: const Text('No one matches that search.'),
      columns: [
        CoilDataColumn(
          label: const Text('Name'),
          minWidth: 140,
          cellBuilder: (context, m) => Text(m.name),
          compare: (a, b) => a.name.compareTo(b.name),
        ),
        CoilDataColumn(
          label: const Text('Role'),
          width: 88,
          cellBuilder: (context, m) => Text(m.role),
          compare: (a, b) => a.role.compareTo(b.role),
        ),
        CoilDataColumn(
          label: const Text('Status'),
          width: 132,
          cellBuilder: (context, m) => CoilBadge(
            variant: CoilBadgeVariant.dot,
            color: m.status.color,
            child: Text(m.status.label),
          ),
          compare: (a, b) => a.status.index.compareTo(b.status.index),
        ),
        CoilDataColumn(
          label: const Text('Last seen'),
          width: 96,
          cellBuilder: (context, m) => Text(m.seen),
        ),
        CoilDataColumn(
          label: const Text(''),
          semanticLabel: 'Actions',
          width: 56,
          alignment: AlignmentDirectional.centerEnd,
          cellBuilder: _actions,
        ),
      ],
    );
    return CatalogPage(
      title: 'DataTable',
      summary:
          'The controller keeps the search, the sort, the selection and the '
          'current page, and the table simply shows whatever it holds. Try '
          'searching for “admin” to see it narrow down.',
      hero: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 560
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: 560, child: table),
              ),
      ),
      usage: '''
final controller = CoilDataTableController<Member>(
  pageSize: 6,
  rows: members,
  matches: (m, query) => m.name.toLowerCase().contains(query),
);

CoilDataTable<Member>(
  controller: controller,
  columns: [
    CoilDataColumn(
      label: const Text('Name'),
      cellBuilder: (context, m) => Text(m.name),
      compare: (a, b) => a.name.compareTo(b.name),
    ),
  ],
)''',
      notes: const [
        CatalogNote(
          'Keyboard',
          'The arrow keys move the active row, Space selects it and Shift '
              'extends the selection. Enter opens a row, Ctrl or ⌘ with A '
              'selects every row, Escape clears the selection and Shift+F10 '
              'opens the row’s actions.',
        ),
        CatalogNote(
          'Touch',
          'Rows are 44 tall, and a row’s actions open from its ⋯ button or a '
              'long press. Once something is selected, an action bar appears '
              'above the safe area.',
        ),
        CatalogNote(
          'Pointer',
          'Search starts as an icon and springs open into a 224 wide field. '
              'Each header has a menu that sorts ascending or descending, and '
              'the highlight glides to the row under the pointer.',
        ),
        CatalogNote(
          'Accessibility',
          'The table, its headers, rows and cells all carry table semantics, '
              'so a header announces the direction it is sorted in and a '
              'picked row is announced as selected.',
        ),
      ],
      children: const [],
    );
  }
}
