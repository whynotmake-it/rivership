import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/code_export.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/icons.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/templates.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// A live view of a project's animation at [size].
class ProjectPreview extends StatelessWidget {
  const ProjectPreview({required this.project, required this.size, super.key});

  final Project project;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconTheme.merge(
      data: IconThemeData(color: CoilTheme.of(context).colors.foreground),
      child: SizedBox.square(
        dimension: size,
        child: switch (project.mode) {
          DotMode.grid => DotGridView.sequence(
            sequence: project.grid,
            style: project.gridStyle,
          ),
          DotMode.cloud => DotCloudView.sequence(
            sequence: project.cloud,
            style: project.cloudStyle,
          ),
        },
      ),
    );
  }
}

/// Shows the project as Dart and JSON, ready to copy.
Future<void> showExportDialog(BuildContext context, Project project) =>
    showCoilDialog<void>(
      context: context,
      builder: (context) => _ExportDialog(project: project),
    );

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.project});

  final Project project;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  var _format = 'dart';
  var _copied = false;

  String get _code => _format == 'dart'
      ? CodeExport.dart(widget.project)
      : CodeExport.json(widget.project);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.project.mode == DotMode.grid;
    final theme = CoilTheme.of(context);
    return CoilDialog(
      size: CoilDialogSize.lg,
      title: Text('Export "${widget.project.name}"'),
      description: Text(
        _format == 'dart'
            ? 'Paste this into your app. It only needs the merging_dots '
                  'package.'
            : 'Load it with DotSequence.${grid ? 'grid' : 'cloud'}FromJson '
                  'and Dot${grid ? 'Grid' : 'Cloud'}Style.fromJson. The '
                  'editor can import it again too.',
      ),
      onClose: () => Navigator.of(context).pop(),
      actions: [
        CoilButton(
          leading: GlyphIcon(_copied ? Glyph.check : Glyph.copy),
          onPressed: _copy,
          child: Text(_copied ? 'Copied' : 'Copy'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final size in const [16.0, 24.0, 48.0, 96.0]) ...[
                ProjectPreview(project: widget.project, size: size),
                const SizedBox(width: 16),
              ],
              const Spacer(),
              Segmented(
                value: _format,
                options: const {'dart': 'Dart', 'json': 'JSON'},
                onChanged: (format) => setState(() => _format = format),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: theme.colors.muted,
              borderRadius: BorderRadius.circular(
                CoilTheme.radiiOf(context).item,
              ),
            ),
            child: CoilScrollArea(
              padding: const EdgeInsets.all(16),
              child: Text(
                _code,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  height: 1.5,
                  color: theme.colors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for JSON to open.
Future<void> showImportDialog(
  BuildContext context,
  EditorController controller,
) => showCoilDialog<void>(
  context: context,
  kind: CoilDialogKind.form,
  builder: (context) => _ImportDialog(controller: controller),
);

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.controller});

  final EditorController controller;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _import() {
    final error = widget.controller.importJson(_text.text);
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return CoilDialog(
      size: CoilDialogSize.lg,
      title: const Text('Import JSON'),
      description: const Text(
        'Paste a project or an animation exported from the editor.',
      ),
      actions: [
        CoilButton(
          variant: CoilButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CoilButton(onPressed: _import, child: const Text('Open')),
      ],
      child: CoilField(
        invalid: error != null,
        error: error == null ? null : Text(error),
        child: CoilInput.multiline(
          controller: _text,
          autofocus: true,
          minLines: 8,
          maxLines: 14,
          placeholder: const Text('{"kind": "grid", ...}'),
          invalid: error != null,
        ),
      ),
    );
  }
}

/// Saved projects and templates to open.
Future<void> showLibraryDialog(
  BuildContext context,
  EditorController controller,
) => showCoilDialog<void>(
  context: context,
  builder: (context) => _LibraryDialog(controller: controller),
);

class _LibraryDialog extends StatelessWidget {
  const _LibraryDialog({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    void open(Project project) {
      controller.open(project);
      Navigator.of(context).pop();
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => CoilDialog(
        size: CoilDialogSize.xl,
        title: const Text('Library'),
        description: const Text(
          'Start from a template, or open a project you saved.',
        ),
        onClose: () => Navigator.of(context).pop(),
        actions: [
          CoilButton(
            variant: CoilButtonVariant.secondary,
            leading: const GlyphIcon(Glyph.plus),
            onPressed: () {
              controller.newProject();
              Navigator.of(context).pop();
            },
            child: const Text('New project'),
          ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: CoilScrollArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RoleText.caption('Saved'),
                const SizedBox(height: 8),
                if (controller.library.isEmpty)
                  const RoleText.body(
                    'Nothing saved yet. Save a project and it shows up here.',
                    muted: true,
                  )
                else
                  _ProjectGrid(
                    projects: controller.library,
                    onOpen: open,
                    onDelete: controller.deleteFromLibrary,
                  ),
                const SizedBox(height: 24),
                const RoleText.caption('Templates'),
                const SizedBox(height: 8),
                _ProjectGrid(projects: templates, onOpen: open),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({
    required this.projects,
    required this.onOpen,
    this.onDelete,
  });

  final List<Project> projects;
  final ValueChanged<Project> onOpen;
  final ValueChanged<Project>? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final project in projects)
          Semantics(
            button: true,
            label: project.name,
            child: GestureDetector(
              onTap: () => onOpen(project),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 156,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: radius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: ProjectPreview(project: project, size: 96)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RoleText(
                              project.name,
                              emphasis: true,
                              maxLines: 1,
                            ),
                          ),
                          if (onDelete case final onDelete?)
                            CoilButton.icon(
                              variant: CoilButtonVariant.ghost,
                              size: CoilSize.compact,
                              semanticLabel: 'Delete ${project.name}',
                              icon: const GlyphIcon(Glyph.clear),
                              onPressed: () => onDelete(project),
                            ),
                        ],
                      ),
                      RoleText.caption(
                        '${project.mode == DotMode.grid ? 'Grid' : 'Freeform'}'
                        ' · ${project.frameCount} '
                        'frame${project.frameCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
