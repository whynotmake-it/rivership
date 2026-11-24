import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const breadcrumbEntry = CatalogEntry(
  slug: 'breadcrumb',
  title: 'Breadcrumb',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'The trail to the current page, folding its middle into a menu.',
  page: BreadcrumbPage.new,
);

/// A folder, or a file when it has no [children] and a [size].
class _Entry {
  const _Entry(this.name, {this.children, this.size});

  final String name;
  final List<_Entry>? children;
  final String? size;

  bool get isFolder => children != null;
}

const _home = _Entry(
  'Home',
  children: [
    _Entry(
      'Documents',
      children: [
        _Entry('Contracts', children: []),
        _Entry('Taxes', children: []),
        _Entry('resume.pdf', size: '84 KB'),
      ],
    ),
    _Entry(
      'Projects',
      children: [
        _Entry(
          'Coil',
          children: [
            _Entry(
              'Design',
              children: [
                _Entry(
                  'Tokens',
                  children: [
                    _Entry(
                      'Colors',
                      children: [
                        _Entry('neutrals.json', size: '3 KB'),
                        _Entry('brand.json', size: '2 KB'),
                      ],
                    ),
                    _Entry(
                      'Spacing',
                      children: [_Entry('scale.json', size: '1 KB')],
                    ),
                    _Entry('tokens.json', size: '12 KB'),
                  ],
                ),
                _Entry('Specs', children: []),
                _Entry('principles.md', size: '6 KB'),
              ],
            ),
            _Entry(
              'Source',
              children: [
                _Entry('button.dart', size: '9 KB'),
                _Entry('table.dart', size: '21 KB'),
              ],
            ),
          ],
        ),
        _Entry('Rivership', children: []),
      ],
    ),
    _Entry('Pictures', children: []),
  ],
);

class BreadcrumbPage extends StatefulWidget {
  const BreadcrumbPage({super.key});

  @override
  State<BreadcrumbPage> createState() => _BreadcrumbPageState();
}

enum _Width {
  full('Full'),
  medium('Medium'),
  narrow('Narrow');

  const _Width(this.label);

  final String label;

  double? get width => switch (this) {
    full => null,
    medium => 360,
    narrow => 260,
  };
}

class _BreadcrumbPageState extends State<BreadcrumbPage> {
  var _width = _Width.narrow;
  var _icon = false;
  var _slash = false;

  static const _trail = [
    'Home',
    'Projects',
    'Coil',
    'Design system',
    'Tokens',
    'Colors',
    'Neutrals',
    'Dark mode',
  ];

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Breadcrumb',
    summary:
        'The trail to the current page. Every crumb except the last one is a '
        'link, and when the trail runs out of room its middle folds into a '
        'menu.',
    hero: const _FileBrowser(),
    usage: '''
CoilBreadcrumb(
  crumbs: [
    for (final (i, folder) in path.indexed)
      CoilCrumb(
        label: Text(folder),
        onPressed: i == path.length - 1 ? null : () => open(i),
      ),
  ],
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Crumbs are links in the native Tab order, and Enter follows one or '
            'opens the menu behind the "…" button.',
      ),
      CatalogNote(
        'Touch',
        'On a phone the trail keeps the first crumb, the "…" button, and the '
            'last two, and every crumb keeps a 44 px hit target.',
      ),
      CatalogNote(
        'Pointer',
        'One highlight glides smoothly between crumbs. A long name truncates '
            'in the trail and reads in full in the menu.',
      ),
      CatalogNote(
        'Screen readers',
        'The trail is a navigation region labeled Breadcrumb, and the '
            'current page is plain text marked as selected.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description:
            'Narrow the row and the middle crumbs collapse into a "…" menu, '
            'keeping the first crumb, the last link and the current page.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Width',
              value: _width,
              values: _Width.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _width = v),
            ),
            DemoControl.toggle(
              label: 'Home icon',
              value: _icon,
              onChanged: (v) => setState(() => _icon = v),
            ),
            DemoControl.toggle(
              label: 'Slash separator',
              value: _slash,
              onChanged: (v) => setState(() => _slash = v),
            ),
          ],
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: _width.width ?? double.infinity,
            child: CoilBreadcrumb(
              separator: _slash
                  ? Text('/', style: CoilTheme.textOf(context).muted.body)
                  : null,
              crumbs: [
                for (final (i, name) in _trail.indexed)
                  CoilCrumb(
                    label: Text(name),
                    leading: i == 0 && _icon
                        ? const CatalogIcon(Glyph.home)
                        : null,
                    onPressed: i == _trail.length - 1 ? null : () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// A file browser: the crumbs navigate the folder shown below them.
class _FileBrowser extends StatefulWidget {
  const _FileBrowser();

  @override
  State<_FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<_FileBrowser> {
  var _path = const ['Home', 'Projects', 'Coil', 'Design', 'Tokens'];

  _Entry get _folder {
    var folder = _home;
    for (final name in _path.skip(1)) {
      folder = folder.children!.firstWhere((entry) => entry.name == name);
    }
    return folder;
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final entries = _folder.children!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoilBreadcrumb(
          crumbs: [
            for (final (i, name) in _path.indexed)
              CoilCrumb(
                label: Text(name),
                leading: i == 0 ? const CatalogIcon(Glyph.home) : null,
                onPressed: i == _path.length - 1
                    ? null
                    : () => setState(() => _path = _path.sublist(0, i + 1)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('This folder is empty.', style: text.muted.body),
            ),
          )
        else
          CoilCardGroup(
            children: [
              for (final entry in entries)
                CoilCard(
                  key: ValueKey((_path, entry.name)),
                  variant: CoilCardVariant.inline,
                  icon: CatalogIcon(
                    entry.isFolder ? Glyph.folder : Glyph.fileText,
                  ),
                  title: Text(entry.name),
                  description: entry.isFolder
                      ? Text(
                          switch (entry.children!.length) {
                            0 => 'Empty',
                            1 => '1 item',
                            final count => '$count items',
                          },
                        )
                      : Text(entry.size!),
                  onPressed: entry.isFolder
                      ? () => setState(() => _path = [..._path, entry.name])
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}
