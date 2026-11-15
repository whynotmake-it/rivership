import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const dataTableEntry = CatalogEntry(
  slug: 'data-table',
  title: 'DataTable',
  group: CatalogGroup.shellAndComposites,
  summary: 'Search, sort, select and page, on a headless controller.',
  page: DataTablePage.new,
);

typedef _Member = ({String name, String role, int commits});

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<DataTablePage> createState() => _DataTablePageState();
}

class _DataTablePageState extends State<DataTablePage> {
  final _controller = CoilDataTableController<_Member>(
    pageSize: 5,
    matches: (m, query) => m.name.toLowerCase().contains(query),
    rows: [
      for (final (i, name) in const [
        'Ada', 'Alan', 'Barbara', 'Claude', 'Donald', 'Edsger', 'Frances', //
        'Grace', 'Hedy', 'John', 'Katherine', 'Linus',
      ].indexed)
        (
          name: name,
          role: i.isEven ? 'Engineer' : 'Designer',
          commits: (i * 37) % 200,
        ),
    ],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'DataTable',
    summary: 'The controller holds the state; the table only shows it.',
    children: [
      DemoSection(
        title: 'Team',
        child: CoilDataTable<_Member>(
          controller: _controller,
          columns: [
            CoilDataColumn(
              label: const Text('Name'),
              cellBuilder: (context, m) => Text(m.name),
              compare: (a, b) => a.name.compareTo(b.name),
            ),
            CoilDataColumn(
              label: const Text('Role'),
              cellBuilder: (context, m) => Text(m.role),
            ),
            CoilDataColumn(
              label: const Text('Commits'),
              width: 112,
              alignment: AlignmentDirectional.centerEnd,
              cellBuilder: (context, m) => Text('${m.commits}'),
              compare: (a, b) => a.commits.compareTo(b.commits),
            ),
          ],
        ),
      ),
    ],
  );
}
