import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/dialog_page.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const contextMenuEntry = CatalogEntry(
  slug: 'context-menu',
  title: 'ContextMenu',
  group: CatalogGroup.menusAndOverlays,
  summary: 'The dropdown at a point: right-click, Shift+F10 or long-press.',
  page: ContextMenuPage.new,
);

class _File {
  const _File(this.name, this.detail, this.glyph, {this.starred = false});

  final String name;
  final String detail;
  final Glyph glyph;
  final bool starred;

  _File copyWith({String? name, bool? starred}) => _File(
    name ?? this.name,
    detail,
    glyph,
    starred: starred ?? this.starred,
  );
}

const _initialFiles = [
  _File('Brand guidelines.pdf', '4.2 MB · Edited today', Glyph.book),
  _File('Launch photos', '18 items · Edited yesterday', Glyph.folder),
  _File('Homepage hero.png', '1.8 MB · Edited Nov 14', Glyph.image),
  _File('Roadmap.md', '12 KB · Edited Nov 9', Glyph.book),
];

class ContextMenuPage extends StatelessWidget {
  const ContextMenuPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'ContextMenu',
    summary:
        'The dropdown opened at a point. Right-click a file, or long-press '
        'it on touch; the file lifts under the finger.',
    hero: const _FileList(),
    usage: '''
CoilContextMenu(
  entries: [
    CoilAction(
      label: const Text('Rename…'),
      onPressed: () => rename(file),
    ),
    CoilAction(
      label: const Text('Duplicate'),
      onPressed: () => duplicate(file),
    ),
    const CoilMenuSeparator(),
    CoilAction(
      label: const Text('Delete'),
      tone: CoilActionTone.destructive,
      onPressed: () => delete(file),
    ),
  ],
  child: FileRow(file),
)''',
    notes: const [
      CatalogNote(
        'Pointer',
        'Right-click, or Control-click on macOS, opens the menu at the '
            'pointer. The menu is a dropdown, so submenus, search and marks '
            'all work.',
      ),
      CatalogNote(
        'Keyboard',
        'Shift+F10 or the Menu key opens it at the focused element. Arrows, '
            'typeahead and Esc work as in a dropdown.',
      ),
      CatalogNote(
        'Touch',
        'A 500 ms long press lifts the element (scale 1.02, one level more '
            'shadow) with a haptic, then opens an anchored menu of up to 8 '
            'rows, else a sheet.',
      ),
      CatalogNote(
        "Do / Don't",
        'Never make a context menu the only path to an action. Offer a '
            'visible More button too, as the rows above do.',
      ),
    ],
    children: [
      DemoSection(
        title: 'On a focused button',
        description:
            'Any focusable widget works. Tab to the button and press '
            'Shift+F10.',
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilContextMenu(
            entries: [
              CoilAction(
                label: const Text('Copy link'),
                searchText: 'Copy link',
                leading: const CatalogIcon(Glyph.link),
                onPressed: () {},
              ),
              CoilAction(
                label: const Text('Download'),
                searchText: 'Download',
                leading: const CatalogIcon(Glyph.download),
                onPressed: () {},
              ),
            ],
            child: CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () {},
              child: const Text('Brand guidelines.pdf'),
            ),
          ),
        ),
      ),
    ],
  );
}

class _FileList extends StatefulWidget {
  const _FileList();

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  var _files = _initialFiles;

  Future<void> _rename(int index) async {
    final name = await showRenameDialog(
      context: context,
      title: 'Rename file',
      name: _files[index].name,
    );
    if (name == null || !mounted) return;
    setState(() {
      _files = [
        for (final (i, file) in _files.indexed)
          if (i == index) file.copyWith(name: name) else file,
      ];
    });
  }

  void _duplicate(int index) => setState(() {
    final file = _files[index];
    final dot = file.name.lastIndexOf('.');
    final copy = dot > 0
        ? '${file.name.substring(0, dot)} copy${file.name.substring(dot)}'
        : '${file.name} copy';
    _files = [..._files]..insert(index + 1, file.copyWith(name: copy));
  });

  void _toggleStar(int index) => setState(() {
    _files = [
      for (final (i, file) in _files.indexed)
        if (i == index) file.copyWith(starred: !file.starred) else file,
    ];
  });

  void _delete(int index) => setState(() {
    _files = [..._files]..removeAt(index);
  });

  List<CoilMenuEntry> _entries(int index) => [
    CoilAction(
      label: const Text('Rename…'),
      searchText: 'Rename',
      leading: const CatalogIcon(Glyph.pencil),
      onPressed: () => _rename(index),
    ),
    CoilAction(
      label: const Text('Duplicate'),
      searchText: 'Duplicate',
      leading: const CatalogIcon(Glyph.copy),
      onPressed: () => _duplicate(index),
    ),
    CoilAction(
      label: const Text('Starred'),
      searchText: 'Starred',
      leading: const CatalogIcon(Glyph.star),
      mark: CoilActionMark.check,
      selected: _files[index].starred,
      onPressed: () => _toggleStar(index),
    ),
    const CoilMenuSeparator(),
    CoilAction(
      label: const Text('Delete'),
      searchText: 'Delete',
      leading: const CatalogIcon(Glyph.trash),
      tone: CoilActionTone.destructive,
      onPressed: () => _delete(index),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    if (_files.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 16),
          Text('No files', style: text.body),
          const SizedBox(height: 2),
          Text('Everything was deleted.', style: text.muted.caption),
          const SizedBox(height: 16),
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => setState(() => _files = _initialFiles),
            child: const Text('Restore files'),
          ),
          const SizedBox(height: 16),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, file) in _files.indexed)
          CoilContextMenu(
            key: ObjectKey(file),
            entries: _entries(i),
            child: _FileRow(
              file: file,
              trailing: CoilDropdown(
                entries: _entries(i),
                builder: (context, menu) => CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  semanticLabel: 'More actions for ${file.name}',
                  icon: const CatalogIcon(Glyph.more),
                  onPressed: menu.open,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.trailing});

  final _File file;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconTheme.merge(
            data: IconThemeData(
              color: CoilTheme.of(context).colors.mutedForeground,
            ),
            child: CatalogIcon(file.glyph),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        file.name,
                        style: text.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (file.starred) ...[
                      const SizedBox(width: 6),
                      const IconTheme(
                        data: IconThemeData(size: 14),
                        child: CatalogIcon(Glyph.star),
                      ),
                    ],
                  ],
                ),
                Text(
                  file.detail,
                  style: text.muted.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
