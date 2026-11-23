import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const comboboxEntry = CatalogEntry(
  slug: 'combobox',
  title: 'Combobox',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Type to filter, then pick one or several; IME-safe Enter.',
  page: ComboboxPage.new,
);

const _members = [
  'Ada Lovelace',
  'Alan Turing',
  'Barbara Liskov',
  'Dennis Ritchie',
  'Edsger Dijkstra',
  'Grace Hopper',
  'Hedy Lamarr',
  'Katherine Johnson',
  'Margaret Hamilton',
  'Radia Perlman',
];

const _labelNames = [
  'Accessibility',
  'Bug',
  'Design',
  'Docs',
  'Feature',
  'Performance',
  'Regression',
  'Research',
];

const _countries = [
  'Argentina',
  'Australia',
  'Austria',
  'Belgium',
  'Brazil',
  'Canada',
  'Chile',
  'Denmark',
  'Finland',
  'France',
  'Germany',
  'Iceland',
  'Japan',
  'Norway',
  'Portugal',
  'Spain',
  'Sweden',
  'Switzerland',
];

List<CoilOption<String>> _optionsOf(List<String> values) => [
  for (final v in values) CoilOption(value: v, label: Text(v), searchText: v),
];

enum _Presentation {
  automatic('Auto', null),
  popover('Popover', CoilPresentation.popover),
  sheet('Sheet', CoilPresentation.sheet);

  const _Presentation(this.label, this.presentation);

  final String label;
  final CoilPresentation? presentation;
}

class ComboboxPage extends StatefulWidget {
  const ComboboxPage({super.key});

  @override
  State<ComboboxPage> createState() => _ComboboxPageState();
}

class _ComboboxPageState extends State<ComboboxPage> {
  var _presentation = _Presentation.automatic;
  String? _country;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Combobox',
    summary:
        'A field you type into to find a value in a long list. Focus stays '
        'in the field while the arrows move through the matches.',
    hero: const _IssuePanel(),
    usage: '''
CoilField(
  label: const Text('Assignee'),
  child: CoilCombobox<String>(
    value: assignee,
    onChanged: pickAssignee,
    placeholder: const Text('Search members'),
    options: [
      for (final name in members)
        CoilOption(value: name, label: Text(name)),
    ],
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Typing filters and resets the active row to the first match. '
            'Up and Down move it, Enter picks it (never mid-composition in '
            'an IME) and Esc clears the text, then closes.',
      ),
      CatalogNote(
        'Multiple',
        'Chips wrap inside the field and the field springs taller. '
            'Backspace on empty text removes the last chip; Left and Right '
            'move between chips.',
      ),
      CatalogNote(
        'Touch',
        'On a phone it opens a full-height sheet with the field focused '
            'and the keyboard up. Chips sit above the field and a multiple '
            'combobox has Done in the header.',
      ),
      CatalogNote(
        'Screen readers',
        'A combobox text field with expanded state and a live result '
            'count. The chips are a toolbar labeled "Selected".',
      ),
      CatalogNote(
        "Do / Don't",
        'Use it for long or open-ended lists; a Select suits fewer than '
            'about a dozen. Never complete inline over what was typed.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Single value',
        description:
            'Type to narrow the list, then pick a match with Enter or a tap.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Presentation',
              value: _presentation,
              values: _Presentation.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _presentation = v),
            ),
          ],
        ),
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Country'),
              child: CoilCombobox<String>(
                options: _optionsOf(_countries),
                value: _country,
                presentation: _presentation.presentation,
                placeholder: const Text('Search countries'),
                sheetTitle: const Text('Country'),
                onChanged: (v) => setState(() => _country = v),
              ),
            ),
            CoilField(
              label: const Text('Disabled'),
              child: CoilCombobox<String>(
                options: _optionsOf(_countries),
                value: 'Japan',
                onChanged: null,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A new issue's side panel: who it goes to and what it's about.
class _IssuePanel extends StatefulWidget {
  const _IssuePanel();

  @override
  State<_IssuePanel> createState() => _IssuePanelState();
}

class _IssuePanelState extends State<_IssuePanel> {
  String? _assignee = 'Grace Hopper';
  var _labels = <String>{'Bug', 'Regression'};

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sheet flickers while dragging', style: text.title),
        const SizedBox(height: 2),
        Text('Opened by Ada Lovelace · 2 hours ago', style: text.muted.caption),
        const SizedBox(height: 20),
        DemoColumn(
          children: [
            CoilField(
              label: const Text('Assignee'),
              child: CoilCombobox<String>(
                options: _optionsOf(_members),
                value: _assignee,
                placeholder: const Text('Search members'),
                sheetTitle: const Text('Assignee'),
                onChanged: (v) => setState(() => _assignee = v),
              ),
            ),
            CoilField(
              label: const Text('Labels'),
              child: CoilMultiCombobox<String>(
                options: _optionsOf(_labelNames),
                values: _labels,
                placeholder: const Text('Add labels'),
                sheetTitle: const Text('Labels'),
                onChanged: (v) => setState(() => _labels = v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
