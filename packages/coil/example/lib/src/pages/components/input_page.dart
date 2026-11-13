import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const inputEntry = CatalogEntry(
  slug: 'input',
  title: 'Input',
  group: CatalogGroup.leafControls,
  summary: 'Single-line text with native editing, slots and validation.',
  page: InputPage.new,
);

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  var _submitted = '';
  var _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _email.text.trim();
    setState(() {
      _emailError = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
          ? null
          : 'Enter an email address like ada@example.com';
    });
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Input',
    summary:
        "Native selection, magnifier and edit menu. Fields don't get a focus "
        'ring: the border darkens instead, however they were focused.',
    children: [
      DemoSection(
        title: 'Sign in',
        description: 'Return on the email field submits and validates it.',
        child: DemoColumn(
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
                onSubmitted: (_) => _validate(),
              ),
            ),
            CoilField(
              label: const Text('Password'),
              description: const Text('At least 12 characters.'),
              child: CoilInput(
                controller: _password,
                leading: const CatalogIcon(Glyph.lock),
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                trailing: CoilButton(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  child: Text(_showPassword ? 'Hide' : 'Show'),
                ),
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Search',
        child: CoilInput(
          semanticLabel: 'Search',
          placeholder: const Text('Search files'),
          leading: const CatalogIcon(Glyph.search),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => setState(() => _submitted = value),
          trailing: _submitted.isEmpty ? null : Text('“$_submitted”'),
        ),
      ),
      DemoSection(
        title: 'States',
        child: DemoColumn(
          children: [
            const CoilField(
              label: Text('Read-only'),
              child: _ReadOnly(),
            ),
            const CoilField(
              label: Text('Disabled'),
              child: CoilInput(
                enabled: false,
                placeholder: Text('Not available'),
              ),
            ),
            CoilField(
              label: const Text('Amount'),
              description: const Text('Digits only.'),
              child: CoilInput(
                placeholder: const Text('0'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                trailing: const Text('EUR'),
              ),
            ),
            const CoilField(
              label: Text('Compact'),
              child: CoilInput(
                size: CoilSize.compact,
                placeholder: Text('Filter'),
                leading: CatalogIcon(Glyph.search),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ReadOnly extends StatefulWidget {
  const _ReadOnly();

  @override
  State<_ReadOnly> createState() => _ReadOnlyState();
}

class _ReadOnlyState extends State<_ReadOnly> {
  final _controller = TextEditingController(text: 'workspace-7f3a');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CoilInput(controller: _controller, readOnly: true);
}
