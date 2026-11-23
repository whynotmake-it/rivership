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
        'A read-only value with a copy action. The feedback is inline on '
        'every platform: a check, or "Copied", for 2 s.',
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
        'Enter or Space copies. A tap on the field’s label copies too.',
      ),
      CatalogNote(
        'Motion',
        'The icon swaps to a check, or an × if the clipboard refused. '
            'A button springs between the real widths of "Copy" and '
            '"Copied". Copying again only restarts the 2 s.',
      ),
      CatalogNote(
        'Accessibility',
        'A button named Copy plus the field label, with the full text as '
            'its value. It announces "Copied" or "Copy failed".',
      ),
      CatalogNote(
        'Pointer',
        'Hovering marks the value with a faint brand tint and turns the '
            'action foreground. A tooltip is optional, never the only '
            'feedback.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description: 'The value truncates; the action is always visible.',
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
