import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/icons.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// The floating toolbar under the canvas: tools, history, grid size and
/// playback, each with its keyboard shortcut in the tooltip.
class Toolbar extends StatelessWidget {
  const Toolbar({required this.controller, required this.onLibrary, super.key});

  final EditorController controller;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final project = controller.project;
        final grid = project.mode == DotMode.grid;
        final current = controller.currentGrid;
        return Panel(
          padding: const EdgeInsets.all(4),
          child: CoilTooltipGroup(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolButton(
                    glyph: Glyph.library,
                    tooltip: 'Library',
                    shortcut: 'G',
                    onPressed: onLibrary,
                  ),
                  const _Divider(),
                  if (grid) ...[
                    for (final (tool, glyph, label, key) in const [
                      (GridTool.flip, Glyph.flip, 'Flip cells', 'F'),
                      (GridTool.draw, Glyph.draw, 'Draw, only adds ink', 'D'),
                      (
                        GridTool.erase,
                        Glyph.erase,
                        'Erase, only removes ink',
                        'E',
                      ),
                    ])
                      _ToolButton(
                        glyph: glyph,
                        tooltip: label,
                        shortcut: key,
                        selected: controller.gridTool == tool,
                        onPressed: () => controller.setGridTool(tool),
                      ),
                    _ToolButton(
                      glyph: Glyph.symmetry,
                      tooltip: 'Symmetry: ${controller.symmetry.name}',
                      shortcut: 'X',
                      selected: controller.symmetry != Symmetry.off,
                      onPressed: () => controller.setSymmetry(
                        Symmetry.values[(controller.symmetry.index + 1) %
                            Symmetry.values.length],
                      ),
                    ),
                  ] else
                    for (final (tool, glyph, label, key) in const [
                      (CloudTool.add, Glyph.add, 'Add dots', 'A'),
                      (CloudTool.move, Glyph.move, 'Select and move', 'V'),
                    ])
                      _ToolButton(
                        glyph: glyph,
                        tooltip: label,
                        shortcut: key,
                        selected: controller.cloudTool == tool,
                        onPressed: () => controller.setCloudTool(tool),
                      ),
                  const _Divider(),
                  _ToolButton(
                    glyph: Glyph.undo,
                    tooltip: 'Undo',
                    shortcut: 'Ctrl+Z',
                    onPressed: controller.canUndo ? controller.undo : null,
                  ),
                  _ToolButton(
                    glyph: Glyph.redo,
                    tooltip: 'Redo',
                    shortcut: 'Shift+Ctrl+Z',
                    onPressed: controller.canRedo ? controller.redo : null,
                  ),
                  if (grid) ...[
                    const _Divider(),
                    _ToolButton(
                      glyph: Glyph.minus,
                      tooltip: 'Fewer cells',
                      shortcut: '[',
                      onPressed: () => controller.stepGridSize(-1),
                    ),
                    SizedBox(
                      width: 48,
                      child: RoleText(
                        '${current.columns}×${current.rows}',
                        align: TextAlign.center,
                        muted: true,
                      ),
                    ),
                    _ToolButton(
                      glyph: Glyph.plus,
                      tooltip: 'More cells',
                      shortcut: ']',
                      onPressed: () => controller.stepGridSize(1),
                    ),
                    const _Divider(),
                    _ToolButton(
                      glyph: Glyph.invert,
                      tooltip: 'Invert cells',
                      shortcut: 'I',
                      onPressed: controller.invertFrame,
                    ),
                  ],
                  _ToolButton(
                    glyph: Glyph.clear,
                    tooltip: 'Clear',
                    shortcut: '⌫',
                    onPressed: controller.clearFrame,
                  ),
                  const _Divider(),
                  _ToolButton(
                    glyph: controller.playing ? Glyph.pause : Glyph.play,
                    tooltip: controller.playing ? 'Pause' : 'Play',
                    shortcut: 'Space',
                    selected: controller.playing,
                    onPressed: project.frameCount < 2
                        ? null
                        : () => controller.setPlaying(
                            playing: !controller.playing,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.shortcut,
    this.selected = false,
  });

  final Glyph glyph;
  final String tooltip;
  final String? shortcut;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shortcut = this.shortcut;
    return CoilTooltip(
      message: Text(tooltip),
      shortcut: shortcut == null ? null : CoilKbd(shortcut),
      child: CoilButton.icon(
        variant: selected ? CoilButtonVariant.primary : CoilButtonVariant.ghost,
        semanticLabel: tooltip,
        icon: GlyphIcon(glyph),
        onPressed: onPressed,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: CoilTheme.of(context).colors.border,
    );
  }
}
