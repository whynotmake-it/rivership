import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const fieldEntry = CatalogEntry(
  slug: 'field',
  title: 'Field',
  group: CatalogGroup.groupedControls,
  summary:
      'Label, description and error around one control; FieldSet groups; '
      'choice cards.',
  page: FieldPage.new,
);

class FieldPage extends StatefulWidget {
  const FieldPage({super.key});

  @override
  State<FieldPage> createState() => _FieldPageState();
}

class _FieldPageState extends State<FieldPage> {
  var _orientation = CoilFieldOrientation.vertical;
  var _showError = false;
  var _plan = 'team';
  var _invoices = true;
  var _usage = false;
  var _kubernetes = true;
  var _vm = false;
  var _tier = 'pro';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Field',
    summary:
        'One control per field. Label, description and error join the '
        "control's semantics, so a screen reader reads them with its role.",
    hero: const _WorkspaceForm(),
    usage: '''
CoilField(
  label: const Text('Workspace name'),
  description: const Text('Shown to everyone you invite.'),
  isRequired: true,
  invalid: error != null,
  error: error == null ? null : Text(error),
  child: CoilInput(
    controller: name,
    placeholder: const Text('Acme Inc.'),
  ),
)''',
    notes: const [
      CatalogNote(
        'Screen readers',
        'Label, description and error are read with the control, in that '
            'order, along with its role and value. The error is a live '
            'region, so it is announced when it appears.',
      ),
      CatalogNote(
        'Pointer',
        'Tapping a label runs its control: a text field takes focus, a '
            'switch or checkbox toggles. In a horizontal row, a tap anywhere '
            'in the row toggles a checkbox, switch or radio.',
      ),
      CatalogNote(
        'Motion',
        'An error or description springs its own height open and the fields '
            'below glide down with it. Reduced motion jumps and fades.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Do put one control in each Field and group several in a FieldSet. '
            'Don’t use a placeholder as the label.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'Responsive is stacked below 448 of width and side by side '
            'above.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Orientation',
              value: _orientation,
              values: CoilFieldOrientation.values,
              labelOf: (v) => switch (v) {
                CoilFieldOrientation.vertical => 'Stacked',
                CoilFieldOrientation.horizontal => 'Side',
                CoilFieldOrientation.responsive => 'Auto',
              },
              onChanged: (v) => setState(() => _orientation = v),
            ),
            DemoControl.toggle(
              label: 'Error',
              value: _showError,
              onChanged: (v) => setState(() => _showError = v),
            ),
          ],
        ),
        child: CoilFieldGroup(
          children: [
            CoilField(
              label: const Text('Billing email'),
              description: const Text('Receipts and invoices go here.'),
              orientation: _orientation,
              isRequired: true,
              invalid: _showError,
              error: _showError
                  ? const Text('Enter an email address like ada@example.com')
                  : null,
              child: const CoilInput(
                placeholder: Text('billing@example.com'),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            CoilField(
              label: const Text('Plan'),
              orientation: _orientation,
              child: CoilSelect<String>(
                value: _plan,
                onChanged: (value) => setState(() => _plan = value),
                options: const [
                  CoilOption(
                    value: 'free',
                    label: Text('Free'),
                    searchText: 'Free',
                  ),
                  CoilOption(
                    value: 'team',
                    label: Text('Team'),
                    searchText: 'Team',
                  ),
                  CoilOption(
                    value: 'enterprise',
                    label: Text('Enterprise'),
                    searchText: 'Enterprise',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'FieldSet and separator',
        description: 'A legend heads a group of fields; a separator splits it.',
        child: CoilFieldSet(
          legend: const Text('Email notifications'),
          description: const Text('Choose what we send you.'),
          children: [
            CoilField(
              label: const Text('Invoices'),
              orientation: CoilFieldOrientation.horizontal,
              child: CoilSwitch(
                value: _invoices,
                onChanged: (v) => setState(() => _invoices = v),
              ),
            ),
            CoilField(
              label: const Text('Usage alerts'),
              description: const Text('When you pass 80 % of your quota.'),
              orientation: CoilFieldOrientation.horizontal,
              child: CoilSwitch(
                value: _usage,
                onChanged: (v) => setState(() => _usage = v),
              ),
            ),
            const CoilFieldSeparator(label: Text('Advanced')),
            const CoilField(
              label: Text('Reply-to address'),
              child: CoilInput(placeholder: Text('support@example.com')),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Choice card',
        description:
            'The whole card is the target. Keyboard focus rings the card, '
            'not the checkbox.',
        child: CoilFieldGroup(
          children: [
            CoilChoiceCard(
              selected: _kubernetes,
              title: const Text('Kubernetes'),
              description: const Text('Run GPU workloads on a K8s cluster.'),
              control: CoilCheckbox(
                value: _kubernetes,
                onChanged: (v) => setState(() => _kubernetes = v ?? false),
              ),
            ),
            CoilChoiceCard(
              selected: _vm,
              title: const Text('Virtual machine'),
              description: const Text('Access a cluster to run GPU workloads.'),
              control: CoilCheckbox(
                value: _vm,
                onChanged: (v) => setState(() => _vm = v ?? false),
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Radio choice card',
        description:
            'One choice from cards: a CoilRadio per card in a '
            'CoilRadioGroup.custom. Arrows move the selection.',
        child: CoilRadioGroup<String>.custom(
          value: _tier,
          onChanged: (v) => setState(() => _tier = v),
          semanticLabel: 'Plan',
          child: CoilFieldGroup(
            children: [
              for (final (value, title, description) in const [
                ('hobby', 'Hobby', 'For side projects.'),
                ('pro', 'Pro', 'For teams that ship every day.'),
                ('enterprise', 'Enterprise', 'SSO, audit logs and support.'),
              ])
                CoilChoiceCard(
                  selected: _tier == value,
                  title: Text(title),
                  description: Text(description),
                  control: CoilRadio(value: value),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Workspace settings: required fields validated when Save is pressed, then
/// kept honest as you type.
class _WorkspaceForm extends StatefulWidget {
  const _WorkspaceForm();

  @override
  State<_WorkspaceForm> createState() => _WorkspaceFormState();
}

class _WorkspaceFormState extends State<_WorkspaceForm> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  var _region = 'eu';
  var _submitted = false;
  var _saved = false;

  static final _slugPattern = RegExp(r'^[a-z0-9-]{3,}$');

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  String? get _nameError => _submitted && _name.text.trim().isEmpty
      ? 'Give the workspace a name'
      : null;

  String? get _slugError {
    if (!_submitted) return null;
    final slug = _slug.text.trim();
    if (slug.isEmpty) return 'Pick a web address';
    if (!_slugPattern.hasMatch(slug)) {
      return 'Use at least 3 lowercase letters, digits or dashes';
    }
    return null;
  }

  void _edited() => setState(() => _saved = false);

  void _save() => setState(() {
    _submitted = true;
    _saved = _nameError == null && _slugError == null;
  });

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final nameError = _nameError;
    final slugError = _slugError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Workspace settings', style: text.title),
        const SizedBox(height: 16),
        CoilFieldGroup(
          children: [
            CoilField(
              label: const Text('Workspace name'),
              description: const Text('Shown to everyone you invite.'),
              isRequired: true,
              invalid: nameError != null,
              error: nameError == null ? null : Text(nameError),
              child: CoilInput(
                controller: _name,
                placeholder: const Text('Acme Inc.'),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _edited(),
              ),
            ),
            CoilField(
              label: const Text('Web address'),
              isRequired: true,
              invalid: slugError != null,
              error: slugError == null ? null : Text(slugError),
              child: CoilInput(
                controller: _slug,
                placeholder: const Text('acme'),
                leading: Text('coil.dev/', style: text.muted.body),
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _edited(),
                onSubmitted: (_) => _save(),
              ),
            ),
            CoilField(
              label: const Text('Data region'),
              description: const Text('Where your files are stored.'),
              child: CoilSelect<String>(
                value: _region,
                onChanged: (value) => setState(() {
                  _region = value;
                  _saved = false;
                }),
                options: const [
                  CoilOption(
                    value: 'eu',
                    label: Text('Europe'),
                    searchText: 'Europe',
                  ),
                  CoilOption(
                    value: 'us',
                    label: Text('United States'),
                    searchText: 'United States',
                  ),
                  CoilOption(
                    value: 'ap',
                    label: Text('Asia Pacific'),
                    searchText: 'Asia Pacific',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: CoilButton(
            leading: _saved ? const CatalogIcon(Glyph.check) : null,
            onPressed: _save,
            child: Text(_saved ? 'Saved' : 'Save changes'),
          ),
        ),
      ],
    );
  }
}
