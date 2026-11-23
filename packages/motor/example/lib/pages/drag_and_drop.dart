import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Reordering a list by dragging its rows.
class DragAndDropPage extends StatefulWidget {
  const DragAndDropPage({super.key});

  @override
  State<DragAndDropPage> createState() => _DragAndDropPageState();
}

const _code =
    '// Rows fly to their new places; MotionReorderable says where a drop\n'
    '// would land and opens a real gap there.\n'
    'MotionLayoutGroup(\n'
    '  motion: motion.standard,\n'
    '  child: MotionReorderable<String>(\n'
    '    items: items,\n'
    '    onMove: (move) => setState(() {\n'
    '      items\n'
    '        ..remove(move.item)\n'
    '        ..insert(move.index, move.item!);\n'
    '    }),\n'
    '    builder: (context, drop) => Column(\n'
    '      children: [\n'
    '        for (final item in items) ...[\n'
    '          if (drop?.before == item) MotionDropGap(child: Well()),\n'
    '          MotionReorderableItem(\n'
    '            key: ValueKey(item),\n'
    '            item: item,\n'
    '            child: MotionDraggable<String>(\n'
    '              data: item,\n'
    '              id: item,\n'
    '              start: touch ? .longPress : .immediate,\n'
    '              motion: motion.gentle,\n'
    '              childWhenDragging: (_, _) => SizedBox.shrink(),\n'
    '              child: Row(item),\n'
    '            ),\n'
    '          ),\n'
    '        ],\n'
    '        if (drop != null && drop.before == null) MotionDropGap(child: Well()),\n'
    '      ],\n'
    '    ),\n'
    '  ),\n'
    ')';

class _DragAndDropPageState extends State<DragAndDropPage> {
  final _items = ['Springs', 'Curves', 'Tracks', 'Phases', 'Converters'];
  final _snippet = ValueNotifier(_code);

  @override
  void dispose() {
    _snippet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Drag and drop'),
      lead:
          'Drag a row to reorder the list. On a touch screen, press and hold '
          'first. A gap opens where it will land, the other rows make room, '
          'and the row you drop lands on a spring.',
      code: _snippet,
      stageHeight: 360,
      stage: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const .all(16),
            child: MotionLayoutGroup(
              motion: CoilTheme.motionOf(context).standard,
              child: MotionReorderable<String>(
                items: _items,
                debugLabel: 'Reorderable list',
                // The index counts after the item has left its old place.
                onMove: (move) => setState(() {
                  _items
                    ..remove(move.item)
                    ..insert(move.index, move.item!);
                }),
                builder: (context, drop) => Column(
                  mainAxisSize: .min,
                  children: [
                    for (final item in _items) ...[
                      if (drop?.before == item)
                        const MotionDropGap(child: _Well()),
                      MotionReorderableItem<String>(
                        // Keyed by item, so a row keeps its state in any slot.
                        key: ValueKey(item),
                        item: item,
                        child: _DraggableRow(item),
                      ),
                    ],
                    if (drop != null && drop.before == null)
                      const MotionDropGap(child: _Well()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that drags: at once with a pointer, after a long press on touch,
/// where the page scrolls.
class _DraggableRow extends StatelessWidget {
  const _DraggableRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return MotionDraggable<String>(
      data: label,
      id: label,
      debugLabel: 'Row $label',
      start: CoilTheme.tierOf(context) == CoilTier.touch
          ? MotionDragStart.longPress
          : MotionDragStart.immediate,
      motion: CoilTheme.motionOf(context).gentle,
      transitions: (drag) => switch (drag.phase) {
        MotionDragPhase.dragging => [
          MotionDraggableTrack.scale([.to(1.02)]),
        ],
        _ => const [],
      },
      // The row under the finger, lifted off the list.
      feedback: (context, drag) => _Row(label, lifted: true),
      childWhenDragging: (context, size) => const SizedBox.shrink(),
      child: _Row(label),
    );
  }
}

// Rows carry their own spacing, so a row that leaves takes it along.
const _spacing = 8.0;

class _Row extends StatelessWidget {
  const _Row(this.label, {this.lifted = false});

  final String label;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const .only(bottom: _spacing),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.surface(4),
          shadows: lifted ? colors.shadow(3) : null,
          shape: RoundedSuperellipseBorder(
            borderRadius: .circular(radii.item),
            side: BorderSide(color: colors.border),
          ),
        ),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const .symmetric(horizontal: 12),
            child: Row(
              spacing: metrics.gap,
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: metrics.iconSize,
                    color: colors.mutedForeground,
                  ),
                  child: const GlyphIcon(Glyph.gripVertical),
                ),
                Expanded(child: Text(label, style: text.body)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The room a drop opens: a pressed well the size of a row.
class _Well extends StatelessWidget {
  const _Well();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    return Padding(
      padding: const .only(bottom: _spacing),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.active,
          shape: RoundedSuperellipseBorder(
            borderRadius: .circular(radii.item),
            side: BorderSide(color: colors.border),
          ),
        ),
        child: const SizedBox(height: 44),
      ),
    );
  }
}
