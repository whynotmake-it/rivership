import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

const settingsDialogEntry = CatalogEntry(
  slug: 'settings-dialog',
  title: 'SettingsDialog',
  group: CatalogGroup.shellAndComposites,
  summary: 'A sidebar of sections inside a dialog.',
  page: SettingsDialogPage.new,
);

class SettingsDialogPage extends StatelessWidget {
  const SettingsDialogPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'SettingsDialog',
    summary:
        'A sidebar that never folds, inside an xl dialog. Below 600 wide a '
        'select picks the section; on a phone it opens as a sheet.',
    children: [
      DemoSection(
        title: 'Settings',
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Builder(
            builder: (context) => CoilButton(
              variant: CoilButtonVariant.secondary,
              leading: const CatalogIcon(Glyph.settings),
              onPressed: () => showDemoSettings(context),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> showDemoSettings(BuildContext context) =>
    showCoilSettingsDialog<String>(
      context: context,
      title: const Text('Settings'),
      sections: [
        CoilSettingsSection(
          value: 'general',
          label: const Text('General'),
          icon: const CatalogIcon(Glyph.settings),
          description: const Text('Workspace name, language and region.'),
          builder: (context) => const _General(),
        ),
        CoilSettingsSection(
          value: 'notifications',
          label: const Text('Notifications'),
          icon: const CatalogIcon(Glyph.bell),
          description: const Text('What reaches your inbox, and when.'),
          builder: (context) => const _Notifications(),
        ),
        CoilSettingsSection(
          value: 'appearance',
          label: const Text('Appearance'),
          icon: const CatalogIcon(Glyph.palette),
          description: const Text('Theme and density on this device.'),
          builder: (context) => const _Appearance(),
        ),
        CoilSettingsSection(
          value: 'security',
          label: const Text('Security'),
          icon: const CatalogIcon(Glyph.shield),
          description: const Text('Sign-in protection and active sessions.'),
          builder: (context) => const _Security(),
        ),
        CoilSettingsSection(
          value: 'members',
          label: const Text('Members'),
          icon: const CatalogIcon(Glyph.users),
          description: const Text('Who can open this workspace.'),
          builder: (context) => const _Members(),
        ),
      ],
    );

class _General extends StatefulWidget {
  const _General();

  @override
  State<_General> createState() => _GeneralState();
}

class _GeneralState extends State<_General> {
  var _language = 'en';

  @override
  Widget build(BuildContext context) => CoilSettingsList(
    children: [
      CoilSettingRow(
        label: const Text('Language'),
        description: const Text('Used for the interface and emails.'),
        trailing: SizedBox(
          width: 180,
          child: CoilSelect<String>(
            value: _language,
            onChanged: (value) => setState(() => _language = value),
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
              CoilOption(value: 'ja', label: Text('日本語'), searchText: '日本語'),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Switches extends StatefulWidget {
  const _Switches(this.rows);

  final List<(String, String, bool)> rows;

  @override
  State<_Switches> createState() => _SwitchesState();
}

class _SwitchesState extends State<_Switches> {
  late final _on = [for (final (_, _, on) in widget.rows) on];

  @override
  Widget build(BuildContext context) => CoilSettingsList(
    children: [
      for (final (i, (label, line, _)) in widget.rows.indexed)
        CoilSettingRow(
          label: Text(label),
          description: Text(line),
          trailing: CoilSwitch(
            value: _on[i],
            semanticLabel: label,
            onChanged: (value) => setState(() => _on[i] = value),
          ),
        ),
    ],
  );
}

class _Notifications extends StatelessWidget {
  const _Notifications();

  @override
  Widget build(BuildContext context) => const _Switches([
    ('Daily digest', 'One email each morning with what changed.', true),
    ('Mentions', 'When someone mentions you.', true),
    ('Product updates', 'New features, once a month at most.', false),
  ]);
}

class _Appearance extends StatefulWidget {
  const _Appearance();

  @override
  State<_Appearance> createState() => _AppearanceState();
}

class _AppearanceState extends State<_Appearance> {
  var _theme = 'system';

  @override
  Widget build(BuildContext context) => CoilSettingsList(
    children: [
      CoilSettingRow(
        label: const Text('Theme'),
        description: const Text('Follows the system unless you pick one.'),
        trailing: SizedBox(
          width: 180,
          child: CoilSelect<String>(
            value: _theme,
            onChanged: (value) => setState(() => _theme = value),
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
  );
}

class _Security extends StatelessWidget {
  const _Security();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Switches([
        (
          'Two-factor authentication',
          'A code from your authenticator app at sign-in.',
          true,
        ),
        ('New sign-in alerts', 'Email when a new device signs in.', true),
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
  const _Members();

  @override
  Widget build(BuildContext context) => CoilSettingsList(
    children: [
      for (final (name, email) in const [
        ('Jane Doe', 'jane@acme.com'),
        ('Sam Park', 'sam@acme.com'),
        ('Ravi Patel', 'ravi@acme.com'),
      ])
        CoilSettingRow(
          label: Text(name),
          description: Text(email),
          trailing: CoilButton(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            onPressed: () {},
            child: const Text('Member'),
          ),
        ),
    ],
  );
}
