import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const dialogEntry = CatalogEntry(
  slug: 'dialog',
  title: 'Dialog',
  group: CatalogGroup.menusAndOverlays,
  summary: 'A modal panel for confirmations and short forms.',
  page: DialogPage.new,
);

/// A dialog that is a route of its own, declared in the router like any
/// page: its URL opens it, and back or the scrim pops it.
final dialogRouteDef = NamedRouteDef(
  name: 'coil:dialog-rename',
  path: '${dialogEntry.path}/rename',
  type: RouteType.custom(
    customRouteBuilder: <T>(context, child, page) => CoilModalRoute<T>(
      context: context,
      settings: page,
      presentation: CoilDialogKind.form.presentation,
      builder: (_) => child,
    ),
  ),
  builder: (context, data) =>
      const RenameDialog(title: 'Rename project', initialName: 'Website'),
);

/// Asks for a new name for [name] in a form dialog; resolves to the
/// trimmed name, or null when cancelled.
Future<String?> showRenameDialog({
  required BuildContext context,
  required String title,
  required String name,
}) => showCoilDialog<String>(
  context: context,
  kind: CoilDialogKind.form,
  builder: (context) => RenameDialog(title: title, initialName: name),
);

/// Asks to confirm deleting [name]; resolves to true when confirmed.
Future<bool> showDeleteDialog({
  required BuildContext context,
  required String name,
}) async {
  final confirmed = await showCoilDialog<bool>(
    context: context,
    builder: (context) => CoilDialog(
      title: Text('Delete $name?'),
      description: const Text(
        'Its pages and history go with it. This can’t be undone.',
      ),
      actions: [
        CoilButton(
          variant: CoilButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        CoilButton(
          variant: CoilButtonVariant.destructive,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete project'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A form dialog with one name field, shared by the examples on this page
/// and the ones that rename things.
class RenameDialog extends StatefulWidget {
  const RenameDialog({
    required this.title,
    required this.initialName,
    super.key,
  });

  final String title;
  final String initialName;

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => CoilDialog(
    title: Text(widget.title),
    onClose: () => Navigator.pop(context),
    actions: [
      CoilButton(
        variant: CoilButtonVariant.secondary,
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => CoilButton(
          onPressed: _controller.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ),
    ],
    child: CoilField(
      label: const Text('Name'),
      child: CoilInput(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _save(),
      ),
    ),
  );
}

class _Project {
  const _Project(this.name, this.detail);

  final String name;
  final String detail;
}

const _initialProjects = [
  _Project('Website', '24 pages · Edited today'),
  _Project('Mobile app', '9 pages · Edited yesterday'),
  _Project('Design system', '61 pages · Edited Nov 12'),
];

enum _Kind {
  confirmation('Confirmation', CoilDialogKind.confirmation),
  form('Form', CoilDialogKind.form);

  const _Kind(this.label, this.kind);

  final String label;
  final CoilDialogKind kind;
}

class DialogPage extends StatefulWidget {
  const DialogPage({super.key});

  @override
  State<DialogPage> createState() => _DialogPageState();
}

class _DialogPageState extends State<DialogPage> {
  var _kind = _Kind.confirmation;
  var _size = CoilDialogSize.sm;
  var _closeButton = false;

  Future<void> _open() => showCoilDialog<void>(
    context: context,
    kind: _kind.kind,
    builder: (context) => switch (_kind) {
      _Kind.confirmation => CoilDialog(
        size: _size,
        title: const Text('Discard draft?'),
        description: const Text(
          'Your changes to the release notes will be lost.',
        ),
        onClose: _closeButton ? () => Navigator.pop(context) : null,
        actions: [
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep editing'),
          ),
          CoilButton(
            variant: CoilButtonVariant.destructive,
            onPressed: () => Navigator.pop(context),
            child: const Text('Discard draft'),
          ),
        ],
      ),
      _Kind.form => CoilDialog(
        size: _size,
        title: const Text('Invite a teammate'),
        description: const Text('They get an email with a link to join.'),
        onClose: _closeButton ? () => Navigator.pop(context) : null,
        actions: [
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CoilButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Send invite'),
          ),
        ],
        child: const CoilField(
          label: Text('Email'),
          child: CoilInput(
            placeholder: Text('ada@example.com'),
            keyboardType: TextInputType.emailAddress,
          ),
        ),
      ),
    },
  );

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Dialog',
    summary:
        'A dialog puts a panel over a scrim for decisions that need an '
        'answer before the user continues. A confirmation stays centered '
        'on every screen, while a form turns into a sheet on phones.',
    hero: const _ProjectList(),
    usage: '''
final confirmed = await showCoilDialog<bool>(
  context: context,
  builder: (context) => CoilDialog(
    title: const Text('Delete Website?'),
    description: const Text('Its pages and history go with it.'),
    actions: [
      CoilButton(
        variant: CoilButtonVariant.secondary,
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      CoilButton(
        variant: CoilButtonVariant.destructive,
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Delete project'),
      ),
    ],
  ),
);''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Focus stays inside the dialog and starts on the first field, or on '
            'the primary button in a confirmation. Esc closes it and focus '
            'returns to whatever opened it.',
      ),
      CatalogNote(
        'Touch',
        'A short confirmation stays centered with its buttons stacked at '
            'full width, while a form on a phone becomes a sheet that can be '
            'dragged away, with its actions pinned below.',
      ),
      CatalogNote(
        'Motion',
        'The scrim fades in while the panel blurs in from 97% scale. A '
            'dialog that is not dismissible ignores taps on the scrim, the '
            'back button, and the sheet drag.',
      ),
      CatalogNote(
        'Screen readers',
        'The dialog is a modal route that keeps screen reader focus inside '
            'the dialog, and its title is read as its name.',
      ),
      CatalogNote(
        "Do / Don't",
        'Name the outcome on the confirm button, such as "Delete project" '
            'instead of "OK". Avoid nesting dialogs, and on a phone push a '
            'page inside a sheet rather than opening a dialog from it.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Kind',
              value: _kind,
              values: _Kind.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _kind = v),
            ),
            DemoControl.choice(
              label: 'Size',
              value: _size,
              values: const [CoilDialogSize.sm, CoilDialogSize.lg],
              labelOf: (v) => v.name,
              onChanged: (v) => setState(() => _size = v),
            ),
            DemoControl.toggle(
              label: 'Close button',
              value: _closeButton,
              onChanged: (v) => setState(() => _closeButton = v),
            ),
          ],
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => unawaited(_open()),
            child: const Text('Open dialog'),
          ),
        ),
      ),
      DemoSection(
        title: 'As a route',
        description:
            'The dialog is declared in the router like a page, so its URL '
            'opens it and the back button or a tap on the scrim closes it.',
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => unawaited(
              context.router.push(NamedRoute(dialogRouteDef.name)),
            ),
            child: const Text('Rename project'),
          ),
        ),
      ),
    ],
  );
}

/// Projects you can rename in a form dialog or delete after a destructive
/// confirmation.
class _ProjectList extends StatefulWidget {
  const _ProjectList();

  @override
  State<_ProjectList> createState() => _ProjectListState();
}

class _ProjectListState extends State<_ProjectList> {
  var _projects = _initialProjects;

  Future<void> _rename(_Project project) async {
    final name = await showRenameDialog(
      context: context,
      title: 'Rename project',
      name: project.name,
    );
    if (name == null || !mounted) return;
    setState(() {
      _projects = [
        for (final p in _projects)
          if (p == project) _Project(name, p.detail) else p,
      ];
    });
  }

  Future<void> _delete(_Project project) async {
    final confirmed = await showDeleteDialog(
      context: context,
      name: project.name,
    );
    if (!confirmed || !mounted) return;
    setState(() => _projects = [..._projects]..remove(project));
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    if (_projects.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 16),
          Text('No projects', style: text.body),
          const SizedBox(height: 2),
          Text('You deleted every project.', style: text.muted.caption),
          const SizedBox(height: 16),
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => setState(() => _projects = _initialProjects),
            child: const Text('Restore projects'),
          ),
          const SizedBox(height: 16),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final project in _projects)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: text.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        project.detail,
                        style: text.muted.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                CoilTooltip(
                  message: const Text('Rename'),
                  child: CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    semanticLabel: 'Rename ${project.name}',
                    icon: const CatalogIcon(Glyph.pencil),
                    onPressed: () => unawaited(_rename(project)),
                  ),
                ),
                CoilTooltip(
                  message: const Text('Delete'),
                  child: CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    semanticLabel: 'Delete ${project.name}',
                    icon: const CatalogIcon(Glyph.trash),
                    onPressed: () => unawaited(_delete(project)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
