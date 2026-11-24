import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const checkboxEntry = CatalogEntry(
  slug: 'checkbox',
  title: 'Checkbox',
  group: CatalogGroup.leafControls,
  summary: 'An independent on/off choice with a check, or a dash when mixed.',
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
  var _invalid = false;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Checkbox',
    summary:
        'A checkbox is an independent on/off choice in a form, shown with a '
        'visible label. A setting that takes effect the moment it changes is '
        'better served by a switch.',
    hero: const _FileList(),
    usage: '''
CoilField(
  label: Text(file),
  orientation: CoilFieldOrientation.horizontal,
  child: CoilCheckbox(
    value: selected.contains(file),
    onChanged: (value) => toggle(file, value!),
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Space toggles the checkbox, and Enter does so only inside a choice '
            'card.',
      ),
      CatalogNote(
        'Touch',
        'On touch the box is 20 px wide with a 44 px hit target, and tapping '
            'the label inside a field toggles it as well.',
      ),
      CatalogNote(
        'Motion',
        'The check draws on and retracts, and changing between check and dash '
            'retracts one before drawing the other. With reduced motion the '
            'new state appears at once.',
      ),
      CatalogNote(
        'Screen readers',
        'A checkbox is read as checked, unchecked or mixed together with '
            'its field’s label, and a checkbox outside a field needs a '
            'semanticLabel of its own.',
      ),
    ],
    children: [
      DemoSection(
        title: 'In a form',
        description:
            'Submit the form without accepting the terms to see the error.',
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
                child: const Text('Create account'),
              ),
            ),
          ],
        ),
      ),
      const DemoSection(
        title: 'States',
        description:
            'Each state in the regular and compact sizes, with the mixed dash '
            'that a tristate checkbox adds.',
        child: _StatesTable(),
      ),
    ],
  );
}

/// A files list: select all, a dash when only some are checked, and a bulk
/// action that enables once something is.
class _FileList extends StatefulWidget {
  const _FileList();

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  static const _sizes = {
    'Invoice-2041.pdf': '184 KB',
    'Receipt-march.pdf': '92 KB',
    'Notes.txt': '4 KB',
    'Site-plan.png': '2.1 MB',
  };

  late final _selected = {'Invoice-2041.pdf', 'Notes.txt'};
  final _removed = <String>{};

  Iterable<String> get _files =>
      _sizes.keys.where((f) => !_removed.contains(f));

  bool? get _all {
    final files = _files.toList();
    if (files.isEmpty || _selected.isEmpty) return false;
    return _selected.length == files.length ? true : null;
  }

  void _toggleAll() => setState(() {
    if (_all ?? false) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(_files);
    }
  });

  void _remove() => setState(() {
    _removed.addAll(_selected);
    _selected.clear();
  });

  void _restore() => setState(_removed.clear);

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final files = _files.toList();
    final count = _selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Files', style: text.title)),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              leading: const CatalogIcon(Glyph.trash),
              onPressed: count == 0 ? null : _remove,
              child: Text(count == 0 ? 'Remove' : 'Remove $count'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DemoColumn(
          children: [
            CoilField(
              label: Text(
                'Select all',
                style: text.body.copyWith(fontWeight: text.emphasis),
              ),
              orientation: CoilFieldOrientation.horizontal,
              child: CoilCheckbox(
                value: _all,
                tristate: true,
                onChanged: files.isEmpty ? null : (_) => _toggleAll(),
              ),
            ),
            if (files.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text('No files left.', style: text.muted.body),
                  ),
                  CoilButton(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    onPressed: _restore,
                    child: const Text('Restore files'),
                  ),
                ],
              ),
            for (final file in files)
              CoilField(
                label: Text(file),
                description: Text(_sizes[file]!),
                orientation: CoilFieldOrientation.horizontal,
                child: CoilCheckbox(
                  value: _selected.contains(file),
                  onChanged: (value) => setState(() {
                    if (value!) {
                      _selected.add(file);
                    } else {
                      _selected.remove(file);
                    }
                  }),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatesTable extends StatefulWidget {
  const _StatesTable();

  @override
  State<_StatesTable> createState() => _StatesTableState();
}

class _StatesTableState extends State<_StatesTable> {
  bool? _mixed;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    Widget row(String label, Widget Function(CoilSize size) box) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.body)),
          for (final size in CoilSize.values)
            SizedBox(width: 72, child: Center(child: box(size))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            for (final size in CoilSize.values)
              SizedBox(
                width: 72,
                child: Center(
                  child: Text(
                    size == CoilSize.compact ? 'Compact' : 'Regular',
                    style: text.muted.caption,
                  ),
                ),
              ),
          ],
        ),
        row(
          'Unchecked',
          (size) => CoilCheckbox(
            value: false,
            size: size,
            semanticLabel: 'Unchecked',
            onChanged: (_) {},
          ),
        ),
        row(
          'Checked',
          (size) => CoilCheckbox(
            value: true,
            size: size,
            semanticLabel: 'Checked',
            onChanged: (_) {},
          ),
        ),
        row(
          'Mixed, tap to cycle',
          (size) => CoilCheckbox(
            value: _mixed,
            tristate: true,
            size: size,
            semanticLabel: 'Mixed',
            onChanged: (value) => setState(() => _mixed = value),
          ),
        ),
        row(
          'Invalid',
          (size) => CoilCheckbox(
            value: false,
            invalid: true,
            size: size,
            semanticLabel: 'Invalid',
            onChanged: (_) {},
          ),
        ),
        row(
          'Disabled',
          (size) => CoilCheckbox(
            value: false,
            size: size,
            semanticLabel: 'Disabled',
            onChanged: null,
          ),
        ),
        row(
          'Disabled, checked',
          (size) => CoilCheckbox(
            value: true,
            size: size,
            semanticLabel: 'Disabled, checked',
            onChanged: null,
          ),
        ),
      ],
    );
  }
}
