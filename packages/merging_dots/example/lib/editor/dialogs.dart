import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/code_export.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/templates.dart';
import 'package:merging_dots_example/editor/ui.dart';

Future<void> _showSheet(BuildContext context, Widget child) {
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Panel(child: child),
        ),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.trailing = const []});

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: EditorText.title)),
          ...trailing,
          const SizedBox(width: 6),
          ToolButton(
            icon: CupertinoIcons.xmark,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// A live view of the project's animation, at [size].
class ProjectPreview extends StatelessWidget {
  const ProjectPreview({required this.project, required this.size, super.key});

  final Project project;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
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
    );
  }
}

/// Shows the project as Dart and JSON, ready to copy.
Future<void> showExportSheet(BuildContext context, Project project) =>
    _showSheet(context, _ExportSheet(project: project));

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.project});

  final Project project;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  var _format = 'dart';
  var _copied = false;
  late final _codeText = TextEditingController(text: _code);

  @override
  void dispose() {
    _codeText.dispose();
    super.dispose();
  }

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
    final hint = _format == 'dart'
        ? 'Paste this into your app. It only needs the merging_dots package.'
        : 'Load it with DotSequence.${widget.project.mode == DotMode.grid ? 'grid' : 'cloud'}FromJson, '
              'and the style with Dot${widget.project.mode == DotMode.grid ? 'Grid' : 'Cloud'}Style.fromJson(json["style"]). '
              'The editor can import it again too.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          title: 'Export "${widget.project.name}"',
          trailing: [
            Choice(
              value: _format,
              options: const {'dart': 'Dart', 'json': 'JSON'},
              onChanged: (format) => setState(() {
                _format = format;
                _codeText.text = _code;
              }),
            ),
            const SizedBox(width: 6),
            ToolButton(
              icon: _copied
                  ? CupertinoIcons.check_mark
                  : CupertinoIcons.doc_on_clipboard,
              label: _copied ? 'Copied' : 'Copy',
              prominent: true,
              onPressed: _copy,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final size in const [16.0, 24.0, 48.0, 96.0]) ...[
                ProjectPreview(project: widget.project, size: size),
                const SizedBox(width: 20),
              ],
              Expanded(child: Text(hint, style: EditorText.label)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: EditorColors.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: CupertinoTextField(
              controller: _codeText,
              readOnly: true,
              maxLines: null,
              expands: true,
              style: EditorText.code,
              padding: const EdgeInsets.all(16),
              decoration: null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Asks for JSON to open.
Future<void> showImportSheet(
  BuildContext context,
  EditorController controller,
) => _showSheet(context, _ImportSheet(controller: controller));

class _ImportSheet extends StatefulWidget {
  const _ImportSheet({required this.controller});

  final EditorController controller;

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          title: 'Import JSON',
          trailing: [
            ToolButton(label: 'Open', prominent: true, onPressed: _import),
          ],
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: CupertinoTextField(
              controller: _text,
              maxLines: null,
              minLines: 12,
              autofocus: true,
              placeholder: 'Paste JSON exported by the editor',
              style: EditorText.code,
              placeholderStyle: EditorText.code.copyWith(
                color: EditorColors.textTertiary,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EditorColors.canvas,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              error,
              style: EditorText.label.copyWith(color: const Color(0xFFFF5C39)),
            ),
          ),
      ],
    );
  }
}

/// Saved projects and templates to open.
Future<void> showLibrarySheet(
  BuildContext context,
  EditorController controller,
) => _showSheet(context, _LibrarySheet(controller: controller));

class _LibrarySheet extends StatelessWidget {
  const _LibrarySheet({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: 'Library',
            trailing: [
              ToolButton(
                icon: CupertinoIcons.add,
                label: 'New',
                onPressed: () {
                  controller.newProject();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                const Text('SAVED', style: EditorText.section),
                const SizedBox(height: 10),
                if (controller.library.isEmpty)
                  const Text(
                    'Nothing saved yet. Save a project from the top bar and it shows up here.',
                    style: EditorText.label,
                  )
                else
                  _ProjectGrid(
                    projects: controller.library,
                    onOpen: (project) {
                      controller.open(project);
                      Navigator.of(context).pop();
                    },
                    onDelete: controller.deleteFromLibrary,
                  ),
                const SizedBox(height: 24),
                const Text('TEMPLATES', style: EditorText.section),
                const SizedBox(height: 10),
                _ProjectGrid(
                  projects: templates,
                  onOpen: (project) {
                    controller.open(project);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final project in projects)
          GestureDetector(
            onTap: () => onOpen(project),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EditorColors.raised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EditorColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: ProjectPreview(project: project, size: 96)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EditorText.value,
                          ),
                        ),
                        if (onDelete != null)
                          GestureDetector(
                            onTap: () => onDelete!(project),
                            child: const Icon(
                              CupertinoIcons.trash,
                              size: 14,
                              color: EditorColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${project.mode == DotMode.grid ? 'Grid' : 'Freeform'} · '
                      '${project.frameCount} frame${project.frameCount == 1 ? '' : 's'}',
                      style: EditorText.label,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
