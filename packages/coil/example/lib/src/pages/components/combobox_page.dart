import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const comboboxEntry = CatalogEntry(
  slug: 'combobox',
  title: 'Combobox',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Type to filter, then pick one or several; IME-safe Enter.',
  page: ComboboxPage.new,
);

const _countries = [
  'Argentina', 'Australia', 'Austria', 'Belgium', 'Brazil', 'Canada', //
  'Chile', 'Denmark', 'Finland', 'France', 'Germany', 'Iceland', 'Japan',
  'Norway', 'Portugal', 'Spain', 'Sweden', 'Switzerland',
];

class ComboboxPage extends StatefulWidget {
  const ComboboxPage({super.key});

  @override
  State<ComboboxPage> createState() => _ComboboxPageState();
}

class _ComboboxPageState extends State<ComboboxPage> {
  String? _country;
  var _visited = <String>{'Japan'};

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final c in _countries)
        CoilOption(value: c, label: Text(c), searchText: c),
    ];
    return CatalogPage(
      title: 'Combobox',
      summary: 'Focus stays in the field: the arrows move through matches.',
      children: [
        DemoSection(
          title: 'Single',
          child: CoilField(
            label: const Text('Country'),
            child: CoilCombobox<String>(
              options: options,
              value: _country,
              onChanged: (v) => setState(() => _country = v),
            ),
          ),
        ),
        DemoSection(
          title: 'Multiple',
          child: CoilField(
            label: const Text('Visited'),
            child: CoilMultiCombobox<String>(
              options: options,
              values: _visited,
              onChanged: (v) => setState(() => _visited = v),
            ),
          ),
        ),
      ],
    );
  }
}
