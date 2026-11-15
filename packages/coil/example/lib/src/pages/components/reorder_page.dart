import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

const reorderEntry = CatalogEntry(
  slug: 'reorder',
  title: 'Reorder',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Cards make room for a dragged card and fly to their new place.',
  page: ReorderPage.new,
);

class ReorderPage extends StatelessWidget {
  const ReorderPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'Reorder',
    summary:
        'Items in a MotionLayoutGroup fly to their new place whenever the '
        'layout moves them. MotionDropZone and MotionDraggable add drag and '
        'drop on top. Scrolling never moves anything on its own.',
    children: [
      DemoSection(
        title: 'Layout group',
        description:
            'Each card is a MotionLayoutItem. Shuffle, add or remove cards, '
            'or tap one to open it: whatever the layout moves flies there. '
            'New cards appear in place.',
        child: _LayoutDemo(),
      ),
      DemoSection(
        title: 'Between containers',
        description:
            'Both lists are in one group, so an item that moves to the other '
            'list flies there, with no drag involved. Check an item to move '
            'it.',
        child: _ChecklistDemo(),
      ),
      DemoSection(
        title: 'Board',
        description:
            'Each column is a MotionDropZone. Drag a card within its column '
            'or to another one: the cards make room where it will go, and it '
            'drops into the gap. Near an edge, the column or the board '
            'scrolls.',
        padding: 0,
        child: _Board(),
      ),
      DemoSection(
        title: 'Grid',
        description:
            'A MotionDropZone laid out by a Wrap. Drag a tile to reorder; '
            'tiles fly on both axes.',
        child: _Grid(),
      ),
      DemoSection(
        title: "Flutter's drag and drop",
        description:
            "A plain Draggable drops into a MotionDropZone, and a card drops "
            "on a plain DragTarget. Drag the new task into the list, or a "
            "card onto the trash: with nowhere to land, it shrinks away.",
        child: _InteropDemo(),
      ),
    ],
  );
}

/// The numbers that lay out the board for the tier.
///
/// A lane is inset around its cards as a popover is around its rows, so its
/// radius is the card's plus that inset (DESIGN.md §5), and a card's text
/// lines up with the lane title.
@immutable
class _BoardMetrics {
  factory _BoardMetrics.of(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: CoilSize.compact);
    final touch = metrics.tier == CoilTier.touch;
    final card = CoilTheme.radiiOf(context).container;
    final inset = metrics.popupInset;
    return _BoardMetrics._(
      inset: inset,
      laneRadius: card + inset,
      laneWidth: touch ? 296 : 272,
      // The cards' edges sit 16 from the frame, the card padding.
      edge: 16 - inset,
      height: touch ? 560 : 480,
    );
  }

  const _BoardMetrics._({
    required this.inset,
    required this.laneRadius,
    required this.laneWidth,
    required this.edge,
    required this.height,
  });

  /// Between a lane's edge and its cards.
  final double inset;
  final double laneRadius;
  final double laneWidth;

  /// Between the frame and the lanes.
  final double edge;
  final double height;

  /// Between two cards, as in a separated card group.
  static const cardGap = 8.0;

  /// Between two lanes. With their insets, card columns are 20 (pointer)
  /// or 24 (touch) apart.
  static const laneGap = 12.0;

  /// A card's padding, compact (DESIGN.md §14.4 Card).
  static const cardPadding = 12.0;
}

enum _Tag {
  bug('Bug', CoilBadgeColor.red),
  design('Design', CoilBadgeColor.gray),
  docs('Docs', CoilBadgeColor.gray);

  const _Tag(this.label, this.color);

  final String label;

  /// Only a bug spends a hue; the rest stay neutral.
  final CoilBadgeColor color;
}

@immutable
class _Task {
  const _Task(this.id, this.title, this.owner, [this.tag]);

  final int id;
  final String title;
  final String owner;
  final _Tag? tag;
}

class _Column {
  _Column(this.title, this.tasks);

  final String title;
  final List<_Task> tasks;
  final controller = ScrollController();

  int? indexOfId(int id) {
    final index = tasks.indexWhere((task) => task.id == id);
    return index < 0 ? null : index;
  }
}

const _tasks = [
  ('Write the release notes', _Tag.docs),
  ('Fix the login redirect', _Tag.bug),
  ('Review the color tokens', _Tag.design),
  ('Profile the board', null),
  ('Update the onboarding copy', _Tag.docs),
  ('Triage new issues', null),
  ('Ship the dark theme', _Tag.design),
  ('Plan the next sprint', null),
  ('Audit the focus order', _Tag.bug),
  ('Draft the migration guide', _Tag.docs),
  ('Reply to design feedback', _Tag.design),
  ('Record the demo', null),
  ('Tune the landing spring', null),
  ('Remove the old flags', null),
  ('Clean up the issue labels', null),
];

const _owners = ['Ada', 'Grace', 'Linus', 'Margaret', 'Ken'];

class _Board extends StatefulWidget {
  const _Board();

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  late final List<_Column> _columns = () {
    var id = 0;
    _Task next() {
      final (title, tag) = _tasks[id % _tasks.length];
      final task = _Task(id, title, _owners[id % _owners.length], tag);
      id++;
      return task;
    }

    return [
      _Column('Backlog', [for (var i = 0; i < 6; i++) next()]),
      _Column('Doing', [for (var i = 0; i < 3; i++) next()]),
      _Column('Review', [for (var i = 0; i < 4; i++) next()]),
      _Column('Done', [for (var i = 0; i < 2; i++) next()]),
    ];
  }();

  @override
  void dispose() {
    for (final column in _columns) {
      column.controller.dispose();
    }
    super.dispose();
  }

  /// Moves [task] to [index] of [to], from wherever it was. The index
  /// counts after the task has left its old place.
  void _insert(_Task task, _Column to, int index) => setState(() {
    for (final column in _columns) {
      column.tasks.remove(task);
    }
    to.tasks.insert(index, task);
  });

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    final colors = CoilTheme.of(context).colors;
    // The board is a screen of its own: it sits on the page background,
    // where cards have their designed contrast, as the Sidebar frames do.
    // Inside the stage's hairline, which it would otherwise cover.
    return Padding(
      padding: const EdgeInsets.all(1),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(
          CoilShape.nested(CoilTheme.radiiOf(context).container, 1),
        ),
        child: ColoredBox(
          color: colors.background,
          child: SizedBox(
            height: board.height,
            child: CoilScrollArea(
              axis: Axis.horizontal,
              padding: EdgeInsets.all(board.edge),
              // One group for the board, so the lanes share it.
              child: MotionLayoutGroup(
                motion: CoilTheme.motionOf(context).standard,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _BoardMetrics.laneGap,
                  children: [
                    for (final column in _columns)
                      SizedBox(
                        width: board.laneWidth,
                        child: _Lane(
                          column: column,
                          onShuffle: () => setState(column.tasks.shuffle),
                          onInsert: (task, index) =>
                              _insert(task, column, index),
                        ),
                      ),
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

/// A column of the board: a header over its cards. The whole lane is a drop
/// zone: a card dragged over it, from this column or another, opens a gap
/// where it will go, and drops into it.
class _Lane extends StatelessWidget {
  const _Lane({
    required this.column,
    required this.onShuffle,
    required this.onInsert,
  });

  final _Column column;
  final VoidCallback onShuffle;
  final void Function(_Task task, int index) onInsert;

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    return MotionDropZone<_Task>(
      items: column.tasks,
      onInsert: onInsert,
      placeholderBuilder: (context, size) => _CardSlot(height: size.height),
      itemBuilder: (context, task) => _DraggableCard(task: task),
      builder: (context, slots) => _DropHighlight(
        active: slots.candidate != null,
        borderRadius: BorderRadius.circular(board.laneRadius),
        // The cards scroll in the whole lane below the header.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                board.inset,
                board.inset,
                board.inset,
                0,
              ),
              child: _LaneHeader(
                title: Text(column.title),
                count: column.tasks.length,
                onShuffle: column.tasks.length > 1 ? onShuffle : null,
              ),
            ),
            Expanded(
              child: slots.length == 0
                  ? const _EmptyLane()
                  : _cards(slots, board.inset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cards(MotionDropSlots<_Task> slots, double inset) =>
      CoilScrollArea.scrollable(
        controller: column.controller,
        child: ListView.builder(
          controller: column.controller,
          // The lane's inset is inside the viewport, which clips the cards,
          // so outlines and shadows have room at its edges. Below the last
          // card, its own gap stands in for the inset.
          padding: EdgeInsets.fromLTRB(
            inset,
            inset,
            inset,
            math.max(0, inset - _BoardMetrics.cardGap),
          ),
          itemCount: slots.length,
          itemBuilder: (context, i) => slots[i],
        ),
      );
}

/// Where a dragged card will drop: a pressed well the card's height, at the
/// card's radius, with the card's hairline (DESIGN.md §2.3).
class _CardSlot extends StatelessWidget {
  const _CardSlot({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: _BoardMetrics.cardGap),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.active,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(
                CoilTheme.radiiOf(context).container,
              ),
              side: BorderSide(color: colors.border),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows that a dragged card can drop here: a `hover` fill under a brand
/// ring, inset as in a clipping parent (DESIGN.md §2.3, §13.4). FF marks
/// its file drop the same way, with an accent ring in place of the edge.
class _DropHighlight extends StatelessWidget {
  const _DropHighlight({
    required this.active,
    required this.borderRadius,
    required this.child,
  });

  final bool active;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context);
    return CoilFocusRing(
      visible: active,
      color: theme.colors.brand,
      borderRadius: borderRadius,
      offset: -theme.focusRingWidth,
      child: MotionBuilder<Color>(
        value: active
            ? theme.colors.hover
            : theme.colors.hover.withValues(alpha: 0),
        converter: MotionConverter.colorRgb,
        motion: active ? motion.fade : motion.fadeExit,
        debugLabel: 'Lane drop fill',
        builder: (context, color, child) => DecoratedBox(
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
          ),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// The lane's title and count, and a quiet shuffle at the trailing edge.
class _LaneHeader extends StatelessWidget {
  const _LaneHeader({
    required this.title,
    required this.count,
    required this.onShuffle,
  });

  final Widget title;
  final int count;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: CoilSize.compact);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.controlHeight),
      child: Row(
        children: [
          // The title starts where the cards' text does.
          const SizedBox(width: _BoardMetrics.cardPadding),
          Flexible(
            child: Semantics(
              header: true,
              child: DefaultTextStyle(
                style: theme.typography.style(
                  metrics.body,
                  weight: CoilWeight.semibold,
                  color: theme.colors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title,
              ),
            ),
          ),
          SizedBox(width: metrics.gap),
          CoilBadge(
            size: CoilSize.compact,
            child: Text(
              '$count',
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          CoilButton(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            onPressed: onShuffle,
            leading: const CatalogIcon(Glyph.shuffle),
            child: const Text('Shuffle'),
          ),
        ],
      ),
    );
  }
}

/// What an empty lane shows until a card is dropped in it.
class _EmptyLane extends StatelessWidget {
  const _EmptyLane();

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: CoilSize.compact);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _BoardMetrics.cardPadding,
        vertical: 24,
      ),
      child: Text(
        'Drop a card here',
        textAlign: TextAlign.center,
        style: theme.typography.style(
          metrics.caption,
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}

/// Tilts the card a little while it is dragged, and straightens it as it
/// lands. With nowhere to land, it shrinks and fades as by default.
List<TrackAnimation<Object>> _tilt(MotionDragDetails drag) =>
    switch ((drag.phase, drag.destination)) {
      (MotionDragPhase.dragging, _) => [
        MotionDraggableTrack.rotation([const TrackStep.to(_tiltTurns)]),
      ],
      (_, null) => [
        MotionDraggableTrack.scale([const TrackStep.to(0)]),
        MotionDraggableTrack.opacity([const TrackStep.to(0)]),
      ],
      _ => const [],
    };

/// Five degrees, clockwise.
const _tiltTurns = 5 / 360;

/// A task card that drags within its lane and to other lanes. It drags the
/// item of the drop zone slot it is in.
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({required this.task});

  final _Task task;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    final card = _TaskCard(task: task);
    // The feedback is the same card, lifted while it is dragged. It settles
    // back on `gentle` as it lands, the landing's own spring. It flies in
    // the overlay, so it takes the board's themes along, among them the
    // surface level it lifts from.
    final themes = InheritedTheme.capture(
      from: context,
      to: Overlay.of(context).context,
    );
    Widget feedback(BuildContext context, MotionDragDetails drag, Widget _) =>
        themes.wrap(
          _TaskCard(task: task, lifted: drag.phase == MotionDragPhase.dragging),
        );
    // The lane scrolls on touch, so a card lifts on a long press there, and
    // at once with a pointer.
    final draggable = CoilTheme.tierOf(context) == CoilTier.touch
        ? MotionLongPressDraggable<_Task>(
            motion: motion.gentle,
            motions: {MotionDraggableTrack.rotation: motion.quick},
            transitions: _tilt,
            feedbackBuilder: feedback,
            child: card,
          )
        : MotionDraggable<_Task>(
            motion: motion.gentle,
            motions: {MotionDraggableTrack.rotation: motion.quick},
            transitions: _tilt,
            feedbackBuilder: feedback,
            child: card,
          );
    // Every card, and the gap, keeps the gap below it, so a card dropped
    // anywhere takes exactly the gap's place.
    return Padding(
      padding: const EdgeInsets.only(bottom: _BoardMetrics.cardGap),
      child: draggable,
    );
  }
}

/// A task: its title, then who owns it and its tag.
///
/// At rest it sits one surface level above the board, without a drop
/// shadow. Lifted, it rises two levels more, as a popover opened from it
/// would (DESIGN.md §2.1, §6): that level's shadow, and in dark mode its
/// lighter fill. It rises on `quick`; it settles on `gentle`, the
/// landing's spring, so it is down when it lands. Built lifted, it is seen
/// being picked up.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.lifted = false});

  final _Task task;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final tag = task.tag;
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final motion = CoilTheme.motionOf(context);
    final metrics = CoilTheme.metricsOf(context, size: CoilSize.compact);
    // At rest the card sits one level above the board, with no drop
    // shadow: only the outline of `--shadow-1` in light, and the card's
    // hairline in dark. Lifted, it rises two levels more, with their
    // shadow.
    final light = colors.brightness == Brightness.light;
    final rest = CoilSurface.levelOf(context) + 1;
    final up = rest + 2;
    final restShadows = light ? colors.shadow(1) : const <BoxShadow>[];
    final description = Row(
      spacing: metrics.gap,
      children: [
        Flexible(child: Text(task.owner, maxLines: 1)),
        if (tag != null)
          CoilBadge(
            variant: CoilBadgeVariant.dot,
            color: tag.color,
            size: CoilSize.compact,
            child: Text(tag.label),
          ),
      ],
    );
    return SingleMotionBuilder(
      value: lifted ? 1 : 0,
      from: 0,
      motion: lifted ? motion.quick : motion.gentle,
      debugLabel: 'Task card lift',
      builder: (context, lift, _) {
        // `gentle` overshoots a little; the surface doesn't.
        final t = lift.clamp(0.0, 1.0);
        return CoilCard(
          // Pinned, because the feedback flies in the overlay, outside any
          // scope the board could set.
          size: CoilSize.compact,
          style: CoilCardStyle(
            surface: Color.lerp(
              colors.surface(rest),
              colors.surface(up),
              t,
            ),
            shadows: BoxShadow.lerpList(
              restShadows,
              colors.shadow(up),
              t,
            ),
          ),
          title: Text(task.title),
          description: description,
        );
      },
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid();

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  final _items = List.generate(12, (i) => i + 1);

  bool get _sorted {
    for (var i = 1; i < _items.length; i++) {
      if (_items[i - 1] > _items[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context);
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    // Two control heights: a tile reads as a token, not a button.
    final extent = metrics.controlHeight * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Row(
          spacing: metrics.buttonGap,
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => setState(_items.shuffle),
              leading: const CatalogIcon(Glyph.shuffle),
              child: const Text('Shuffle'),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              onPressed: _sorted ? null : () => setState(_items.sort),
              leading: const CatalogIcon(Glyph.sort),
              child: const Text('Sort'),
            ),
          ],
        ),
        MotionDropZone<int>(
          items: _items,
          motion: motion.standard,
          onInsert: (item, index) => setState(() {
            _items
              ..remove(item)
              ..insert(index, item);
          }),
          placeholderBuilder: (context, size) => SizedBox.fromSize(
            size: size,
            child: DecoratedBox(
              // A pressed well where the tile will drop, with a hairline.
              decoration: ShapeDecoration(
                color: theme.colors.active,
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(color: theme.colors.border),
                ),
              ),
            ),
          ),
          itemBuilder: (context, item) =>
              _GridTile(item: item, extent: extent, radius: radius),
          builder: (context, slots) =>
              Wrap(spacing: 8, runSpacing: 8, children: slots.children),
        ),
      ],
    );
  }
}

/// A numbered tile of the grid, which drags: at once with a pointer, after a
/// long press on touch, where the page scrolls.
class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.item,
    required this.extent,
    required this.radius,
  });

  final int item;
  final double extent;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context);
    final tile = SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        // A quiet fill: tiles are content, not raised surfaces.
        decoration: ShapeDecoration(
          color: theme.colors.muted,
          shape: RoundedSuperellipseBorder(borderRadius: radius),
        ),
        child: Center(
          child: Text(
            '$item',
            style: theme.typography
                .style(
                  metrics.body,
                  weight: CoilWeight.semibold,
                  color: theme.colors.foreground,
                )
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    );
    return CoilTheme.tierOf(context) == CoilTier.touch
        ? MotionLongPressDraggable<int>(motion: motion.gentle, child: tile)
        : MotionDraggable<int>(motion: motion.gentle, child: tile);
  }
}

/// Makes a demo's tasks from its [titles], each a new object: tasks are
/// their own ids.
class _TaskMaker {
  _TaskMaker(this.titles);

  final List<String> titles;
  int _next = 0;

  _Task next() {
    final task = _Task(
      _next,
      titles[_next % titles.length],
      _owners[_next % _owners.length],
    );
    _next++;
    return task;
  }
}

/// Cards whose layout changes: shuffled, added at the top, removed from the
/// top, or opened to show more.
class _LayoutDemo extends StatefulWidget {
  const _LayoutDemo();

  @override
  State<_LayoutDemo> createState() => _LayoutDemoState();
}

class _LayoutDemoState extends State<_LayoutDemo> {
  final _maker = _TaskMaker(const [
    'Pick a venue',
    'Send the invites',
    'Order the cake',
    'Book the band',
    'Print the menus',
    'Plan the seating',
    'Hire a photographer',
  ]);
  late final _list = [for (var i = 0; i < 4; i++) _maker.next()];
  final _open = <_Task>{};

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Wrap(
          spacing: metrics.buttonGap,
          runSpacing: metrics.buttonGap,
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: _list.length > 1
                  ? () => setState(_list.shuffle)
                  : null,
              leading: const CatalogIcon(Glyph.shuffle),
              child: const Text('Shuffle'),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              onPressed: () => setState(() => _list.insert(0, _maker.next())),
              leading: const CatalogIcon(Glyph.plus),
              child: const Text('Add'),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              onPressed: _list.isEmpty
                  ? null
                  : () => setState(() => _open.remove(_list.removeAt(0))),
              leading: const CatalogIcon(Glyph.trash),
              child: const Text('Remove'),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: MotionLayoutGroup(
            motion: motion.standard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _BoardMetrics.cardGap,
              children: [
                for (final task in _list)
                  MotionLayoutItem(
                    key: ValueKey(task),
                    id: task,
                    child: CoilCard(
                      size: CoilSize.compact,
                      onPressed: () => setState(() {
                        if (!_open.remove(task)) _open.add(task);
                      }),
                      title: Text(task.title),
                      description: _open.contains(task)
                          ? Text('${task.owner} owns this. Tap to close.')
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Two lists in one group: checking an item moves it to the other list,
/// and it flies there.
class _ChecklistDemo extends StatefulWidget {
  const _ChecklistDemo();

  @override
  State<_ChecklistDemo> createState() => _ChecklistDemoState();
}

class _ChecklistDemoState extends State<_ChecklistDemo> {
  final _maker = _TaskMaker(const [
    'Pack the charger',
    'Water the plants',
    'Empty the fridge',
    'Lock the windows',
  ]);
  late final _todo = [for (var i = 0; i < 4; i++) _maker.next()];
  final _done = <_Task>[];

  void _check(_Task task, {required bool done}) => setState(() {
    _todo.remove(task);
    _done.remove(task);
    done ? _done.insert(0, task) : _todo.add(task);
  });

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return MotionLayoutGroup(
      motion: motion.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Expanded(child: _list(context, 'To do', _todo, done: false)),
          Expanded(child: _list(context, 'Done', _done, done: true)),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    String title,
    List<_Task> tasks, {
    required bool done,
  }) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.controlHeight),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.typography.style(
                  metrics.body,
                  weight: CoilWeight.semibold,
                  color: theme.colors.foreground,
                ),
              ),
            ),
          ),
        ),
        for (final task in tasks)
          MotionLayoutItem(
            key: ValueKey(task),
            id: task,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: metrics.controlHeight),
              child: Row(
                spacing: metrics.gap,
                children: [
                  CoilCheckbox(
                    value: done,
                    onChanged: (value) => _check(task, done: value ?? false),
                    semanticLabel: task.title,
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.style(
                        metrics.body,
                        color: done
                            ? theme.colors.mutedForeground
                            : theme.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A drop zone next to Flutter's own Draggable and DragTarget: a new task
/// that drops into the list, and a trash that takes cards out of it.
class _InteropDemo extends StatefulWidget {
  const _InteropDemo();

  @override
  State<_InteropDemo> createState() => _InteropDemoState();
}

class _InteropDemoState extends State<_InteropDemo> {
  final _maker = _TaskMaker(const [
    'Draft the agenda',
    'Share the notes',
    'Book a room',
    'Follow up with the team',
    'Collect the feedback',
  ]);
  late final _list = [for (var i = 0; i < 3; i++) _maker.next()];
  late _Task _new = _maker.next();

  void _insert(_Task task, int index) => setState(() {
    _list
      ..remove(task)
      ..insert(index, task);
    if (identical(task, _new)) _new = _maker.next();
  });

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: CoilSize.compact);
    final themes = InheritedTheme.capture(
      from: context,
      to: Overlay.of(context).context,
    );
    final newTask = CoilBadge(
      size: CoilSize.compact,
      child: Text('New task: ${_new.title}'),
    );
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        SizedBox(
          width: board.laneWidth,
          child: MotionDropZone<_Task>(
            items: _list,
            onInsert: _insert,
            // A plain Draggable doesn't tell the zone its size, so its gap
            // has a card's height.
            placeholderBuilder: (context, size) => _CardSlot(
              height: size.isEmpty ? metrics.controlHeight * 2 : size.height,
            ),
            itemBuilder: (context, task) => _DraggableCard(task: task),
            builder: (context, slots) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: slots.children,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Draggable<_Task>(
              data: _new,
              feedback: themes.wrap(newTask),
              childWhenDragging: Opacity(opacity: 0.4, child: newTask),
              child: newTask,
            ),
            DragTarget<_Task>(
              onAcceptWithDetails: (details) =>
                  setState(() => _list.remove(details.data)),
              builder: (context, candidates, _) => _DropHighlight(
                active: candidates.isNotEmpty,
                borderRadius: BorderRadius.circular(board.laneRadius),
                child: SizedBox(
                  width: 160,
                  height: 96,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: metrics.gap,
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(
                          color: theme.colors.mutedForeground,
                        ),
                        child: const CatalogIcon(Glyph.trash),
                      ),
                      Text(
                        'Trash',
                        style: theme.typography.style(
                          metrics.caption,
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
