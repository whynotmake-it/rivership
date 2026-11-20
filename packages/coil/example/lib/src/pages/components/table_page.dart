import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const tableEntry = CatalogEntry(
  slug: 'table',
  title: 'Table',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Rows to select or open, one tab stop with arrow keys.',
  page: TablePage.new,
);

typedef _Invoice = ({String id, String client, int amount});

const _invoices = <_Invoice>[
  (id: 'INV-031', client: 'Northwind', amount: 1200),
  (id: 'INV-032', client: 'Globex', amount: 860),
  (id: 'INV-033', client: 'Initech', amount: 2400),
];

class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  var _selected = <_Invoice>{};

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Table',
    summary: 'Selected rows merge into one block. Space selects, Enter opens.',
    children: [
      DemoSection(
        title: 'Invoices',
        child: CoilTable<_Invoice>(
          rows: _invoices,
          values: _selected,
          onChanged: (v) => setState(() => _selected = v),
          columns: [
            CoilTableColumn(
              label: const Text('Invoice'),
              cellBuilder: (context, row) => Text(row.id),
            ),
            CoilTableColumn(
              label: const Text('Client'),
              cellBuilder: (context, row) => Text(row.client),
            ),
            CoilTableColumn(
              label: const Text('Amount'),
              width: 112,
              alignment: AlignmentDirectional.centerEnd,
              cellBuilder: (context, row) => Text('€${row.amount}'),
            ),
          ],
        ),
      ),
    ],
  );
}
