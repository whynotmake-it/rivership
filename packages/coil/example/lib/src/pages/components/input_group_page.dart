import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const inputGroupEntry = CatalogEntry(
  slug: 'input-group',
  title: 'InputGroup',
  group: CatalogGroup.groupedControls,
  summary: 'A column of labeled inputs that share one hover scope.',
  page: InputGroupPage.new,
);

class InputGroupPage extends StatefulWidget {
  const InputGroupPage({super.key});

  @override
  State<InputGroupPage> createState() => _InputGroupPageState();
}

class _InputGroupPageState extends State<InputGroupPage> {
  var _compact = false;
  var _showError = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputGroup',
    summary:
        'A column of labeled inputs that share one hover scope, so with a '
        'mouse only the field nearest the pointer takes the hover fill.',
    hero: const _ProfileForm(),
    usage: '''
CoilInputGroup(
  children: [
    CoilField(
      label: const Text('Name'),
      child: CoilInput(
        placeholder: const Text('Ada Lovelace'),
        leading: const Icon(LucideIcons.user),
      ),
    ),
    CoilField(
      label: const Text('Website'),
      child: CoilInput(placeholder: const Text('example.com')),
    ),
  ],
)''',
    notes: const [
      CatalogNote(
        'Pointer',
        'Only the field nearest the pointer is filled, and moving between '
            'fields swaps the fill at once instead of gliding it across.',
      ),
      CatalogNote(
        'Keyboard',
        'Tab moves between the fields in order, and focus shows as the '
            'field’s own border rather than as a hover fill. A tap anywhere '
            'in a field’s box puts the caret in its text.',
      ),
      CatalogNote(
        'Touch',
        'There is no hover on touch, so the fields only show focus, and '
            'they sit a little further apart than on desktop.',
      ),
      CatalogNote(
        'Accessibility',
        'Each error sits under its own field and is announced with it, and '
            'a button inside one input never makes that field taller than '
            'its neighbors.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Error',
              value: _showError,
              onChanged: (v) => setState(() => _showError = v),
            ),
          ],
        ),
        child: CoilInputGroup(
          size: _compact ? CoilSize.compact : null,
          children: [
            const CoilField(
              label: Text('Email'),
              child: CoilInput(
                placeholder: Text('ada@example.com'),
                leading: CatalogIcon(Glyph.mail),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            CoilField(
              label: const Text('Password'),
              description: const Text('At least 12 characters.'),
              invalid: _showError,
              error: _showError
                  ? const Text('That password is too short')
                  : null,
              child: const CoilInput(
                leading: CatalogIcon(Glyph.lock),
                obscureText: true,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A public profile: three fields in one group. The handle is checked while
/// you type, the website is optional.
class _ProfileForm extends StatefulWidget {
  const _ProfileForm();

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  var _handle = '';

  bool get _handleInvalid => _handle.contains(' ');

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Public profile', style: text.title),
        const SizedBox(height: 16),
        CoilInputGroup(
          children: [
            const CoilField(
              label: Text('Name'),
              child: CoilInput(
                placeholder: Text('Ada Lovelace'),
                leading: CatalogIcon(Glyph.user),
                textCapitalization: TextCapitalization.words,
                autofillHints: [AutofillHints.name],
              ),
            ),
            CoilField(
              label: const Text('Handle'),
              invalid: _handleInvalid,
              error: _handleInvalid
                  ? const Text('Use letters, digits and dashes, no spaces')
                  : null,
              child: CoilInput(
                placeholder: const Text('ada'),
                leading: const CatalogIcon(Glyph.at),
                autocorrect: false,
                onChanged: (value) => setState(() => _handle = value),
              ),
            ),
            const CoilField(
              label: Text('Website'),
              description: Text('Shown on your public profile.'),
              child: CoilInput(
                placeholder: Text('example.com'),
                leading: CatalogIcon(Glyph.globe),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
