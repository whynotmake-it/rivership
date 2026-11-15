import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

const inputGroupEntry = CatalogEntry(
  slug: 'input-group',
  title: 'InputGroup',
  group: CatalogGroup.groupedControls,
  summary: 'Labeled inputs sharing one hover scope.',
  page: InputGroupPage.new,
);

class InputGroupPage extends StatefulWidget {
  const InputGroupPage({super.key});

  @override
  State<InputGroupPage> createState() => _InputGroupPageState();
}

class _InputGroupPageState extends State<InputGroupPage> {
  var _handle = '';

  bool get _handleInvalid => _handle.contains(' ');

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputGroup',
    summary:
        'With a mouse, the field nearest the pointer gets the hover fill; '
        'nothing glides. Tab moves between fields.',
    children: [
      DemoSection(
        title: 'Profile',
        child: CoilInputGroup(
          children: [
            const CoilField(
              label: Text('Name'),
              child: CoilInput(
                placeholder: Text('Ada Lovelace'),
                leading: CatalogIcon(Glyph.user),
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
                invalid: _handleInvalid,
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
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
