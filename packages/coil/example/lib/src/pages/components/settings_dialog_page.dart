import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/sidebar_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const settingsDialogEntry = CatalogEntry(
  slug: 'settings-dialog',
  title: 'SettingsDialog',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A dialog that puts a sidebar of sections next to the setting rows for '
      'the section you picked.',
  page: SettingsDialogPage.new,
);

/// What the settings change, held above the dialog so it outlives the
/// panels and the app bar can show it.
class _Prefs extends ChangeNotifier {
  String name = 'Ada Lovelace';
  String language = 'en';
  String theme = 'system';
  final switches = <String, bool>{
    'digest': true,
    'mentions': true,
    'updates': false,
    'twoFactor': true,
    'alerts': true,
  };
  final roles = <String, String>{
    'Jane Doe': 'Admin',
    'Sam Park': 'Member',
    'Ravi Patel': 'Member',
  };

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }
}

class SettingsDialogPage extends StatefulWidget {
  const SettingsDialogPage({super.key});

  @override
  State<SettingsDialogPage> createState() => _SettingsDialogPageState();
}

class _SettingsDialogPageState extends State<SettingsDialogPage> {
  final _prefs = _Prefs();

  @override
  void dispose() {
    _prefs.dispose();
    super.dispose();
  }

  Future<void> _open([String section = 'account']) =>
      showCoilSettingsDialog<String>(
        context: context,
        title: const Text('Settings'),
        initialSection: section,
        sections: _sections(_prefs),
      );

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'SettingsDialog',
    summary:
        'An extra-large dialog with setting rows next to a sidebar of '
        'sections that never folds. Below 600 px wide a select takes over '
        'from the sidebar, and on a phone the whole thing opens as a sheet.',
    hero: _AppBar(prefs: _prefs, onOpen: _open),
    usage: '''
showCoilSettingsDialog<String>(
  context: context,
  title: const Text('Settings'),
  initialSection: 'notifications',
  sections: [
    CoilSettingsSection(
      value: 'notifications',
      label: const Text('Notifications'),
      icon: const Icon(LucideIcons.bell),
      description: const Text('What reaches your inbox.'),
      builder: (context) => CoilSettingsList(
        children: [
          CoilSettingRow(
            label: const Text('Mentions'),
            trailing: CoilSwitch(
              value: mentions,
              onChanged: setMentions,
            ),
          ),
        ],
      ),
    ),
  ],
)''',
    notes: const [
      CatalogNote(
        'Touch',
        'On a phone it opens as a sheet, where the title moves into the sheet '
            'header next to the single close button and a select underneath '
            'picks the section.',
      ),
      CatalogNote(
        'Pointer',
        'The sections sit in a static sidebar 208 px wide, so there is no '
            'rail, shortcut, or drawer here. The panel keeps its heading and '
            'description in place while its body scrolls.',
      ),
      CatalogNote(
        "Do / Don't",
        'Put a single control in each row. A whole toggle row is one tap '
            'target, while a row with a select, slider, or button responds '
            'only on the control itself.',
      ),
      CatalogNote(
        'Accessibility',
        'The title names the route and the close button sits in the corner. A '
            'toggle row reads as a single node, so a screen reader announces '
            'its label, description, and state together.',
      ),
    ],
    children: [
      DemoSection(
        title: 'The panel on its own',
        description:
            'CoilSettingsDialog is a plain widget, so you can put it in a '
            'CoilModalPage or inline in a page as it is here. Resize the '
            'window below 600 px to watch the select take over from the '
            'sidebar.',
        child: CoilSettingsDialog<String>(
          title: const Text('Settings'),
          initialSection: 'notifications',
          sections: _sections(_prefs),
        ),
      ),
    ],
  );
}

/// The signed-in app's top bar: the workspace, and three ways into the
/// settings.
class _AppBar extends StatelessWidget {
  const _AppBar({required this.prefs, required this.onOpen});

  final _Prefs prefs;
  final Future<void> Function([String section]) onOpen;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Row(
        spacing: 12,
        children: [
          const WorkspaceTile('A'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acme AI', style: text.title),
                Text(
                  prefs.name.isEmpty ? 'Signed in' : prefs.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.muted.caption,
                ),
              ],
            ),
          ),
          CoilButton.icon(
            variant: CoilButtonVariant.ghost,
            semanticLabel: 'Notification settings',
            icon: const CatalogIcon(Glyph.bell),
            onPressed: () => onOpen('notifications'),
          ),
          CoilDropdown(
            entries: [
              const CoilMenuLabel(Text('Ada Lovelace')),
              CoilAction(
                label: const Text('Settings'),
                searchText: 'Settings',
                leading: const CatalogIcon(Glyph.settings),
                onPressed: onOpen,
              ),
              CoilAction(
                label: const Text('Appearance'),
                searchText: 'Appearance',
                leading: const CatalogIcon(Glyph.palette),
                onPressed: () => onOpen('appearance'),
              ),
              const CoilMenuSeparator(),
              CoilAction(
                label: const Text('Log out'),
                searchText: 'Log out',
                leading: const CatalogIcon(Glyph.logOut),
                onPressed: () {},
              ),
            ],
            builder: (context, menu) => CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              semanticLabel: 'Account menu',
              icon: const CatalogIcon(Glyph.user),
              onPressed: menu.open,
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 600)
            CoilButton(
              variant: CoilButtonVariant.secondary,
              leading: const CatalogIcon(Glyph.settings),
              onPressed: onOpen,
              child: const Text('Settings'),
            )
          else
            CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              semanticLabel: 'Settings',
              icon: const CatalogIcon(Glyph.settings),
              onPressed: onOpen,
            ),
        ],
      ),
    );
  }
}

List<CoilSettingsSection<String>> _sections(_Prefs prefs) => [
  CoilSettingsSection(
    value: 'account',
    label: const Text('Account'),
    icon: const CatalogIcon(Glyph.user),
    description: const Text('How you appear to the rest of the workspace.'),
    builder: (context) => _Account(prefs),
  ),
  CoilSettingsSection(
    value: 'appearance',
    label: const Text('Appearance'),
    icon: const CatalogIcon(Glyph.palette),
    description: const Text('Theme on this device.'),
    builder: (context) => _Appearance(prefs),
  ),
  CoilSettingsSection(
    value: 'notifications',
    label: const Text('Notifications'),
    icon: const CatalogIcon(Glyph.bell),
    description: const Text('What reaches your inbox, and when.'),
    builder: (context) => _Switches(prefs, const [
      ('digest', 'Daily digest', 'One email each morning with what changed.'),
      ('mentions', 'Mentions', 'When someone mentions you.'),
      ('updates', 'Product updates', 'New features, once a month at most.'),
    ]),
  ),
  CoilSettingsSection(
    value: 'security',
    label: const Text('Security'),
    icon: const CatalogIcon(Glyph.shield),
    description: const Text('Sign-in protection and active sessions.'),
    builder: (context) => _Security(prefs),
  ),
  CoilSettingsSection(
    value: 'members',
    label: const Text('Members'),
    icon: const CatalogIcon(Glyph.users),
    description: const Text('Who can open this workspace.'),
    builder: (context) => _Members(prefs),
  ),
];

class _Account extends StatefulWidget {
  const _Account(this.prefs);

  final _Prefs prefs;

  @override
  State<_Account> createState() => _AccountState();
}

class _AccountState extends State<_Account> {
  late final _name = TextEditingController(text: widget.prefs.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.prefs,
    builder: (context, _) => CoilSettingsList(
      children: [
        CoilSettingRow(
          label: const Text('Display name'),
          description: const Text('Shown on your messages and comments.'),
          trailing: SizedBox(
            width: 180,
            child: CoilInput(
              controller: _name,
              semanticLabel: 'Display name',
              onChanged: (value) =>
                  widget.prefs.update(() => widget.prefs.name = value),
            ),
          ),
        ),
        CoilSettingRow(
          label: const Text('Language'),
          description: const Text('Used for the interface and emails.'),
          trailing: SizedBox(
            width: 180,
            child: CoilSelect<String>(
              value: widget.prefs.language,
              onChanged: (value) =>
                  widget.prefs.update(() => widget.prefs.language = value),
              options: const [
                CoilOption(
                  value: 'en',
                  label: Text('English'),
                  searchText: 'English',
                ),
                CoilOption(
                  value: 'fr',
                  label: Text('Français'),
                  searchText: 'Français',
                ),
                CoilOption(
                  value: 'de',
                  label: Text('Deutsch'),
                  searchText: 'Deutsch',
                ),
                CoilOption(
                  value: 'ja',
                  label: Text('日本語'),
                  searchText: '日本語',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Switches extends StatelessWidget {
  const _Switches(this.prefs, this.rows);

  final _Prefs prefs;
  final List<(String, String, String)> rows;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: prefs,
    builder: (context, _) => CoilSettingsList(
      children: [
        for (final (key, label, line) in rows)
          CoilSettingRow(
            label: Text(label),
            description: Text(line),
            trailing: CoilSwitch(
              value: prefs.switches[key]!,
              onChanged: (value) =>
                  prefs.update(() => prefs.switches[key] = value),
            ),
          ),
      ],
    ),
  );
}

class _Appearance extends StatelessWidget {
  const _Appearance(this.prefs);

  final _Prefs prefs;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: prefs,
    builder: (context, _) => CoilSettingsList(
      children: [
        CoilSettingRow(
          label: const Text('Theme'),
          description: const Text('Follows the system unless you pick one.'),
          trailing: SizedBox(
            width: 180,
            child: CoilSelect<String>(
              value: prefs.theme,
              onChanged: (value) => prefs.update(() => prefs.theme = value),
              options: const [
                CoilOption(
                  value: 'system',
                  label: Text('System'),
                  searchText: 'System',
                  icon: CatalogIcon(Glyph.monitor),
                ),
                CoilOption(
                  value: 'light',
                  label: Text('Light'),
                  searchText: 'Light',
                  icon: CatalogIcon(Glyph.sun),
                ),
                CoilOption(
                  value: 'dark',
                  label: Text('Dark'),
                  searchText: 'Dark',
                  icon: CatalogIcon(Glyph.moon),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Security extends StatelessWidget {
  const _Security(this.prefs);

  final _Prefs prefs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Switches(prefs, const [
        (
          'twoFactor',
          'Two-factor authentication',
          'A code from your authenticator app at sign-in.',
        ),
        ('alerts', 'New sign-in alerts', 'Email when a new device signs in.'),
      ]),
      CoilSettingRow(
        label: const Text('Active sessions'),
        description: const Text('3 devices are signed in right now.'),
        trailing: CoilButton(
          variant: CoilButtonVariant.secondary,
          size: CoilSize.compact,
          onPressed: () {},
          child: const Text('Sign out everywhere'),
        ),
      ),
    ],
  );
}

class _Members extends StatelessWidget {
  const _Members(this.prefs);

  final _Prefs prefs;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: prefs,
    builder: (context, _) => CoilSettingsList(
      children: [
        for (final (name, email) in const [
          ('Jane Doe', 'jane@acme.com'),
          ('Sam Park', 'sam@acme.com'),
          ('Ravi Patel', 'ravi@acme.com'),
        ])
          CoilSettingRow(
            label: Text(name),
            description: Text(email),
            trailing: SizedBox(
              width: 120,
              child: CoilSelect<String>(
                value: prefs.roles[name],
                onChanged: (value) =>
                    prefs.update(() => prefs.roles[name] = value),
                options: const [
                  CoilOption(
                    value: 'Admin',
                    label: Text('Admin'),
                    searchText: 'Admin',
                  ),
                  CoilOption(
                    value: 'Member',
                    label: Text('Member'),
                    searchText: 'Member',
                  ),
                  CoilOption(
                    value: 'Viewer',
                    label: Text('Viewer'),
                    searchText: 'Viewer',
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
