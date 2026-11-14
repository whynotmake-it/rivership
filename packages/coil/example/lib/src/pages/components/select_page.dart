import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

const selectEntry = CatalogEntry(
  slug: 'select',
  title: 'Select',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Select and MultiSelect: a popover, or a sheet on phones.',
  page: SelectPage.new,
);

const _countries = [
  'Australia',
  'Brazil',
  'Canada',
  'Denmark',
  'Egypt',
  'Finland',
  'Germany',
  'Hungary',
  'India',
  'Japan',
  'Kenya',
  'Mexico',
];

class SelectPage extends StatefulWidget {
  const SelectPage({super.key});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  String? _role = 'editor';
  String? _country;
  var _labels = {'bug'};
  var _sheetPick = 'week';
  var _popoverPick = 'week';
  String? _visibility;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Select',
    summary:
        'On a touch phone, short single-choice lists stay anchored; long, '
        'searchable or multi-select lists open as a sheet. Type to jump to '
        'a row with a keyboard.',
    children: [
      DemoSection(
        title: 'Short list',
        description: 'Up to 8 rows: an anchored popover everywhere.',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Role'),
              description: const Text(
                'Editors can change content, not billing.',
              ),
              child: CoilSelect<String>(
                value: _role,
                onChanged: (value) => setState(() => _role = value),
                icon: const CatalogIcon(Glyph.user),
                options: const [
                  CoilOption(
                    value: 'viewer',
                    label: Text('Viewer'),
                    searchText: 'Viewer',
                  ),
                  CoilOption(
                    value: 'editor',
                    label: Text('Editor'),
                    searchText: 'Editor',
                  ),
                  CoilOption(
                    value: 'admin',
                    label: Text('Admin'),
                    searchText: 'Admin',
                  ),
                  CoilOption(
                    value: 'owner',
                    label: Text('Owner'),
                    searchText: 'Owner',
                    enabled: false,
                  ),
                ],
              ),
            ),
            CoilField(
              label: const Text('Visibility'),
              child: CoilSelect<String>(
                value: _visibility,
                placeholder: const Text('Choose who can see it'),
                onChanged: (value) => setState(() => _visibility = value),
                options: const [
                  CoilOption(
                    value: 'private',
                    label: Text('Private'),
                    searchText: 'Private',
                    icon: CatalogIcon(Glyph.lock),
                  ),
                  CoilOption(
                    value: 'public',
                    label: Text('Public'),
                    searchText: 'Public',
                    icon: CatalogIcon(Glyph.globe),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Long list',
        description: 'More than 8 rows: a sheet on a touch phone.',
        child: CoilField(
          label: const Text('Country'),
          child: CoilSelect<String>(
            value: _country,
            placeholder: const Text('Select a country'),
            sheetTitle: const Text('Country'),
            onChanged: (value) => setState(() => _country = value),
            options: [
              for (final c in _countries)
                CoilOption(value: c, label: Text(c), searchText: c),
            ],
          ),
        ),
      ),
      DemoSection(
        title: 'MultiSelect',
        description:
            'Picked rows merge into one block. Always a sheet on phones.',
        child: CoilField(
          label: const Text('Labels'),
          child: CoilMultiSelect<String>(
            values: _labels,
            placeholder: const Text('Add labels'),
            sheetTitle: const Text('Labels'),
            onChanged: (values) => setState(() => _labels = values),
            options: const [
              CoilOption(value: 'bug', label: Text('Bug'), searchText: 'Bug'),
              CoilOption(
                value: 'feature',
                label: Text('Feature'),
                searchText: 'Feature',
              ),
              CoilOption(
                value: 'docs',
                label: Text('Docs'),
                searchText: 'Docs',
              ),
              CoilOption(
                value: 'design',
                label: Text('Design'),
                searchText: 'Design',
              ),
              CoilOption(
                value: 'perf',
                label: Text('Performance'),
                searchText: 'Performance',
              ),
            ],
          ),
        ),
      ),
      DemoSection(
        title: 'Pinned presentation',
        description: 'presentation: overrides the phone rule.',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Always a popover'),
              child: CoilSelect<String>(
                value: _popoverPick,
                presentation: CoilPresentation.popover,
                onChanged: (value) => setState(() => _popoverPick = value),
                options: _ranges,
              ),
            ),
            CoilField(
              label: const Text('Always a sheet'),
              child: CoilSelect<String>(
                value: _sheetPick,
                presentation: CoilPresentation.sheet,
                sheetTitle: const Text('Range'),
                onChanged: (value) => setState(() => _sheetPick = value),
                options: _ranges,
              ),
            ),
            const CoilField(
              label: Text('Disabled'),
              child: CoilSelect<String>(
                value: 'week',
                onChanged: null,
                options: _ranges,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  static const _ranges = [
    CoilOption(value: 'day', label: Text('Today'), searchText: 'Today'),
    CoilOption(
      value: 'week',
      label: Text('This week'),
      searchText: 'This week',
    ),
    CoilOption(
      value: 'month',
      label: Text('This month'),
      searchText: 'This month',
    ),
  ];
}
