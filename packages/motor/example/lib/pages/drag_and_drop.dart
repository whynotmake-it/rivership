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
    '// The builder lays out the list; MotionReorderable says where a drop\n'
    '// would land, and the rows fly aside by themselves.\n'
    'MotionReorderable<String>(\n'
    '  items: items,\n'
    '  onMove: (move) => setState(() {\n'
    '    items\n'
    '      ..remove(move.item)\n'
    '      ..insert(move.index, move.item!);\n'
    '  }),\n'
    '  builder: (context, drop) => Column(\n'
    '    children: [\n'
    '      for (final item in items) ...[\n'
    '        if (drop?.before == item) MotionDropGap(child: Slot()),\n'
    '        MotionReorderableItem(\n'
    '          item: item,\n'
    '          child: MotionDraggable<String>(\n'
    '            data: item,\n'
    '            childWhenDragging: (context, size) => SizedBox.shrink(),\n'
    '            child: Row(item),\n'
    '          ),\n'
    '        ),\n'
    '      ],\n'
    '      if (drop != null && drop.before == null) MotionDropGap(child: Slot()),\n'
    '    ],\n'
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
          'Drag a row to reorder the list. The row you drop lands on a '
          'spring, and the rows around it move aside on their own.',
      code: _snippet,
      stageHeight: 360,
      stage: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const .all(16),
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
                      const MotionDropGap(child: _Slot()),
                    MotionReorderableItem<String>(
                      item: item,
                      child: MotionDraggable<String>(
                        data: item,
                        debugLabel: 'Row $item',
                        childWhenDragging: (context, size) =>
                            const SizedBox.shrink(),
                        child: _Row(item),
                      ),
                    ),
                  ],
                  if (drop != null && drop.before == null)
                    const MotionDropGap(child: _Slot()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Rows carry their own spacing, so a row that leaves takes it along.
const _spacing = 8.0;

class _Row extends StatelessWidget {
  const _Row(this.label);

  final String label;

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

/// The room a drop opens, outlined where the row would land.
class _Slot extends StatelessWidget {
  const _Slot();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    return Padding(
      padding: const .only(bottom: _spacing),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.muted,
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
