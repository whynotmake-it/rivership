import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
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
  var _plan = 'team';
  var _invoices = true;
  var _usage = false;
  var _showError = false;
  var _kubernetes = true;
  var _vm = false;
  var _tier = 'pro';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Field',
    summary:
        'One control per field. Label, description and error join the '
        "control's semantics, so a screen reader reads them with its role.",
    children: [
      DemoSection(
        title: 'Orientation',
        description:
            'Responsive is vertical below 448 of width and horizontal above.',
        child: DemoColumn(
          children: [
            CoilTabs<CoilFieldOrientation>(
              value: _orientation,
              onChanged: (value) => setState(() => _orientation = value),
              tabs: const [
                CoilTab(
                  value: CoilFieldOrientation.vertical,
                  label: Text('Stacked'),
                ),
                CoilTab(
                  value: CoilFieldOrientation.horizontal,
                  label: Text('Side'),
                ),
                CoilTab(
                  value: CoilFieldOrientation.responsive,
                  label: Text('Auto'),
                ),
              ],
            ),
            CoilFieldGroup(
              children: [
                CoilField(
                  label: const Text('Workspace name'),
                  description: const Text('Shown to everyone you invite.'),
                  orientation: _orientation,
                  isRequired: true,
                  child: const CoilInput(placeholder: Text('Acme Inc.')),
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
          ],
        ),
      ),
      DemoSection(
        title: 'Errors',
        description:
            'The label turns destructive and the error is a live region.',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Billing email'),
              invalid: _showError,
              error: _showError
                  ? const Text('Enter an email address like ada@example.com')
                  : null,
              child: CoilInput(
                placeholder: const Text('billing@example.com'),
                invalid: _showError,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: () => setState(() => _showError = !_showError),
                child: Text(_showError ? 'Clear error' : 'Show error'),
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'FieldSet and separator',
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
