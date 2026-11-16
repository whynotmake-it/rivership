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
        'Items in a MotionLayoutGroup fly to their new place when their '
        'order changes. MotionDraggable, MotionReorderable and '
        'MotionDragToScroll add drag and drop on top. Scrolling never moves '
        'anything on its own.',
    children: [
      DemoSection(
        title: 'Layout group',
        description:
            'Each card is a MotionLayoutItem. Shuffle, add or remove cards: '
            'whatever changes place flies there. Tap a card to open it; it '
            'grows on its own spring, and the cards below follow.',
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
            'Each column is a MotionReorderable. Drag a card within its '
            'column or to another one, anywhere over the column: the dragged '
            'card collapses, and a gap opens where it will go. Near an edge, '
            'the column or the board scrolls.',
        padding: 0,
        child: _Board(),
      ),
      DemoSection(
        title: 'Grid',
        description:
            'A MotionReorderable laid out by a Wrap. Drag a tile to reorder; '
            'tiles fly on both axes.',
        child: _Grid(),
      ),
      DemoSection(
        title: 'Line',
        description:
            'The dragged card keeps its room, and a line marks where it will '
            'go. Nothing moves until the drop.',
        child: _LineDemo(),
      ),
      DemoSection(
        title: 'Drag handle',
        description:
            'Only the grip starts a drag, so the rest of the card stays free '
            'for taps and text. The whole card flies.',
        child: _HandleDemo(),
      ),
      DemoSection(
        title: 'New from a button',
        description:
            'Drag the button over the list: the new card shows where it will '
            'go. On the drop, the button turns into the card.',
        child: _CreateDemo(),
      ),
      DemoSection(
        title: 'Sections',
        description:
            'Two MotionReorderable.sliver sections in one scroll view, with a '
            'header between them. Drag cards within a section or across.',
        child: _SectionsDemo(),
      ),
      DemoSection(
        title: "Flutter's drag and drop",
        description:
            'A plain Draggable drops into a MotionReorderable, and a card '
            'drops on a plain DragTarget. Drag the new task into the list, or '
            'a card onto the trash: with nowhere to land, it shrinks away.',
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
  void _move(_Task task, _Column to, int index) => setState(() {
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
            child: MotionDragToScroll(
              child: CoilScrollArea(
                axis: Axis.horizontal,
                padding: EdgeInsets.all(board.edge),
                // One group for the board, so a card flies from one lane to
                // another.
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
                            onMove: (task, index) => _move(task, column, index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A column of the board: a header over its cards. The whole lane takes
/// drops: a card dragged over it, from this column or another, opens a gap
/// where it will go, and drops into it.
class _Lane extends StatelessWidget {
  const _Lane({
    required this.column,
    required this.onShuffle,
    required this.onMove,
  });

  final _Column column;
  final VoidCallback onShuffle;
  final void Function(_Task task, int index) onMove;

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    return MotionReorderable<_Task>(
      items: column.tasks,
      onMove: (move) => onMove(move.item!, move.index),
      builder: (context, drop) => _DropHighlight(
        active: drop != null,
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
              child: column.tasks.isEmpty && drop == null
                  ? const _EmptyLane()
                  : _cards(context, drop, board.inset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cards(BuildContext context, MotionDrop<_Task>? drop, double inset) {
    final tasks = column.tasks;
    final gap = MotionDropGap(child: _CardSlot(height: _slotHeight(drop)));
    return MotionDragToScroll(
      child: CoilScrollArea.scrollable(
        controller: column.controller,
        child: ListView(
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
          children: [
            for (final task in tasks) ...[
              if (drop?.before == task) gap,
              MotionReorderableItem(
                key: ValueKey(task),
                item: task,
                child: _DraggableCard(task: task, collapses: true),
              ),
            ],
            if (drop != null && drop.before == null) gap,
          ],
        ),
      ),
    );
  }
}

/// The height of a card's slot for [drop]: the dragged card's, or a card's
/// when a plain Draggable doesn't tell.
double _slotHeight(MotionDrop<Object>? drop) => switch (drop?.size) {
  final size? => size.height - _BoardMetrics.cardGap,
  null => 64,
};

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
      offset: -theme.focusRing.width,
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
    final text = theme.typography.resolve(
      CoilTheme.tierOf(context),
      CoilSize.compact,
    );
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
                style: text.body.copyWith(
                  fontWeight: text.emphasis,
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
    final text = theme.typography.resolve(
      CoilTheme.tierOf(context),
      CoilSize.compact,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _BoardMetrics.cardPadding,
        vertical: 24,
      ),
      child: Text(
        'Drop a card here',
        textAlign: TextAlign.center,
        style: text.caption.copyWith(color: theme.colors.mutedForeground),
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

/// A task card that drags within its list and to other lists.
///
/// The card keeps the gap below it, also while it flies, so a card dropped
/// anywhere takes exactly a slot's place. With [collapses], it leaves the
/// layout while it is dragged, so a gap can open in its place; else it
/// keeps its room.
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.task,
    this.collapses = false,
    this.handleOnly = false,
  });

  final _Task task;
  final bool collapses;

  /// Whether only the grip starts the drag.
  final bool handleOnly;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    // The feedback is the same card, lifted while it is dragged. It settles
    // back on `gentle` as it lands, the landing's own spring. It flies in
    // the overlay, so it takes the page's themes along, among them the
    // surface level it lifts from.
    final themes = InheritedTheme.capture(
      from: context,
      to: Overlay.of(context).context,
    );
    Widget card({required bool lifted}) => Padding(
      padding: const EdgeInsets.only(bottom: _BoardMetrics.cardGap),
      child: _TaskCard(task: task, lifted: lifted, grip: handleOnly),
    );
    return MotionDraggable<_Task>(
      data: task,
      id: task,
      // The page scrolls on touch, so a card lifts on a long press there,
      // and at once with a pointer.
      start: CoilTheme.tierOf(context) == CoilTier.touch
          ? MotionDragStart.longPress
          : MotionDragStart.immediate,
      handleOnly: handleOnly,
      motion: motion.gentle,
      motions: {MotionDraggableTrack.rotation: motion.quick},
      transitions: _tilt,
      childWhenDragging: collapses
          ? (context, size) => const SizedBox.shrink()
          : null,
      feedback: (context, drag) =>
          themes.wrap(card(lifted: drag.phase == MotionDragPhase.dragging)),
      child: card(lifted: false),
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
  const _TaskCard({required this.task, this.lifted = false, this.grip = false});

  final _Task task;
  final bool lifted;

  /// Whether the card shows a grip that starts its drag.
  final bool grip;

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
          icon: grip
              ? const MotionDragHandle(child: CatalogIcon(Glyph.grip))
              : null,
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
    // Each tile keeps its share of the spacing around it, so a dragged tile
    // that leaves the layout leaves no spacing behind.
    const half = 4.0;
    final gap = MotionDropGap(
      child: Padding(
        padding: const EdgeInsets.all(half),
        child: SizedBox.square(
          dimension: extent,
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
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16 - half,
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
        MotionLayoutGroup(
          motion: motion.standard,
          child: MotionReorderable<int>(
            items: _items,
            // Numbers are only unique within this grid's group.
            onMove: (move) => setState(() {
              _items
                ..remove(move.item)
                ..insert(move.index, move.item!);
            }),
            builder: (context, drop) => Wrap(
              children: _withGap(
                _items,
                drop,
                gap: gap,
                item: (item) => Padding(
                  padding: const EdgeInsets.all(half),
                  child: _GridTile(item: item, extent: extent, radius: radius),
                ),
              ),
            ),
          ),
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
    final text = CoilTheme.textOf(context);
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
            style: text.body.copyWith(
              fontWeight: text.emphasis,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
    return MotionDraggable<int>(
      data: item,
      id: item,
      start: CoilTheme.tierOf(context) == CoilTier.touch
          ? MotionDragStart.longPress
          : MotionDragStart.immediate,
      motion: motion.gentle,
      childWhenDragging: (context, size) => const SizedBox.shrink(),
      child: tile,
    );
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

/// A short list of cards in a lane's frame, used by the smaller demos.
class _ListFrame extends StatelessWidget {
  const _ListFrame({required this.child, this.active = false});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    return SizedBox(
      width: board.laneWidth,
      child: _DropHighlight(
        active: active,
        borderRadius: BorderRadius.circular(board.laneRadius),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            board.inset,
            board.inset,
            board.inset,
            math.max(0, board.inset - _BoardMetrics.cardGap),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Cards whose order changes: shuffled, added at the top, removed from the
/// top. A card opens on its own spring, and the cards below follow it.
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
                      // The card grows and shrinks on its own spring, so the
                      // cards below follow it frame by frame.
                      description: MotionSize(
                        motion: motion.standard,
                        alignment: AlignmentDirectional.topStart,
                        child: _open.contains(task)
                            ? Text('${task.owner} owns this. Tap to close.')
                            : const SizedBox(width: double.infinity),
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

/// [items] as [MotionReorderableItem]s, with [gap] in front of the item
/// the drop comes before, or after the last one.
List<Widget> _withGap<T extends Object>(
  List<T> items,
  MotionDrop<T>? drop, {
  required Widget gap,
  required Widget Function(T item) item,
}) => [
  for (final each in items) ...[
    if (drop?.before == each) gap,
    MotionReorderableItem(key: ValueKey(each), item: each, child: item(each)),
  ],
  if (drop != null && drop.before == null) gap,
];

/// Removes [item] from [from] and inserts it at [index] of [to], in place.
void _moveTask(List<_Task> from, List<_Task> to, _Task item, int index) {
  from.remove(item);
  to.insert(index, item);
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
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
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
                style: text.body.copyWith(fontWeight: text.emphasis),
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
                      style: (done ? text.muted : text).body,
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

/// A list whose dragged card keeps its room: a line marks where it will
/// go, at the top of the card the drop comes before, or under the last one.
class _LineDemo extends StatefulWidget {
  const _LineDemo();

  @override
  State<_LineDemo> createState() => _LineDemoState();
}

class _LineDemoState extends State<_LineDemo> {
  final _maker = _TaskMaker(const [
    'Choose a theme',
    'Write the speech',
    'Rehearse twice',
    'Print the handouts',
  ]);
  late final _list = [for (var i = 0; i < 4; i++) _maker.next()];

  @override
  Widget build(BuildContext context) => MotionLayoutGroup(
    motion: CoilTheme.motionOf(context).standard,
    child: MotionReorderable<_Task>(
      items: _list,
      onMove: (move) =>
          setState(() => _moveTask(_list, _list, move.item!, move.index)),
      builder: (context, drop) => _ListFrame(
        active: drop != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, task) in _list.indexed)
              MotionReorderableItem(
                key: ValueKey(task),
                item: task,
                child: _DropLine(
                  top: drop != null && drop.before == task,
                  bottom:
                      drop != null &&
                      drop.before == null &&
                      i == _list.length - 1,
                  child: _DraggableCard(task: task),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A thin brand line in the gap above [child] or below it, where a drop
/// would go. The card keeps its own gap below it, so the line sits in the
/// middle of the gaps.
class _DropLine extends StatelessWidget {
  const _DropLine({
    required this.top,
    required this.bottom,
    required this.child,
  });

  final bool top;
  final bool bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const thickness = 2.0;
    const middle = (_BoardMetrics.cardGap - thickness) / 2;
    final line = DecoratedBox(
      decoration: ShapeDecoration(
        color: CoilTheme.of(context).colors.brand,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(thickness),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (top)
          Positioned(
            top: -middle - thickness,
            left: 0,
            right: 0,
            height: thickness,
            child: line,
          ),
        if (bottom)
          Positioned(
            bottom: middle,
            left: 0,
            right: 0,
            height: thickness,
            child: line,
          ),
      ],
    );
  }
}

/// A list whose cards only drag by their grip.
class _HandleDemo extends StatefulWidget {
  const _HandleDemo();

  @override
  State<_HandleDemo> createState() => _HandleDemoState();
}

class _HandleDemoState extends State<_HandleDemo> {
  final _maker = _TaskMaker(const [
    'Read the brief',
    'Sketch three ideas',
    'Pick one with the team',
    'Build the prototype',
  ]);
  late final _list = [for (var i = 0; i < 4; i++) _maker.next()];

  @override
  Widget build(BuildContext context) => MotionLayoutGroup(
    motion: CoilTheme.motionOf(context).standard,
    child: MotionReorderable<_Task>(
      items: _list,
      onMove: (move) =>
          setState(() => _moveTask(_list, _list, move.item!, move.index)),
      builder: (context, drop) => _ListFrame(
        active: drop != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _withGap(
            _list,
            drop,
            gap: MotionDropGap(child: _CardSlot(height: _slotHeight(drop))),
            item: (task) =>
                _DraggableCard(task: task, collapses: true, handleOnly: true),
          ),
        ),
      ),
    ),
  );
}

/// A button that drags out a new card: the list shows the card where it
/// will go, and on the drop, the button turns into it.
class _CreateDemo extends StatefulWidget {
  const _CreateDemo();

  @override
  State<_CreateDemo> createState() => _CreateDemoState();
}

class _CreateDemoState extends State<_CreateDemo> {
  final _maker = _TaskMaker(const [
    'Sort the inbox',
    'Call the landlord',
    'Renew the passport',
    'Book the dentist',
    'Back up the laptop',
    'Fix the bike',
  ]);
  late final _list = [for (var i = 0; i < 3; i++) _maker.next()];

  /// The task the button makes next. It isn't in the list yet, but it is
  /// already what the button drags, with its own id.
  late _Task _draft = _maker.next();

  void _move(_Task task, int index) => setState(() {
    _moveTask(_list, _list, task, index);
    if (identical(task, _draft)) _draft = _maker.next();
  });

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        MotionLayoutGroup(
          motion: CoilTheme.motionOf(context).standard,
          child: MotionReorderable<_Task>(
            items: _list,
            onMove: (move) => _move(move.item!, move.index),
            builder: (context, drop) => _ListFrame(
              active: drop != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _withGap(
                  _list,
                  drop,
                  // The new card, ghosted, where it will go; a slot for a
                  // card that is moved.
                  gap: MotionDropGap(
                    child: switch (drop?.item) {
                      final task? when !_list.contains(task) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: _BoardMetrics.cardGap,
                        ),
                        child: Opacity(
                          opacity: 0.5,
                          child: _TaskCard(task: task),
                        ),
                      ),
                      _ => _CardSlot(height: _slotHeight(drop)),
                    },
                  ),
                  item: (task) => _DraggableCard(task: task, collapses: true),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: board.laneWidth / 2,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: _NewTaskButton(
              task: _draft,
              onPressed: () => _move(_draft, 0),
            ),
          ),
        ),
      ],
    );
  }
}

/// The round button that makes a new task: tapped, it adds it at the top;
/// dragged, it carries it, and on the drop it turns into its card.
class _NewTaskButton extends StatelessWidget {
  const _NewTaskButton({required this.task, required this.onPressed});

  final _Task task;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final radii = CoilTheme.radiiOf(context);
    final motion = CoilTheme.motionOf(context);
    final surface = colors.surface(CoilSurface.levelOf(context) + 1);
    final themes = InheritedTheme.capture(
      from: context,
      to: Overlay.of(context).context,
    );
    final button = CoilButton.icon(
      onPressed: onPressed,
      icon: const CatalogIcon(Glyph.plus),
      semanticLabel: 'New task',
    );
    final card = Padding(
      padding: const EdgeInsets.only(bottom: _BoardMetrics.cardGap),
      child: _TaskCard(task: task),
    );
    return MotionDraggable<_Task>(
      data: task,
      id: task,
      start: CoilTheme.tierOf(context) == CoilTier.touch
          ? MotionDragStart.longPress
          : MotionDragStart.immediate,
      // The whole morph plays in the overlay, then the card takes over.
      handoff: MotionDragHandoff.never,
      motion: motion.gentle,
      motions: {MotionDraggableTrack.morph: motion.standard},
      // The button stays where it is, faded, while its task is dragged.
      childWhenDragging: (context, size) =>
          Opacity(opacity: 0.4, child: button),
      // A button that turns into the card: the size springs to the card's,
      // the shape and fill follow `morph`, and the icon fades into the
      // card's content.
      feedback: (context, drag) {
        final t = drag.morph.clamp(0.0, 1.0);
        final destination = drag.destination;
        return themes.wrap(
          Padding(
            padding: EdgeInsets.only(bottom: _BoardMetrics.cardGap * t),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                // From the primary button's fill to the card's surface.
                color: Color.lerp(colors.foreground, surface, t),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    radii.item + (radii.container - radii.item) * t,
                  ),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 1 - t,
                    child: IconTheme.merge(
                      data: IconThemeData(color: colors.background),
                      child: const Center(child: CatalogIcon(Glyph.plus)),
                    ),
                  ),
                  if (destination != null)
                    Opacity(
                      opacity: t,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: AlignmentDirectional.topStart,
                          minWidth: destination.width,
                          maxWidth: destination.width,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: card,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: button,
    );
  }
}

/// Two reorderable sections in one scroll view, with a header between
/// them.
class _SectionsDemo extends StatefulWidget {
  const _SectionsDemo();

  @override
  State<_SectionsDemo> createState() => _SectionsDemoState();
}

class _SectionsDemoState extends State<_SectionsDemo> {
  final _maker = _TaskMaker(const [
    'Answer the reviews',
    'Merge the docs fix',
    'Update the roadmap',
    'Prepare the retro',
    'Clean up the branch',
  ]);
  late final _today = [for (var i = 0; i < 3; i++) _maker.next()];
  late final _later = [for (var i = 0; i < 2; i++) _maker.next()];
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(List<_Task> to, _Task task, int index) => setState(() {
    _today.remove(task);
    _later.remove(task);
    to.insert(index, task);
  });

  Widget _header(String title, List<_Task> list) {
    final board = _BoardMetrics.of(context);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: board.inset),
      sliver: SliverToBoxAdapter(
        child: _LaneHeader(
          title: Text(title),
          count: list.length,
          onShuffle: list.length > 1 ? () => setState(list.shuffle) : null,
        ),
      ),
    );
  }

  Widget _section(List<_Task> list) {
    final board = _BoardMetrics.of(context);
    return MotionReorderable<_Task>.sliver(
      items: list,
      onMove: (move) => _move(list, move.item!, move.index),
      builder: (context, drop) => SliverPadding(
        padding: EdgeInsets.all(board.inset),
        sliver: SliverList.list(
          children: list.isEmpty
              // An empty section needs something to drop on.
              ? [
                  MotionDropGap(
                    child: drop == null
                        ? const _EmptyLane()
                        : _CardSlot(height: _slotHeight(drop)),
                  ),
                ]
              : _withGap(
                  list,
                  drop,
                  gap: MotionDropGap(
                    child: _CardSlot(height: _slotHeight(drop)),
                  ),
                  item: (task) => _DraggableCard(task: task, collapses: true),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = _BoardMetrics.of(context);
    return SizedBox(
      width: board.laneWidth,
      height: 360,
      child: MotionLayoutGroup(
        motion: CoilTheme.motionOf(context).standard,
        child: MotionDragToScroll(
          child: CoilScrollArea.scrollable(
            controller: _controller,
            child: CustomScrollView(
              controller: _controller,
              slivers: [
                _header('Today', _today),
                _section(_today),
                _header('Later', _later),
                _section(_later),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A reorderable list next to Flutter's own Draggable and DragTarget: a new
/// task that drops into the list, and a trash that takes cards out of it.
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

  void _move(_Task task, int index) => setState(() {
    _moveTask(_list, _list, task, index);
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
        MotionLayoutGroup(
          motion: CoilTheme.motionOf(context).standard,
          child: MotionReorderable<_Task>(
            items: _list,
            onMove: (move) => _move(move.item!, move.index),
            builder: (context, drop) => _ListFrame(
              active: drop != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _withGap(
                  _list,
                  drop,
                  // A plain Draggable doesn't tell its size: the slot has a
                  // card's height.
                  gap: MotionDropGap(
                    child: _CardSlot(height: _slotHeight(drop)),
                  ),
                  item: (task) => _DraggableCard(task: task, collapses: true),
                ),
              ),
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
                        style: theme.typography
                            .resolve(
                              CoilTheme.tierOf(context),
                              CoilSize.compact,
                            )
                            .caption
                            .copyWith(color: theme.colors.mutedForeground),
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
