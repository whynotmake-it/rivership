import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const selectEntry = CatalogEntry(
  slug: 'select',
  title: 'Select',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Pick one option or several from a list, in a popover or a sheet.',
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

const _ranges = [
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

enum _Presentation {
  automatic('Auto', null),
  popover('Popover', CoilPresentation.popover),
  sheet('Sheet', CoilPresentation.sheet);

  const _Presentation(this.label, this.presentation);

  final String label;
  final CoilPresentation? presentation;
}

class SelectPage extends StatefulWidget {
  const SelectPage({super.key});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  String? _country;
  var _labels = {'bug'};
  var _range = 'week';
  var _presentation = _Presentation.automatic;
  var _disabled = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Select',
    summary:
        'Select picks one option and MultiSelect picks several. The list '
        'opens as a popover where there is room, and on a touch phone a '
        'long list or a multiple choice opens as a sheet instead.',
    hero: const _InviteForm(),
    usage: '''
CoilField(
  label: const Text('Role'),
  description: Text(role.description),
  child: CoilSelect<Role>(
    value: role,
    onChanged: (value) => setState(() => role = value),
    options: [
      for (final r in Role.values)
        CoilOption(value: r, label: Text(r.label)),
    ],
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Enter, Space or the up and down arrows open the list on the picked '
            'row. From there the arrows, Home, End, PageUp and PageDown move '
            'between rows, typing jumps to a match, Enter or Space picks, '
            'and Esc or Tab dismisses the list.',
      ),
      CatalogNote(
        'Pointer',
        'The popover is at most 300 logical pixels tall, and a list of more '
            'than 12 options adds a search row. The active row’s fill '
            'glides from one row to the next as you move.',
      ),
      CatalogNote(
        'Touch',
        'A single choice of up to 8 options stays in a popover anchored to '
            'the field. Longer lists and every MultiSelect open a sheet '
            'titled with the field’s label.',
      ),
      CatalogNote(
        'Motion',
        'After a pick the list stays open for 300 ms so the check mark can '
            'draw, and then it closes. The page behind it already accepts '
            'input during that moment.',
      ),
      CatalogNote(
        "Do / Don't",
        'For fewer than 3 options a RadioGroup or Tabs is usually a better '
            'fit, and a list of actions belongs in a Dropdown.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Long list',
        description:
            'With more than 8 options the list opens as a sheet on a touch '
            'phone.',
        child: CoilField(
          label: const Text('Country'),
          child: CoilSelect<String>(
            value: _country,
            placeholder: const Text('Choose a country'),
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
            'Picked rows merge into a single block, and on a touch phone the '
            'list always opens as a sheet.',
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
        title: 'Playground',
        description:
            'Setting presentation overrides the default choice between '
            'popover and sheet.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Presentation',
              value: _presentation,
              values: _Presentation.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _presentation = v),
            ),
            DemoControl.toggle(
              label: 'Disabled',
              value: _disabled,
              onChanged: (v) => setState(() => _disabled = v),
            ),
          ],
        ),
        child: CoilField(
          label: const Text('Date range'),
          child: CoilSelect<String>(
            value: _range,
            presentation: _presentation.presentation,
            sheetTitle: const Text('Date range'),
            onChanged: _disabled
                ? null
                : (value) => setState(() => _range = value),
            options: _ranges,
          ),
        ),
      ),
    ],
  );
}

enum _Role {
  viewer('Viewer', 'Viewers can read everything but change nothing.'),
  editor('Editor', 'Editors can change content, not billing.'),
  admin('Admin', 'Admins can also manage members and billing.');

  const _Role(this.label, this.description);

  final String label;
  final String description;
}

/// Inviting a member: a role whose description follows the choice, and
/// who may see the project.
class _InviteForm extends StatefulWidget {
  const _InviteForm();

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _email = TextEditingController();
  var _role = _Role.editor;
  String? _visibility = 'project';
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() => _sentTo = email);
    _email.clear();
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Invite a member', style: text.title),
        const SizedBox(height: 2),
        Text(
          _sentTo == null
              ? 'They get an email with a link to join.'
              : 'Invitation sent to $_sentTo.',
          style: text.muted.caption,
        ),
        const SizedBox(height: 20),
        DemoColumn(
          children: [
            CoilField(
              label: const Text('Email'),
              child: CoilInput(
                controller: _email,
                placeholder: const Text('ada@example.com'),
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _send(),
              ),
            ),
            CoilField(
              label: const Text('Role'),
              description: Text(_role.description),
              child: CoilSelect<_Role>(
                value: _role,
                icon: const CatalogIcon(Glyph.user),
                sheetTitle: const Text('Role'),
                onChanged: (role) => setState(() => _role = role),
                options: [
                  for (final role in _Role.values)
                    CoilOption(
                      value: role,
                      label: Text(role.label),
                      searchText: role.label,
                    ),
                ],
              ),
            ),
            CoilField(
              label: const Text('Can see'),
              child: CoilSelect<String>(
                value: _visibility,
                sheetTitle: const Text('Can see'),
                onChanged: (value) => setState(() => _visibility = value),
                options: const [
                  CoilOption(
                    value: 'project',
                    label: Text('Only this project'),
                    searchText: 'Only this project',
                    icon: CatalogIcon(Glyph.lock),
                  ),
                  CoilOption(
                    value: 'workspace',
                    label: Text('The whole workspace'),
                    searchText: 'The whole workspace',
                    icon: CatalogIcon(Glyph.globe),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ListenableBuilder(
            listenable: _email,
            builder: (context, _) => CoilButton(
              onPressed: _email.text.trim().isEmpty ? null : _send,
              child: const Text('Send invite'),
            ),
          ),
        ),
      ],
    );
  }
}
