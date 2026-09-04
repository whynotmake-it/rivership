import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

const _routeName = 'Drag Reorder';

class DragReorderListPage extends StatefulWidget {
  const DragReorderListPage({super.key});
  static const routeName = _routeName;

  @override
  State<DragReorderListPage> createState() => _DragReorderListPageState();
}

class _DragReorderListPageState extends State<DragReorderListPage> {
  final List<_ItemData> items = List.generate(
    7,
    (i) => _ItemData(
      id: i,
      title: _titles[i % _titles.length],
      subtitle: _subtitles[i % _subtitles.length],
      icon: _icons[i % _icons.length],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: _routeName,
      description:
          'Vertical drag-to-reorder with MotionDraggable. Tiles return on a '
          'spring, and the drop gap opens with a SingleMotionBuilder.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(
          onPressed: () => setState(items.shuffle),
          child: const Text('Shuffle'),
        ),
      ),
      child: Surface(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ExampleTheme.surfaceRadius),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ReorderableItem(
                key: ValueKey(item.id),
                item: item,
                showDivider: index != items.length - 1,
                onAccept: (draggedId) => _reorder(draggedId, index),
              );
            },
          ),
        ),
      ),
    );
  }

  void _reorder(int draggedId, int targetIndex) {
    setState(() {
      final oldIndex = items.indexWhere((e) => e.id == draggedId);
      if (oldIndex == -1 || oldIndex == targetIndex) return;
      final item = items.removeAt(oldIndex);
      items.insert(targetIndex, item);
    });
  }
}

class _ReorderableItem extends StatelessWidget {
  const _ReorderableItem({
    required this.item,
    required this.onAccept,
    required this.showDivider,
    super.key,
  });

  final _ItemData item;
  final bool showDivider;
  final void Function(int draggedId) onAccept;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final tile = _ItemTile(item: item, showDivider: showDivider);

    return MotionDraggable<int>(
      axis: Axis.vertical,
      data: item.id,
      feedbackMatchesConstraints: true,
      onlyReturnWhenCanceled: false,
      childWhenDragging: const SizedBox.shrink(),
      feedback: _DragFeedback(child: _ItemTile(item: item, showDivider: false)),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidate, rejected) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleMotionBuilder(
              motion: const CupertinoMotion.smooth(),
              value: candidate.isNotEmpty ? 1.0 : 0.0,
              builder: (context, value, child) => SizedBox.fromSize(
                size: Size.fromHeight(value.clamp(0, 1) * 60),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.fog,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                  child: Center(
                    child: Text(
                      'Drop here',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            tile,
          ],
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Transform.scale(
        scale: 1 + value * 0.02,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surfaceSolid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
            boxShadow: t.softShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.showDivider});

  final _ItemData item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        border: showDivider
            ? Border(bottom: BorderSide(color: t.border))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.fog, shape: BoxShape.circle),
              child: Icon(item.icon, size: 18, color: t.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(color: t.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.line_horizontal_3,
              color: t.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemData {
  const _ItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final int id;
  final String title;
  final String subtitle;
  final IconData icon;
}

const _titles = [
  'Position spring',
  'Opacity fade',
  'Scale bounce',
  'Rotation snap',
  'Color tint',
  'Blur radius',
  'Padding shift',
];

const _subtitles = [
  'CupertinoMotion.smooth',
  'CupertinoMotion.bouncy',
  'CupertinoMotion.snappy',
  'CupertinoMotion.interactive',
  'Motion.curved',
  'SpringMotion',
  'Motion.linear',
];

const _icons = [
  CupertinoIcons.location_fill,
  CupertinoIcons.sun_max_fill,
  CupertinoIcons.resize,
  CupertinoIcons.rotate_right_fill,
  CupertinoIcons.paintbrush_fill,
  CupertinoIcons.circle_grid_hex_fill,
  CupertinoIcons.square_on_square,
];
