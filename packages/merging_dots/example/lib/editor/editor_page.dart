import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/canvas.dart';
import 'package:merging_dots_example/editor/dialogs.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/icons.dart';
import 'package:merging_dots_example/editor/panels.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/toolbar.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// The merging dots editor: draw dots on a grid or place them freely,
/// animate them over frames, save them and export them as Dart or JSON.
///
/// It is built with coil, and follows the nearest `CoilTheme`, or the
/// platform's brightness without one.
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
    await showCoilDialog<void>(
      context: context,
      builder: (context) => CoilDialog(
        title: const Text('Saved'),
        description: Text('"${controller.project.name}" is in your library.'),
        actions: [
          CoilButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _library() => showLibraryDialog(context, controller);

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final grid = controller.project.mode == DotMode.grid;
    final shortcuts = <ShortcutActivator, VoidCallback>{
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
      const SingleActivator(LogicalKeyboardKey.keyG): _library,
      const SingleActivator(LogicalKeyboardKey.backspace):
          controller.clearFrame,
      if (grid) ...{
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            controller.setGridTool(GridTool.flip),
        const SingleActivator(LogicalKeyboardKey.keyD): () =>
            controller.setGridTool(GridTool.draw),
        const SingleActivator(LogicalKeyboardKey.keyE): () =>
            controller.setGridTool(GridTool.erase),
        const SingleActivator(LogicalKeyboardKey.keyX): () =>
            controller.setSymmetry(
              Symmetry.values[(controller.symmetry.index + 1) %
                  Symmetry.values.length],
            ),
        const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
            controller.stepGridSize(-1),
        const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
            controller.stepGridSize(1),
        const SingleActivator(LogicalKeyboardKey.keyI): controller.invertFrame,
      } else ...{
        const SingleActivator(LogicalKeyboardKey.keyA): () =>
            controller.setCloudTool(CloudTool.add),
        const SingleActivator(LogicalKeyboardKey.keyV): () =>
            controller.setCloudTool(CloudTool.move),
      },
    };
    // Typing a name must not trigger single-key shortcuts.
    return {
      for (final MapEntry(:key, :value) in shortcuts.entries)
        key: () {
          if (_typing) return;
          value();
        },
    };
  }

  bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) =>
          CallbackShortcuts(bindings: _shortcuts, child: child!),
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: CoilTheme.of(context).colors.background,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                return Column(
                  children: [
                    _TopBar(
                      controller: controller,
                      compact: constraints.maxWidth < 640,
                      onLibrary: _library,
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

  Widget _stage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: EditorCanvas(controller: controller)),
        Center(
          child: Toolbar(controller: controller, onLibrary: _library),
        ),
      ],
    );
  }

  Widget _wide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 220,
            child: Panel(child: FramesPanel(controller: controller)),
          ),
          Expanded(child: _stage()),
          SizedBox(
            width: 320,
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
          Expanded(flex: 5, child: _stage()),
          const SizedBox(height: 8),
          Segmented(
            value: _narrowTab,
            options: const {0: 'Frames', 1: 'Style and motion'},
            onChanged: (tab) => setState(() => _narrowTab = tab),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 4,
            child: Panel(
              child: _narrowTab == 0
                  ? FramesPanel(controller: controller)
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
    required this.onLibrary,
    required this.onSave,
  });

  final EditorController controller;
  final bool compact;
  final VoidCallback onLibrary;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const _Logo(),
          const SizedBox(width: 10),
          if (!compact) ...[
            const RoleText.title('Merging Dots'),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: _NameField(controller: controller),
              ),
            ),
          ),
          CoilButton(
            variant: CoilButtonVariant.ghost,
            leading: const GlyphIcon(Glyph.library),
            onPressed: onLibrary,
            child: const Text('Library'),
          ),
          if (!compact) ...[
            CoilButton(
              variant: CoilButtonVariant.ghost,
              leading: const GlyphIcon(Glyph.import),
              onPressed: () => showImportDialog(context, controller),
              child: const Text('Import'),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              leading: const GlyphIcon(Glyph.save),
              onPressed: onSave,
              child: const Text('Save'),
            ),
          ],
          const SizedBox(width: 8),
          CoilButton(
            leading: const GlyphIcon(Glyph.export),
            onPressed: () => showExportDialog(context, controller.project),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
}

/// The app mark: a small dot grid that breathes.
class _Logo extends StatelessWidget {
  const _Logo();

  static final _sequence = DotSequence<DotGrid>([
    DotKeyframe(
      DotGrid.parse('''
          ##
          #.
        '''),
      hold: const Duration(milliseconds: 1600),
    ),
    DotKeyframe(
      DotGrid.parse('''
          .#
          ##
        '''),
      hold: const Duration(milliseconds: 1600),
    ),
  ], motion: const CupertinoMotion(duration: Duration(milliseconds: 500)));

  @override
  Widget build(BuildContext context) {
    return IconTheme.merge(
      data: IconThemeData(color: CoilTheme.of(context).colors.foreground),
      child: SizedBox.square(
        dimension: 22,
        child: DotGridView.sequence(
          sequence: _sequence,
          style: const DotGridStyle.tiles(),
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
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  void _sync() {
    final name = widget.controller.project.name;
    if (!_focus.hasFocus && _text.text != name) _text.text = name;
  }

  void _commit() {
    if (_text.text != widget.controller.project.name) {
      widget.controller.rename(_text.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoilInput(
      controller: _text,
      focusNode: _focus,
      placeholder: const Text('Project name'),
      onSubmitted: (_) => _commit(),
    );
  }
}
