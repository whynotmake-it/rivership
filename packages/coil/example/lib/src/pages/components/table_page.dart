import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const tableEntry = CatalogEntry(
  slug: 'table',
  title: 'Table',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Rows you can select or open, with the keyboard or a tap.',
  page: TablePage.new,
);

enum _Status {
  paid('Paid', CoilBadgeColor.green),
  pending('Pending', CoilBadgeColor.amber),
  overdue('Overdue', CoilBadgeColor.red);

  const _Status(this.label, this.color);

  final String label;
  final CoilBadgeColor color;
}

typedef _Invoice = ({String client, int amount, _Status status});

const _invoices = <String, _Invoice>{
  'INV-031': (client: 'Northwind', amount: 1200, status: _Status.paid),
  'INV-032': (client: 'Globex', amount: 860, status: _Status.pending),
  'INV-033': (client: 'Initech', amount: 2400, status: _Status.overdue),
  'INV-034': (client: 'Umbrella', amount: 1750, status: _Status.pending),
  'INV-035': (client: 'Hooli', amount: 3200, status: _Status.paid),
  'INV-036': (client: 'Vandelay', amount: 640, status: _Status.overdue),
};

enum _SortKey { invoice, amount }

String _euros(int amount) {
  final digits = '$amount';
  final grouped = digits.length > 3
      ? '${digits.substring(0, digits.length - 3)},'
            '${digits.substring(digits.length - 3)}'
      : digits;
  return '€$grouped';
}

class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  var _statuses = {
    for (final entry in _invoices.entries) entry.key: entry.value.status,
  };
  var _selected = <String>{};
  var _sortKey = _SortKey.invoice;
  var _direction = CoilSortDirection.ascending;
  String _message = 'Tap a row, or select it and press Enter, to open it.';

  var _size = CoilSize.regular;
  var _selectable = true;
  var _empty = false;
  var _narrow = false;
  var _playgroundSelected = <String>{};

  List<String> get _rows {
    final ids = _invoices.keys.toList();
    int compare(String a, String b) => switch (_sortKey) {
      _SortKey.invoice => a.compareTo(b),
      _SortKey.amount => _invoices[a]!.amount.compareTo(_invoices[b]!.amount),
    };
    ids.sort(compare);
    return _direction == CoilSortDirection.ascending
        ? ids
        : ids.reversed.toList();
  }

  void _sortBy(_SortKey key) => setState(() {
    if (_sortKey == key) {
      _direction = _direction == CoilSortDirection.ascending
          ? CoilSortDirection.descending
          : CoilSortDirection.ascending;
    } else {
      _sortKey = key;
      _direction = CoilSortDirection.ascending;
    }
  });

  void _open(String id) {
    final invoice = _invoices[id]!;
    setState(() {
      _message =
          '$id, ${invoice.client}, ${_euros(invoice.amount)}, '
          '${_statuses[id]!.label.toLowerCase()}.';
    });
  }

  void _markPaid() => setState(() {
    final count = _selected.length;
    _statuses = {
      for (final entry in _statuses.entries)
        entry.key: _selected.contains(entry.key) ? _Status.paid : entry.value,
    };
    _selected = {};
    _message = 'Marked $count ${count == 1 ? 'invoice' : 'invoices'} as paid.';
  });

  void _remind() => setState(() {
    final clients = [
      for (final id in _rows)
        if (_selected.contains(id)) _invoices[id]!.client,
    ];
    _selected = {};
    _message = 'Reminder sent to ${clients.join(', ')}.';
  });

  List<CoilTableColumn<String>> _columns({
    required bool checkboxes,
    required bool sortable,
  }) => [
    if (checkboxes)
      CoilTableColumn(
        width: 56,
        semanticLabel: 'Select',
        label: ExcludeFocus(
          child: CoilCheckbox(
            size: CoilSize.compact,
            tristate: true,
            semanticLabel: 'Select all invoices',
            value: _selected.length == _invoices.length
                ? true
                : _selected.isEmpty
                ? false
                : null,
            onChanged: (_) => setState(
              () => _selected = _selected.length == _invoices.length
                  ? {}
                  : {..._invoices.keys},
            ),
          ),
        ),
        cellBuilder: (context, id) => ExcludeFocus(
          child: CoilCheckbox(
            size: CoilSize.compact,
            semanticLabel: 'Select $id',
            value: _selected.contains(id),
            onChanged: (checked) => setState(
              () => _selected = checked!
                  ? {..._selected, id}
                  : ({..._selected}..remove(id)),
            ),
          ),
        ),
      ),
    CoilTableColumn(
      label: const Text('Invoice'),
      width: 128,
      sort: sortable && _sortKey == _SortKey.invoice ? _direction : null,
      onSort: sortable ? () => _sortBy(_SortKey.invoice) : null,
      cellBuilder: (context, id) => Text(id),
    ),
    CoilTableColumn(
      label: const Text('Client'),
      minWidth: 128,
      cellBuilder: (context, id) => Text(_invoices[id]!.client),
    ),
    CoilTableColumn(
      label: const Text('Status'),
      width: 128,
      cellBuilder: (context, id) {
        final status = _statuses[id]!;
        return CoilBadge(
          variant: CoilBadgeVariant.dot,
          color: status.color,
          child: Text(status.label),
        );
      },
    ),
    CoilTableColumn(
      label: const Text('Amount'),
      width: 112,
      alignment: AlignmentDirectional.centerEnd,
      sort: sortable && _sortKey == _SortKey.amount ? _direction : null,
      onSort: sortable ? () => _sortBy(_SortKey.amount) : null,
      cellBuilder: (context, id) => Text(_euros(_invoices[id]!.amount)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final selected = _selected.length;
    return CatalogPage(
      title: 'Table',
      summary:
          'A table of rows you can select or open. It takes a single tab '
          'stop: use the arrow keys to move between rows, Space to select one '
          'and Enter to open it.',
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selected == 0
                      ? '${_invoices.length} invoices'
                      : '$selected selected',
                  style: text.subtitle.copyWith(fontWeight: text.emphasis),
                ),
              ),
              CoilButton(
                variant: CoilButtonVariant.secondary,
                size: CoilSize.compact,
                onPressed: selected == 0 ? null : _remind,
                child: const Text('Remind'),
              ),
              SizedBox(width: CoilTheme.metricsOf(context).buttonGap),
              CoilButton(
                size: CoilSize.compact,
                onPressed: selected == 0 ? null : _markPaid,
                child: const Text('Mark paid'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CoilTable<String>(
            semanticLabel: 'Invoices',
            rows: _rows,
            values: _selected,
            onChanged: (v) => setState(() => _selected = v),
            onRowActivated: _open,
            columns: _columns(checkboxes: true, sortable: true),
          ),
          const SizedBox(height: 12),
          Text(_message, style: text.muted.caption),
        ],
      ),
      usage: '''
CoilTable<String>(
  rows: invoiceIds,
  values: selected,
  onChanged: (ids) => setState(() => selected = ids),
  onRowActivated: openInvoice,
  columns: [
    CoilTableColumn(
      label: Text('Invoice'),
      cellBuilder: (context, id) => Text(id),
    ),
    CoilTableColumn(
      label: Text('Amount'),
      alignment: AlignmentDirectional.centerEnd,
      cellBuilder: (context, id) => Text(amountOf(id)),
    ),
  ],
)''',
      notes: const [
        CatalogNote(
          'Keyboard',
          'Tab reaches the table once. From there the up and down arrows move '
              'the active row, Space selects it and Enter opens it, while '
              'Left and Right scroll a table that is wider than its box.',
        ),
        CatalogNote(
          'Touch',
          'When you pass onRowActivated a tap opens the row, so selection '
              'needs its own checkbox column. Without it, a tap toggles '
              'selection.',
        ),
        CatalogNote(
          'Pointer',
          'The row highlight glides quickly between rows, and adjacent '
              'selected rows merge smoothly into one block.',
        ),
        CatalogNote(
          'Accessibility',
          'Rows and cells carry table semantics along with their column '
              'headers, a sorted header announces its direction, and the '
              'values you pass as rows have to be distinct.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          description:
              'Columns that do not fit scroll sideways, and the edges fade '
              'wherever there is more to see.',
          controls: DemoControls(
            children: [
              DemoControl.choice(
                label: 'Size',
                value: _size,
                values: const [CoilSize.regular, CoilSize.compact],
                labelOf: (v) => v == CoilSize.regular ? 'Regular' : 'Compact',
                onChanged: (v) => setState(() => _size = v),
              ),
              DemoControl.toggle(
                label: 'Selectable',
                value: _selectable,
                onChanged: (v) => setState(() {
                  _selectable = v;
                  _playgroundSelected = {};
                }),
              ),
              DemoControl.toggle(
                label: 'Empty',
                value: _empty,
                onChanged: (v) => setState(() => _empty = v),
              ),
              DemoControl.toggle(
                label: 'Narrow',
                value: _narrow,
                onChanged: (v) => setState(() => _narrow = v),
              ),
            ],
          ),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: _narrow ? 300 : double.infinity,
              child: CoilTable<String>(
                semanticLabel: 'Invoices',
                size: _size,
                rows: _empty ? const [] : _invoices.keys.take(4).toList(),
                values: _playgroundSelected,
                onChanged: _selectable
                    ? (v) => setState(() => _playgroundSelected = v)
                    : null,
                empty: const Text('No invoices yet'),
                columns: _columns(checkboxes: false, sortable: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
