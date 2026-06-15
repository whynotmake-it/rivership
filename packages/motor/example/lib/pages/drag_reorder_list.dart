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
    12,
    (i) => _ItemData(
      id: i,
      title: _titles[i % _titles.length],
      subtitle: _subtitles[i % _subtitles.length],
      icon: _icons[i % _icons.length],
      colorIndex: i % 4,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return ExamplePage(
      title: _routeName,
      description:
          'MotionDraggable handles vertical reordering with spring-based '
          'return animations. Drag any tile to reorder — the gap animates '
          'in with SingleMotionBuilder.',
      action: Row(
        children: [
          IconBadge(
            icon: CupertinoIcons.arrow_up_arrow_down,
            color: t.accentBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${items.length} items · drag to reorder',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _shuffle,
            child: Text(
              'Shuffle',
              style: TextStyle(
                color: t.accentBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.borderSubtle),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: t.borderSubtle, width: 0.5),
                  ),
                ),
                child: const SizedBox(width: double.infinity),
              ),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ReorderableItem(
                key: ValueKey(item.id),
                item: item,
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

  void _shuffle() {
    setState(() => items.shuffle());
  }
}

class _ReorderableItem extends StatelessWidget {
  const _ReorderableItem({
    required this.item,
    required this.onAccept,
    super.key,
  });

  final _ItemData item;
  final void Function(int draggedId) onAccept;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final tile = _ItemTile(item: item);

    return MotionDraggable<int>(
      axis: Axis.vertical,
      data: item.id,
      feedbackMatchesConstraints: true,
      onlyReturnWhenCanceled: false,
      childWhenDragging: const SizedBox.shrink(),
      feedback: _DragFeedback(child: tile),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidateData, rejectedData) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleMotionBuilder(
              motion: const CupertinoMotion.smooth(),
              value: candidateData.isNotEmpty ? 1.0 : 0.0,
              builder: (context, value, child) => SizedBox.fromSize(
                size: Size.fromHeight(value.clamp(0, 1) * 64),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.accentBlue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: t.accentBlue.withValues(alpha: .24),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Drop here',
                      style: TextStyle(
                        color: t.accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
      builder: (context, value, _) => Transform.translate(
        offset: Offset(value * 8, -value * 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.accentBlue.withValues(alpha: .32)),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: value * .32),
                blurRadius: 24 * value,
                offset: Offset(0, 12 * value),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final _ItemData item;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final color = _colorFromIndex(t, item.colorIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconBadge(icon: item.icon, color: color),
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
                    fontWeight: FontWeight.w600,
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
    );
  }
}

Color _colorFromIndex(ExampleTheme t, int index) {
  return switch (index) {
    0 => t.accentBlue,
    1 => t.accentGreen,
    2 => t.accentPurple,
    3 => t.accentOrange,
    _ => t.accentBlue,
  };
}

class _ItemData {
  const _ItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorIndex,
  });

  final int id;
  final String title;
  final String subtitle;
  final IconData icon;
  final int colorIndex;
}

const _titles = [
  'Position spring',
  'Opacity fade',
  'Scale bounce',
  'Rotation snap',
  'Color tint',
  'Blur radius',
  'Border width',
  'Padding shift',
  'Elevation lift',
  'Clip radius',
  'Shadow spread',
  'Gradient stop',
];

const _subtitles = [
  'CupertinoMotion.smooth',
  'CupertinoMotion.bouncy',
  'CupertinoMotion.snappy',
  'CupertinoMotion.interactive',
  'Motion.curved',
  'SpringMotion',
  'Motion.linear',
  'Motion.none',
  'CupertinoMotion.smooth',
  'CupertinoMotion.bouncy',
  'CupertinoMotion.snappy',
  'CupertinoMotion.interactive',
];

const _icons = [
  CupertinoIcons.location_fill,
  CupertinoIcons.sun_max_fill,
  CupertinoIcons.resize,
  CupertinoIcons.rotate_right_fill,
  CupertinoIcons.paintbrush_fill,
  CupertinoIcons.circle_grid_hex_fill,
  CupertinoIcons.square_on_square,
  CupertinoIcons.arrow_right_arrow_left,
  CupertinoIcons.arrow_up_circle_fill,
  CupertinoIcons.crop,
  CupertinoIcons.moon_fill,
  CupertinoIcons.slider_horizontal_3,
];
