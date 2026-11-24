import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:coil_example/src/widgets/shortcut.dart';
import 'package:flutter/widgets.dart';

const commandMenuEntry = CatalogEntry(
  slug: 'command-menu',
  title: 'CommandMenu',
  group: CatalogGroup.menusAndOverlays,
  summary: 'A searchable list of an app’s commands, usually bound to ⌘K.',
  page: CommandMenuPage.new,
);

class _OpenCommandMenuIntent extends Intent {
  const _OpenCommandMenuIntent();
}

enum _View {
  inbox('Inbox', Glyph.inbox),
  projects('Projects', Glyph.folder),
  settings('Settings', Glyph.settings);

  const _View(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

class CommandMenuPage extends StatefulWidget {
  const CommandMenuPage({super.key});

  @override
  State<CommandMenuPage> createState() => _CommandMenuPageState();
}

class _CommandMenuPageState extends State<CommandMenuPage> {
  var _view = _View.inbox;
  final _projects = ['Website', 'Mobile app'];

  void _setThemeMode(CatalogThemeMode mode) {
    final settings = CatalogSettingsScope.maybeOf(context);
    if (settings != null) settings.themeMode = mode;
  }

  List<CoilMenuEntry> get _entries => [
    const CoilMenuLabel(Text('Go to')),
    for (final view in _View.values)
      CoilAction(
        label: Text(view.label),
        searchText: 'Go to ${view.label}',
        leading: CatalogIcon(view.glyph),
        onPressed: () => setState(() => _view = view),
      ),
    const CoilMenuLabel(Text('Create')),
    CoilAction(
      label: const Text('New project'),
      searchText: 'New project create',
      leading: const CatalogIcon(Glyph.plus),
      onPressed: () => setState(() {
        _projects.add('Project ${_projects.length + 1}');
        _view = _View.projects;
      }),
    ),
    const CoilMenuLabel(Text('Theme')),
    CoilAction(
      label: const Text('Light'),
      searchText: 'Theme light',
      leading: const CatalogIcon(Glyph.sun),
      onPressed: () => _setThemeMode(CatalogThemeMode.light),
    ),
    CoilAction(
      label: const Text('Dark'),
      searchText: 'Theme dark',
      leading: const CatalogIcon(Glyph.moon),
      onPressed: () => _setThemeMode(CatalogThemeMode.dark),
    ),
    CoilAction(
      label: const Text('System'),
      searchText: 'Theme system',
      leading: const CatalogIcon(Glyph.monitor),
      onPressed: () => _setThemeMode(CatalogThemeMode.system),
    ),
  ];

  Future<void> _open(BuildContext context) =>
      showCoilCommandMenu(context: context, entries: _entries);

  String get _pressHint => CoilTheme.tierOf(context) == CoilTier.touch
      ? ''
      : ' Press ${shortcutOf(context, 'K')} on this page.';

  @override
  Widget build(BuildContext context) {
    final apple = usesCommandKey(context);
    // The shell binds ⌘K to the catalog's own search; closer to the focus,
    // this page's binding wins while the page has it.
    return Shortcuts(
      shortcuts: {
        CharacterActivator('k', meta: apple, control: !apple):
            const _OpenCommandMenuIntent(),
      },
      child: Actions(
        actions: {
          _OpenCommandMenuIntent: CallbackAction<_OpenCommandMenuIntent>(
            onInvoke: (_) => unawaited(_open(context)),
          ),
        },
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          child: CatalogPage(
            title: 'CommandMenu',
            summary:
                'The command menu puts one search over everything the app '
                'can do, from going somewhere to creating something or '
                'changing a setting.$_pressHint',
            hero: _AppFrame(
              view: _view,
              projects: _projects,
              onOpen: () => unawaited(_open(context)),
            ),
            usage: '''
await showCoilCommandMenu(
  context: context,
  entries: [
    const CoilMenuLabel(Text('Go to')),
    CoilAction(label: const Text('Inbox'), onPressed: openInbox),
    CoilAction(label: const Text('Projects'), onPressed: openProjects),
    const CoilMenuLabel(Text('Create')),
    CoilAction(label: const Text('New project'), onPressed: newProject),
  ],
);''',
            notes: const [
              CatalogNote(
                'Keyboard',
                'Up and Down wrap around the list and skip disabled rows, '
                    'and Enter runs the highlighted command. Esc first '
                    'clears the search and then closes the menu. An '
                    'app-wide key such as ⌘K belongs to the app itself, in '
                    'a Shortcuts widget at its root.',
              ),
              CatalogNote(
                'Filtering',
                'Each command is matched word by word against its '
                    'searchText rather than fuzzily, and a group with no '
                    'matches is hidden.',
              ),
              CatalogNote(
                'Touch',
                'On a phone the menu opens as a full-height sheet with the '
                    'field focused, and the shortcut caps and the footer are '
                    'dropped. Touch has no keyboard shortcut, so give the '
                    'app a visible search button like the one in the header '
                    'above.',
              ),
              CatalogNote(
                'Motion',
                'The panel springs to the height of the current results as '
                    'you type, and the highlight glides from row to row.',
              ),
              CatalogNote(
                'Screen readers',
                'The field is announced as a combobox and reports a live '
                    'count of the matching commands.',
              ),
            ],
            children: const [],
          ),
        ),
      ),
    );
  }
}

/// A miniature app: a header with a search trigger, and a view that the
/// commands change.
class _AppFrame extends StatelessWidget {
  const _AppFrame({
    required this.view,
    required this.projects,
    required this.onOpen,
  });

  final _View view;
  final List<String> projects;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Acme', style: text.title)),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              leading: const CatalogIcon(Glyph.search),
              trailing: touch ? null : CoilKbd(shortcutOf(context, 'K')),
              onPressed: onOpen,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(view.label, style: text.subtitle),
        const SizedBox(height: 4),
        switch (view) {
          _View.inbox => Text(
            'You’re all caught up.',
            style: text.muted.body,
          ),
          _View.projects => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final project in projects)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(project, style: text.body),
                ),
            ],
          ),
          _View.settings => Text(
            'Theme, notifications and members live here.',
            style: text.muted.body,
          ),
        },
      ],
    );
  }
}
