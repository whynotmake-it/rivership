import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

const reorderEntry = CatalogEntry(
  slug: 'reorder',
  title: 'Reorder',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Cards fly to their new place; drag them between columns.',
  page: ReorderPage.new,
);

class ReorderPage extends StatelessWidget {
  const ReorderPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'Reorder',
    summary:
        'MotionReorder flies each item to its new place when its list '
        'reorders. Scrolling never moves anything on its own.',
    children: [
      DemoSection(
        title: 'Board',
        description:
            'Shuffle a column, or drag a card to another column. The '
            'card lands with MotionDraggable; the cards around it make room.',
        child: SizedBox(height: 460, child: _Board()),
      ),
      DemoSection(
        title: 'Grid',
        description: 'Items fly on both axes.',
        child: _Grid(),
      ),
    ],
  );
}

@immutable
class _Task {
  const _Task(this.id, this.title, this.owner);

  final int id;
  final String title;
  final String owner;
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

const _titles = [
  'Write the release notes',
  'Fix the login redirect',
  'Review the color tokens',
  'Profile the board',
  'Update the onboarding copy',
  'Triage new issues',
  'Ship the dark theme',
  'Plan the next sprint',
  'Audit the focus order',
  'Draft the migration guide',
  'Reply to design feedback',
  'Record the demo',
  'Tune the landing spring',
  'Remove the old flags',
  'Clean up the issue labels',
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
      final task = _Task(
        id,
        _titles[id % _titles.length],
        _owners[id % _owners.length],
      );
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

  void _move(_Task task, _Column to) => setState(() {
    for (final column in _columns) {
      column.tasks.remove(task);
    }
    to.tasks.insert(0, task);
  });

  @override
  Widget build(BuildContext context) => CoilScrollArea(
    axis: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, column) in _columns.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          SizedBox(
            width: 260,
            child: _ColumnView(
              column: column,
              onShuffle: () => setState(column.tasks.shuffle),
              onAccept: (task) => _move(task, column),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ColumnView extends StatelessWidget {
  const _ColumnView({
    required this.column,
    required this.onShuffle,
    required this.onAccept,
  });

  final _Column column;
  final VoidCallback onShuffle;
  final ValueChanged<_Task> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final radii = CoilTheme.radiiOf(context);
    return DragTarget<_Task>(
      // A card can only go to another column: there is no reordering
      // within a column yet, so a drop on its own column flies back.
      onWillAcceptWithDetails: (details) =>
          !column.tasks.contains(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: candidates.isEmpty ? theme.colors.muted : theme.colors.tint,
          borderRadius: BorderRadius.circular(radii.container),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Row(
                  children: [
                    RoleText(column.title, role: TypeRole.title),
                    const SizedBox(width: 8),
                    CoilBadge(child: Text('${column.tasks.length}')),
                    const Spacer(),
                    CoilButton(
                      variant: CoilButtonVariant.ghost,
                      size: CoilSize.compact,
                      onPressed: onShuffle,
                      child: const Text('Shuffle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CoilScrollArea.scrollable(
                  controller: column.controller,
                  child: ListView.builder(
                    controller: column.controller,
                    itemCount: column.tasks.length,
                    findChildIndexCallback: (key) =>
                        column.indexOfId((key as ValueKey<int>).value),
                    itemBuilder: (context, i) =>
                        _card(context, column.tasks[i], i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _Task task, int index) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context);
    final radii = CoilTheme.radiiOf(context);
    final card = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CoilCard(
        title: Text(task.title),
        description: Text(task.owner),
      ),
    );
    List<TrackAnimation<Object>> transitions(MotionDragDetails drag) => [
      if (drag.phase == MotionDragPhase.dragging)
        MotionDraggableTrack.scale(const [TrackStep.to(1.03)]),
    ];
    Widget feedback(BuildContext context, MotionDragDetails drag, Widget f) =>
        DecoratedBox(
          // The lifted card's shadow. coil has no "lifted" step yet, so
          // this uses the highest elevation.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radii.container),
            boxShadow: drag.phase == MotionDragPhase.dragging
                ? theme.colors.shadow(6)
                : null,
          ),
          child: f,
        );
    // The vertical list scrolls on touch, so a card lifts on a long press
    // there and at once with a pointer.
    final draggable = CoilTheme.tierOf(context) == CoilTier.touch
        ? MotionLongPressDraggable<_Task>(
            data: task,
            motion: motion.gentle,
            transitions: transitions,
            feedbackBuilder: feedback,
            child: card,
          )
        : MotionDraggable<_Task>(
            data: task,
            motion: motion.gentle,
            transitions: transitions,
            feedbackBuilder: feedback,
            child: card,
          );
    return MotionReorder(
      key: ValueKey(task.id),
      flightKey: index,
      // A card that changes column snaps; MotionDraggable lands it.
      scope: column,
      motion: motion.standard,
      child: draggable,
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

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final radii = CoilTheme.radiiOf(context);
    final motion = CoilTheme.motionOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoilButton(
          variant: CoilButtonVariant.secondary,
          onPressed: () => setState(_items.shuffle),
          child: const Text('Shuffle'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, item) in _items.indexed)
              MotionReorder(
                key: ValueKey(item),
                flightKey: i,
                motion: motion.standard,
                child: SizedBox.square(
                  dimension: 64,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.surface(4),
                      borderRadius: BorderRadius.circular(radii.item),
                      boxShadow: theme.colors.shadow(2),
                    ),
                    child: Center(
                      child: RoleText('$item', role: TypeRole.title),
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
