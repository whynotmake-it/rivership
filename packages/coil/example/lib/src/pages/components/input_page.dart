import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const inputEntry = CatalogEntry(
  slug: 'input',
  title: 'Input',
  group: CatalogGroup.leafControls,
  summary:
      'Single-line text that edits like the platform’s own fields, with '
      'slots and validation.',
  page: InputPage.new,
);

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

enum _Mode {
  editable('Editable'),
  readOnly('Read-only'),
  disabled('Disabled');

  const _Mode(this.label);

  final String label;
}

class _InputPageState extends State<InputPage> {
  final _workspace = TextEditingController(text: 'workspace-7f3a');
  var _compact = false;
  var _leading = true;
  var _invalid = false;
  var _mode = _Mode.editable;
  var _submitted = '';

  @override
  void dispose() {
    _workspace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Input',
    summary:
        'An input edits single-line text the way the platform’s own fields '
        'do, with the same selection, magnifier and edit menu. Pair it with a '
        'field so that it has a label.',
    hero: const _SignInForm(),
    usage: '''
CoilField(
  label: const Text('Email'),
  error: error == null ? null : Text(error),
  child: CoilInput(
    controller: email,
    placeholder: const Text('ada@example.com'),
    leading: const CatalogIcon(Glyph.mail),
    keyboardType: TextInputType.emailAddress,
    invalid: error != null,
  ),
)''',
    notes: const [
      CatalogNote(
        'Focus',
        'An input has no focus ring, and its border darkens instead, '
            'whichever way it received focus.',
      ),
      CatalogNote(
        'Pointer',
        'Selection, the context menu and the shortcuts are the platform’s '
            'own, so a double-click selects a word and the menu offers copy '
            'and paste.',
      ),
      CatalogNote(
        'Touch',
        'The platform draws its own handles, magnifier and edit menu, and '
            'the input scrolls itself 16 px clear of the keyboard.',
      ),
      CatalogNote(
        'Keyboard',
        'Return runs onSubmitted, except while it is committing an IME '
            'composition, when it only commits. Set keyboardType, '
            'textInputAction and autofillHints for each input.',
      ),
      CatalogNote(
        'Do / Don’t',
        'A placeholder is a hint and should not stand in for the label. The '
            'slots can hold an icon, a unit or a compact button without '
            'making the input any taller.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'State',
              value: _mode,
              values: _Mode.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _mode = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Leading icon',
              value: _leading,
              onChanged: (v) => setState(() => _leading = v),
            ),
            DemoControl.toggle(
              label: 'Invalid',
              value: _invalid,
              onChanged: (v) => setState(() => _invalid = v),
            ),
          ],
        ),
        child: CoilField(
          label: const Text('Workspace ID'),
          error: _invalid ? const Text('That ID is already taken') : null,
          invalid: _invalid,
          child: CoilInput(
            controller: _workspace,
            size: _compact ? CoilSize.compact : null,
            enabled: _mode != _Mode.disabled,
            readOnly: _mode == _Mode.readOnly,
            invalid: _invalid,
            leading: _leading ? const CatalogIcon(Glyph.globe) : null,
          ),
        ),
      ),
      DemoSection(
        title: 'Slots and formatting',
        description:
            'A short slot sits inline with the text, and formatters and '
            'keyboard types keep unwanted characters out.',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Amount'),
              description: const Text('Digits only'),
              child: CoilInput(
                placeholder: const Text('0'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                trailing: const Text('EUR'),
              ),
            ),
            CoilField(
              label: const Text('Search'),
              description: const Text('Press Return to search'),
              child: CoilInput(
                placeholder: const Text('Search members'),
                leading: const CatalogIcon(Glyph.search),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => setState(() => _submitted = value),
                trailing: _submitted.isEmpty ? null : Text('“$_submitted”'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A sign-in form: Return in the email field validates it, a button in the
/// password's slot shows or hides it, and the primary button submits.
class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _signedInAs;
  var _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(
      _email.text.trim(),
    );
    setState(() {
      _emailError = valid ? null : 'Enter an email like ada@example.com';
    });
    return valid;
  }

  void _signIn() {
    final emailValid = _validateEmail();
    final passwordValid = _password.text.length >= 12;
    setState(() {
      _passwordError = passwordValid ? null : 'Use at least 12 characters';
      _signedInAs = emailValid && passwordValid ? _email.text.trim() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign in', style: text.title),
        const SizedBox(height: 16),
        DemoColumn(
          children: [
            CoilField(
              label: const Text('Email'),
              isRequired: true,
              invalid: _emailError != null,
              error: _emailError == null ? null : Text(_emailError!),
              child: CoilInput(
                controller: _email,
                placeholder: const Text('ada@example.com'),
                leading: const CatalogIcon(Glyph.mail),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                invalid: _emailError != null,
                onSubmitted: (_) => _validateEmail(),
              ),
            ),
            CoilField(
              label: const Text('Password'),
              description: const Text('At least 12 characters'),
              invalid: _passwordError != null,
              error: _passwordError == null ? null : Text(_passwordError!),
              child: CoilInput(
                controller: _password,
                leading: const CatalogIcon(Glyph.lock),
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                invalid: _passwordError != null,
                onSubmitted: (_) => _signIn(),
                // A button in a slot is compact and sits in the field's
                // padding, so the field keeps its height.
                trailing: CoilButton(
                  variant: CoilButtonVariant.ghost,
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  child: Text(_showPassword ? 'Hide' : 'Show'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            CoilButton(onPressed: _signIn, child: const Text('Sign in')),
            const SizedBox(width: 12),
            if (_signedInAs case final email?)
              Expanded(
                child: Text(
                  'Signed in as $email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.muted.caption,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
