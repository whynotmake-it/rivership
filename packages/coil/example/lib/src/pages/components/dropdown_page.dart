import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:coil_example/src/widgets/shortcut.dart';
import 'package:flutter/widgets.dart';

const dropdownEntry = CatalogEntry(
  slug: 'dropdown',
  title: 'Dropdown',
  group: CatalogGroup.menusAndOverlays,
  summary: 'A menu of actions, with marks, shortcuts, submenus and search.',
  page: DropdownPage.new,
);

const _projects = ['Website', 'Mobile app', 'Design system', 'Archive'];

const _teammates = [
  'Ada Lovelace',
  'Alan Turing',
  'Barbara Liskov',
  'Dennis Ritchie',
  'Edsger Dijkstra',
  'Grace Hopper',
  'Hedy Lamarr',
  'Katherine Johnson',
  'Margaret Hamilton',
  'Radia Perlman',
];

enum _Presentation {
  automatic('Auto', null),
  popover('Popover', CoilPresentation.popover),
  sheet('Sheet', CoilPresentation.sheet);

  const _Presentation(this.label, this.presentation);

  final String label;
  final CoilPresentation? presentation;
}

class DropdownPage extends StatefulWidget {
  const DropdownPage({super.key});

  @override
  State<DropdownPage> createState() => _DropdownPageState();
}

class _DropdownPageState extends State<DropdownPage> {
  var _presentation = _Presentation.automatic;
  String? _assignee;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Dropdown',
    summary:
        'A dropdown opens a menu of actions from any trigger you build. '
        'Hovering a submenu row opens it beside the menu, and on touch a '
        'submenu drills in and replaces the rows.',
    hero: const _DocumentToolbar(),
    usage: '''
CoilDropdown(
  entries: [
    CoilAction(label: const Text('Duplicate'), onPressed: duplicate),
    CoilSubmenu(label: const Text('Move to'), entries: projectActions),
    const CoilMenuSeparator(),
    CoilAction(
      label: const Text('Move to trash'),
      tone: CoilActionTone.destructive,
      onPressed: trash,
    ),
  ],
  builder: (context, menu) => CoilButton.icon(
    variant: CoilButtonVariant.ghost,
    semanticLabel: 'More',
    icon: Icon(LucideIcons.ellipsis),
    onPressed: menu.open,
  ),
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'The arrow keys loop through the rows and skip disabled ones, while '
            'Home, End and typing jump straight to a row. Enter or Space '
            'runs a row, Right opens a submenu, Left or Esc closes one level '
            'and Tab closes the whole menu.',
      ),
      CatalogNote(
        'Pointer',
        'A submenu opens after 100 ms of hover, and moving diagonally toward '
            'it lets the pointer cross other rows without closing it. The '
            'highlight glides from row to row.',
      ),
      CatalogNote(
        'Touch',
        'A short menu stays anchored to its trigger, while a menu with '
            'search, more than 8 rows or nested submenus opens as a sheet. '
            'Tapping a submenu there drills in and leaves a row to go back.',
      ),
      CatalogNote(
        'Motion',
        'A checkable row stays visible for 300 ms so its mark can be seen '
            'before the menu closes, while a plain action closes at once. '
            'The page behind already accepts input during that moment.',
      ),
    ],
    children: [
      DemoSection(
        title: 'With search',
        description:
            'Typing filters the rows by word prefix. A pointer menu focuses '
            'the search field right away, while a sheet on a phone leaves it '
            'unfocused so the keyboard stays down.',
        child: Row(
          children: [
            CoilDropdown(
              search: const CoilMenuSearch(
                placeholder: Text('Search teammates'),
                semanticLabel: 'Search teammates',
              ),
              entries: [
                for (final name in _teammates)
                  CoilAction(
                    label: Text(name),
                    searchText: name,
                    mark: CoilActionMark.radio,
                    selected: _assignee == name,
                    onPressed: () => setState(() => _assignee = name),
                  ),
              ],
              builder: (context, menu) => CoilButton(
                variant: CoilButtonVariant.secondary,
                trailing: const CatalogIcon(Glyph.chevronsUpDown),
                onPressed: menu.open,
                child: const Text('Assign to'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _assignee ?? 'Unassigned',
                style: CoilTheme.textOf(context).muted.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Presentation',
        description:
            'The menu decides between a popover and a sheet when it opens, '
            'based on the window; set presentation to pin it to one of the '
            'two.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Presentation',
              value: _presentation,
              values: _Presentation.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _presentation = v),
            ),
          ],
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilDropdown(
            presentation: _presentation.presentation,
            entries: [
              const CoilMenuLabel(Text('Sort by')),
              for (final key in ['Name', 'Date modified', 'Size'])
                CoilAction(
                  label: Text(key),
                  searchText: key,
                  mark: CoilActionMark.radio,
                  selected: key == 'Name',
                  onPressed: () {},
                ),
            ],
            builder: (context, menu) => CoilButton(
              variant: CoilButtonVariant.secondary,
              leading: const CatalogIcon(Glyph.sort),
              onPressed: menu.open,
              child: const Text('Sort'),
            ),
          ),
        ),
      ),
    ],
  );
}

/// A document's toolbar: its title and where it lives, with a "More" menu
/// that moves, favorites, duplicates and trashes it for real.
class _DocumentToolbar extends StatefulWidget {
  const _DocumentToolbar();

  @override
  State<_DocumentToolbar> createState() => _DocumentToolbarState();
}

class _DocumentToolbarState extends State<_DocumentToolbar> {
  var _project = _projects.first;
  var _favorite = false;
  var _copies = 0;
  var _trashed = false;

  List<CoilMenuEntry> _entries(BuildContext context) => [
    CoilAction(
      label: const Text('Favorite'),
      searchText: 'Favorite',
      leading: const CatalogIcon(Glyph.star),
      mark: CoilActionMark.check,
      selected: _favorite,
      onPressed: () => setState(() => _favorite = !_favorite),
    ),
    CoilAction(
      label: const Text('Duplicate'),
      searchText: 'Duplicate',
      leading: const CatalogIcon(Glyph.copy),
      shortcut: CoilKbd(shortcutOf(context, 'D')),
      onPressed: () => setState(() => _copies++),
    ),
    CoilSubmenu(
      label: const Text('Move to'),
      searchText: 'Move to',
      leading: const CatalogIcon(Glyph.folder),
      entries: [
        const CoilMenuLabel(Text('Projects')),
        for (final project in _projects)
          CoilAction(
            label: Text(project),
            searchText: project,
            mark: CoilActionMark.radio,
            selected: _project == project,
            onPressed: () => setState(() => _project = project),
          ),
      ],
    ),
    CoilAction(
      label: const Text('Copy link'),
      searchText: 'Copy link',
      leading: const CatalogIcon(Glyph.link),
      shortcut: CoilKbd(shortcutOf(context, 'L', shift: true)),
      onPressed: () {},
    ),
    const CoilMenuSeparator(),
    CoilAction(
      label: const Text('Move to trash'),
      searchText: 'Move to trash',
      leading: const CatalogIcon(Glyph.trash),
      tone: CoilActionTone.destructive,
      onPressed: () => setState(() => _trashed = true),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final copies = _copies == 0
        ? ''
        : ' · $_copies ${_copies == 1 ? 'copy' : 'copies'}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _trashed ? 'Moved to trash' : 'Q4 launch plan',
                      style: text.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_favorite && !_trashed) ...[
                    const SizedBox(width: 8),
                    const IconTheme(
                      data: IconThemeData(size: 16),
                      child: CatalogIcon(Glyph.star),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _trashed ? 'Q4 launch plan' : 'In $_project$copies',
                style: text.muted.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (_trashed)
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => setState(() => _trashed = false),
            child: const Text('Undo'),
          )
        else ...[
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () {},
            child: const Text('Share'),
          ),
          const SizedBox(width: 4),
          CoilDropdown(
            entries: _entries(context),
            builder: (context, menu) => CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              semanticLabel: 'More',
              icon: const CatalogIcon(Glyph.more),
              onPressed: menu.open,
            ),
          ),
        ],
      ],
    );
  }
}
