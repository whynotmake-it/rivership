import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const dropdownEntry = CatalogEntry(
  slug: 'dropdown',
  title: 'Dropdown',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Action menus with headings, marks, submenus and search.',
  page: DropdownPage.new,
);

class DropdownPage extends StatefulWidget {
  const DropdownPage({super.key});

  @override
  State<DropdownPage> createState() => _DropdownPageState();
}

class _DropdownPageState extends State<DropdownPage> {
  var _grid = true;
  var _sort = 'Name';

  List<CoilMenuEntry> get _entries => [
    const CoilMenuLabel('View'),
    CoilAction(
      label: 'Show grid',
      mark: CoilActionMark.check,
      selected: _grid,
      onPressed: () => setState(() => _grid = !_grid),
    ),
    CoilSubmenu(
      label: 'Sort by',
      entries: [
        for (final key in ['Name', 'Date', 'Size'])
          CoilAction(
            label: key,
            mark: CoilActionMark.radio,
            selected: _sort == key,
            onPressed: () => setState(() => _sort = key),
          ),
      ],
    ),
    const CoilMenuSeparator(),
    CoilAction(label: 'Rename', shortcut: const Text('⌘R'), onPressed: () {}),
    CoilAction(
      label: 'Delete',
      tone: CoilActionTone.destructive,
      onPressed: () {},
    ),
  ];

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Dropdown',
    summary:
        'Hover a submenu row to open it; the pointer can cut across other '
        'rows on the way. On touch, submenus replace the rows.',
    children: [
      DemoSection(
        title: 'Menu',
        child: DemoWrap(
          children: [
            CoilDropdown(
              entries: _entries,
              builder: (context, menu) => CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: menu.open,
                child: const Text('Actions'),
              ),
            ),
            CoilDropdown(
              search: const CoilMenuSearch(hint: 'Filter actions'),
              entries: _entries,
              builder: (context, menu) => CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: menu.open,
                child: const Text('With search'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
