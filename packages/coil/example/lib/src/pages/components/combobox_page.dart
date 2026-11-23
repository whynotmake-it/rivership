import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const comboboxEntry = CatalogEntry(
  slug: 'combobox',
  title: 'Combobox',
  group: CatalogGroup.menusAndOverlays,
  summary: 'A field you type into to filter a long list, then pick from it.',
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
        'A combobox is a text field you type into to find a value in a long '
        'list. Focus stays in the field while the arrow keys move through '
        'the matches, so you can keep typing to narrow them further.',
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
        'Typing filters the list and moves the active row back to the first '
            'match. Up and Down move it from there and Enter picks it, '
            'though never while an input method is still composing, and Esc '
            'first clears the text and then closes the list.',
      ),
      CatalogNote(
        'Multiple',
        'With MultiCombobox the picked values become chips that wrap inside '
            'the field as it springs taller. Backspace on empty text removes '
            'the last chip, and Left and Right move between them.',
      ),
      CatalogNote(
        'Touch',
        'On a phone the list opens as a full-height sheet with the field '
            'focused and the keyboard up. The chips sit above the field, and '
            'a multiple combobox gets a Done button in the header.',
      ),
      CatalogNote(
        'Screen readers',
        'The field is announced as a combobox with its expanded state and a '
            'live count of the matches, and the chips form a toolbar labeled '
            '"Selected".',
      ),
      CatalogNote(
        "Do / Don't",
        'Reach for a combobox when the list is long or open-ended, and for '
            'a Select when it holds fewer than about a dozen options. Never '
            'complete a value inline over what someone has typed.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Single value',
        description:
            'Type to narrow the list, then pick a match with Enter or a tap; '
            'setting presentation pins the list to a popover or a sheet.',
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
