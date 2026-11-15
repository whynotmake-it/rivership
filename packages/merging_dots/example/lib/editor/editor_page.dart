import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:merging_dots_example/editor/canvas.dart';
import 'package:merging_dots_example/editor/dialogs.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/inspector.dart';
import 'package:merging_dots_example/editor/timeline.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// The merging dots editor: draw dots on a grid or freely, animate them
/// over frames, save them and export them as Dart or JSON.
class MergingDotsEditor extends StatefulWidget {
  const MergingDotsEditor({super.key, this.controller});

  /// The editor's state. Created and restored from storage when null.
  final EditorController? controller;

  @override
  State<MergingDotsEditor> createState() => _MergingDotsEditorState();
}

class _MergingDotsEditorState extends State<MergingDotsEditor> {
  late final EditorController controller;
  var _narrowTab = 0;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? (EditorController()..restore());
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await controller.saveToLibrary();
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Saved'),
        content: Text('"${controller.project.name}" is in your library.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            controller.undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            controller.redo,
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (controller.project.frameCount > 1) {
            controller.setPlaying(playing: !controller.playing);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: EditorColors.canvas,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                return Column(
                  children: [
                    _TopBar(
                      controller: controller,
                      compact: constraints.maxWidth < 640,
                      onSave: _save,
                    ),
                    Expanded(child: wide ? _wide() : _narrow()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _wide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 260,
            child: Panel(child: ToolsPanel(controller: controller)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: EditorCanvas(controller: controller)),
                Timeline(controller: controller),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 280,
            child: Panel(child: SettingsPanel(controller: controller)),
          ),
        ],
      ),
    );
  }

  Widget _narrow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: EditorCanvas(controller: controller)),
          Timeline(controller: controller),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _narrowTab,
            backgroundColor: EditorColors.surface,
            thumbColor: EditorColors.control,
            children: const {
              0: Text('Draw', style: EditorText.value),
              1: Text('Animate', style: EditorText.value),
            },
            onValueChanged: (tab) => setState(() => _narrowTab = tab ?? 0),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 4,
            child: Panel(
              child: _narrowTab == 0
                  ? ToolsPanel(controller: controller)
                  : SettingsPanel(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.compact,
    required this.onSave,
  });

  final EditorController controller;
  final bool compact;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            if (!compact) ...[
              const Text('Merging Dots', style: EditorText.title),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _NameField(controller: controller),
                ),
              ),
            ),
            ToolButton(
              icon: CupertinoIcons.arrow_uturn_left,
              tooltip: 'Undo',
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            const SizedBox(width: 4),
            ToolButton(
              icon: CupertinoIcons.arrow_uturn_right,
              tooltip: 'Redo',
              onPressed: controller.canRedo ? controller.redo : null,
            ),
            const SizedBox(width: 12),
            ToolButton(
              icon: CupertinoIcons.square_grid_2x2,
              label: compact ? null : 'Library',
              onPressed: () => showLibrarySheet(context, controller),
            ),
            const SizedBox(width: 6),
            ToolButton(
              icon: CupertinoIcons.arrow_down_doc,
              label: compact ? null : 'Import',
              onPressed: () => showImportSheet(context, controller),
            ),
            const SizedBox(width: 6),
            ToolButton(
              icon: CupertinoIcons.floppy_disk,
              label: compact ? null : 'Save',
              onPressed: onSave,
            ),
            const SizedBox(width: 6),
            ToolButton(
              icon: CupertinoIcons.chevron_left_slash_chevron_right,
              label: 'Export',
              prominent: true,
              onPressed: () => showExportSheet(context, controller.project),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.controller});

  final EditorController controller;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _text = TextEditingController(
    text: widget.controller.project.name,
  );

  @override
  void didUpdateWidget(_NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final name = widget.controller.project.name;
    if (_text.text != name) _text.text = name;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return CupertinoTextField(
      controller: _text,
      style: EditorText.value.copyWith(fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: EditorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EditorColors.border),
      ),
      onSubmitted: widget.controller.rename,
      onTapOutside: (_) {
        if (_text.text != widget.controller.project.name) {
          widget.controller.rename(_text.text);
        }
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }
}
