import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const inputCopyEntry = CatalogEntry(
  slug: 'input-copy',
  title: 'InputCopy',
  group: CatalogGroup.groupedControls,
  summary: 'A read-only value with a copy action and inline feedback.',
  page: InputCopyPage.new,
);

class InputCopyPage extends StatefulWidget {
  const InputCopyPage({super.key});

  @override
  State<InputCopyPage> createState() => _InputCopyPageState();
}

enum _Action {
  icon('Icon', CoilInputCopyVariant.icon),
  button('Button', CoilInputCopyVariant.button);

  const _Action(this.label, this.variant);

  final String label;
  final CoilInputCopyVariant variant;
}

class _InputCopyPageState extends State<InputCopyPage> {
  var _action = _Action.icon;
  var _atStart = false;
  var _compact = false;
  var _disabled = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputCopy',
    summary:
        'Shows a read-only value next to a copy action, and confirms a copy '
        'inline for a couple of seconds on every platform.',
    hero: const _DeveloperKeys(),
    usage: '''
CoilField(
  label: const Text('Secret key'),
  description: const Text('Server-side only. Rotate it if it leaks.'),
  child: CoilInputCopy(value: secretKey),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Enter or Space copies the value while the action has focus, and '
            'clicking the field’s label copies it too.',
      ),
      CatalogNote(
        'Motion',
        'The icon swaps to a check, or to an X if copying fails, and a '
            'button springs between the widths of “Copy” and “Copied”. '
            'Copying again just restarts the confirmation.',
      ),
      CatalogNote(
        'Accessibility',
        'The action is a button named after the field it copies, carrying '
            'the full text as its value, and it announces “Copied” or “Copy '
            'failed” when pressed.',
      ),
      CatalogNote(
        'Pointer',
        'Hovering tints the value and brings the action to full opacity. A '
            'tooltip can explain the action, but it is never the only '
            'feedback a copy gives.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'A value that is too long to fit is truncated, and the action '
            'stays visible at the end of the field.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Action',
              value: _action,
              values: _Action.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _action = v),
            ),
            DemoControl.toggle(
              label: 'Action first',
              value: _atStart,
              onChanged: (v) => setState(() => _atStart = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Disabled',
              value: _disabled,
              onChanged: (v) => setState(() => _disabled = v),
            ),
          ],
        ),
        child: CoilField(
          label: const Text('Clone URL'),
          child: CoilInputCopy(
            value: 'git@github.com:whynotmake-it/rivership.git',
            variant: _action.variant,
            align: _atStart ? CoilInputCopyAlign.start : CoilInputCopyAlign.end,
            size: _compact ? CoilSize.compact : null,
            enabled: !_disabled,
          ),
        ),
      ),
    ],
  );
}

/// Developer settings: two keys to copy into a config, and an invite link to
/// paste into a chat.
class _DeveloperKeys extends StatelessWidget {
  const _DeveloperKeys();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Developer settings', style: text.title),
        const SizedBox(height: 16),
        const CoilFieldGroup(
          children: [
            CoilField(
              label: Text('Publishable key'),
              description: Text('Safe to ship in your app.'),
              child: CoilInputCopy(value: 'pk_live_51Hx7bc0e2d4a58'),
            ),
            CoilField(
              label: Text('Secret key'),
              description: Text('Server-side only. Rotate it if it leaks.'),
              child: CoilInputCopy(value: 'sk_live_9d1f2a7e43b0c685'),
            ),
            CoilFieldSeparator(label: Text('Team')),
            CoilField(
              label: Text('Invite link'),
              description: Text('Anyone with the link can join as a member.'),
              child: CoilInputCopy(
                value: 'https://coil.dev/join/7f3a-91bc',
                variant: CoilInputCopyVariant.button,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
