import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const checkboxEntry = CatalogEntry(
  slug: 'checkbox',
  title: 'Checkbox',
  group: CatalogGroup.leafControls,
  summary: 'A bare tick when checked, a dash when mixed.',
  page: CheckboxPage.new,
);

class CheckboxPage extends StatefulWidget {
  const CheckboxPage({super.key});

  @override
  State<CheckboxPage> createState() => _CheckboxPageState();
}

class _CheckboxPageState extends State<CheckboxPage> {
  var _terms = false;
  var _newsletter = true;
  final _files = {'Invoice.pdf': true, 'Receipt.pdf': false, 'Notes.txt': true};
  bool? _tri;
  var _invalid = false;

  bool? get _allFiles {
    final values = _files.values.toSet();
    return values.length == 1 ? values.single : null;
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Checkbox',
    summary:
        'Use it for independent on/off choices in a form. For settings that '
        'apply at once, use a Switch.',
    children: [
      DemoSection(
        title: 'In fields',
        description: 'Tap the label too: it toggles the box.',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('I agree to the terms'),
              orientation: CoilFieldOrientation.horizontal,
              invalid: _invalid && !_terms,
              error: _invalid && !_terms
                  ? const Text('Accept the terms to continue')
                  : null,
              child: CoilCheckbox(
                value: _terms,
                invalid: _invalid && !_terms,
                onChanged: (value) => setState(() => _terms = value!),
              ),
            ),
            CoilField(
              label: const Text('Send me product news'),
              description: const Text('About once a month.'),
              orientation: CoilFieldOrientation.horizontal,
              child: CoilCheckbox(
                value: _newsletter,
                onChanged: (value) => setState(() => _newsletter = value!),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: () => setState(() => _invalid = true),
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Select all',
        description:
            'A parent box shows a dash when only some children are checked.',
        child: DemoColumn(
          spacing: 8,
          children: [
            CoilField(
              label: const Text('All files'),
              orientation: CoilFieldOrientation.horizontal,
              child: CoilCheckbox(
                value: _allFiles,
                tristate: true,
                onChanged: (_) => setState(() {
                  final next = _allFiles != true;
                  _files.updateAll((_, _) => next);
                }),
              ),
            ),
            for (final name in _files.keys)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 24),
                child: CoilField(
                  label: Text(name),
                  orientation: CoilFieldOrientation.horizontal,
                  child: CoilCheckbox(
                    value: _files[name],
                    onChanged: (value) => setState(() => _files[name] = value!),
                  ),
                ),
              ),
          ],
        ),
      ),
      DemoSection(
        title: 'States',
        child: DemoWrap(
          spacing: 24,
          children: [
            Labeled(
              'Tristate: tap to cycle',
              child: CoilCheckbox(
                value: _tri,
                tristate: true,
                semanticLabel: 'Tristate',
                onChanged: (value) => setState(() => _tri = value),
              ),
            ),
            const Labeled(
              'Disabled',
              child: CoilCheckbox(
                value: false,
                onChanged: null,
                semanticLabel: 'Disabled',
              ),
            ),
            const Labeled(
              'Disabled, checked',
              child: CoilCheckbox(
                value: true,
                onChanged: null,
                semanticLabel: 'Disabled, checked',
              ),
            ),
            Labeled(
              'Invalid',
              child: CoilCheckbox(
                value: false,
                invalid: true,
                semanticLabel: 'Invalid',
                onChanged: (_) {},
              ),
            ),
            Labeled(
              'Compact',
              child: CoilCheckbox(
                value: true,
                size: CoilSize.compact,
                semanticLabel: 'Compact',
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
