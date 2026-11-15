# Motor Widgets

Spring-driven versions of Flutter's implicit animation widgets, built on
[Motor](../motor).

Flutter's `AnimatedContainer`, `AnimatedSwitcher`, `AnimatedSize` and friends
run on an `AnimationController` with a duration and a curve. When their value
changes mid-flight, they start a new curve from where they are, at zero
velocity, so a quick series of changes stutters. They can't use springs.

The widgets here take a Motor `motion` instead. When their value changes
mid-flight, they head for the new value with the velocity they already have.
There is no `AnimationController`, `Tween` or curve in this package.

## Flutter widget → Motor widget

| Flutter | Motor widgets | Notes |
|---|---|---|
| `AnimatedOpacity` | `MotionOpacity` | The shown opacity stays within 0 and 1 while the spring overshoots. |
| `AnimatedAlign` | `MotionAlign` | `alignment`, `widthFactor` and `heightFactor` each have their own track. |
| `AnimatedPadding` | `MotionPadding` | Allows the negative padding a spring overshoots into, through `PaddingExtended`. |
| `AnimatedPositioned` | `MotionPositioned` | Also `MotionPositioned.fromRect`. |
| `AnimatedScale` | `MotionScale` | |
| `AnimatedRotation` | `MotionRotation` | `turns`, like `AnimatedRotation`. |
| `AnimatedSlide` | `MotionSlide` | `offset` is a fraction of the child's size. |
| `AnimatedContainer` | `MotionContainer` | One track per property; see below for what animates. |
| `AnimatedSize` | `MotionSize` | A render object that springs toward its child's size. |
| `AnimatedSwitcher` | `MotionSwitcher` | Same `transitionBuilder` and `layoutBuilder`, fed by a presence spring per child. |
| rivership `AnimatedSizeSwitcher` | `MotionSizeSwitcher` | `MotionSwitcher` inside `MotionSize`. |
| (none) | `MotionLayoutGroup`, `MotionLayoutItem` | Flies items to their new places when a rebuild moves them. See [Layout groups](#layout-groups). |
| `Draggable`, `LongPressDraggable` | `MotionDraggable` | The feedback lands with a spring; plain `DragTarget`s work unchanged. `start: .longPress` stands in for `LongPressDraggable`. See [Dragging](#dragging). |
| `ReorderableListView` | `MotionReorderable` | Tells your builder where a drag would drop, so you can show a gap or a line in any list, grid or sliver. See [Reordering](#reordering). |
| (none) | `MotionDragToScroll` | Scrolls the scroll view below it while a drag is near one of its edges. See [Scrolling while dragging](#scrolling-while-dragging). |

Each widget takes `motion` where the Flutter widget takes `duration` and
`curve`. Every widget also takes `tickerRate` and `debugLabel`, like Motor's
builders, so it shows up by name in `motor_devtools`.

## Differences from Flutter

- **No reverse timing.** `MotionSize` has no `reverseDuration`, because a
  spring has no reverse leg. The switchers have no `reverseDuration`,
  `switchInCurve` or `switchOutCurve`; `exitMotion` sets the motion of a
  leaving child and defaults to `motion`.
- **`MotionSizeSwitcher` has no `layoutBuilder`.** It lays its children out
  itself.
- **`MotionSizeSwitcher(immediateResize: true)` doesn't stretch leaving
  children.** They keep the constraints they had, so wrapping text doesn't
  reflow while it fades. They sit by `alignment`, clipped to the new size.
  `AnimatedSizeSwitcher` lays them out at the new size.
- **`MotionSizeSwitcher.sizeMotion`** gives the size its own spring, for
  example a spatial spring while the children fade on `motion`.
- **Some `MotionContainer` properties change at once:** the border, shadows,
  gradient and image of a `BoxDecoration`, any other kind of `Decoration`,
  and unbounded (infinite) constraints. A `transform` loses perspective and
  skew while it animates, as it does in `AnimatedContainer`.
- **Directional values are resolved first.** `MotionAlign`, `MotionContainer`
  and `MotionPadding` resolve `AlignmentDirectional` and
  `EdgeInsetsDirectional` against the ambient `Directionality`, then animate.
  A change of text direction jumps.
- **Not ported:** `AnimatedPositionedDirectional`, `AnimatedCrossFade` (use
  `MotionSwitcher`), `AnimatedPhysicalModel`, `AnimatedDefaultTextStyle` and
  `AnimatedFractionallySizedBox`.

## One motion per property: `motions`

Widgets that animate several properties (`MotionContainer`, `MotionAlign`,
`MotionPositioned`) play one Motor `Track` per property. Each widget
declares its tracks on its own track class (`MotionContainerTrack`,
`MotionAlignTrack`, `MotionPositionedTrack`). `motion` is the default for
every track, and `motions` overrides it for single tracks:

```dart
MotionContainer(
  motion: const .smoothSpring(),
  motions: {
    .color: const .snappySpring(),
    .padding: const .bouncySpring(),
  },
  color: selected ? Colors.indigo : Colors.grey,
  padding: .all(selected ? 24 : 12),
  child: child,
)
```

Keys are typed per widget, so another widget's track doesn't compile, and
dot shorthand finds them: `.color` is `MotionContainerTrack.color`. Motions
compare by value, so rebuilding the map in `build` changes nothing unless a
motion changed.

Widgets with a single value (`MotionOpacity`, `MotionScale`, `MotionSlide`,
…) just take `motion`.

## Examples

### Implicit animations

```dart
MotionOpacity(
  opacity: visible ? 1 : 0,
  motion: const .smoothSpring(),
  child: const Text('Hello'),
)
```

```dart
MotionContainer(
  motion: const .bouncySpring(),
  width: expanded ? 240 : 120,
  padding: .all(expanded ? 24 : 12),
  decoration: BoxDecoration(
    color: expanded ? Colors.indigo : Colors.teal,
    borderRadius: .circular(expanded ? 32 : 12),
  ),
  child: const FlutterLogo(),
)
```

Every property is its own track, so changing the color doesn't touch a
width that is still moving. `MotionContainer` animates `alignment`,
`padding`, `margin`, `color`, `width`, `height`, `constraints`, `transform`
and `transformAlignment`, and the `color` and `borderRadius` of a
`BoxDecoration` in `decoration` or `foregroundDecoration`. As in
`AnimatedContainer`, a property that goes from null to a value starts there.

### Size

```dart
MotionSize(
  motion: const .smoothSpring(),
  alignment: .topCenter,
  child: expanded ? const LongText() : const ShortText(),
)
```

### Switching children

```dart
MotionSwitcher(
  motion: const .smoothSpring(),
  exitMotion: const .snappySpring(duration: Duration(milliseconds: 300)),
  transitionBuilder: (child, animation) =>
      ScaleTransition(scale: animation, child: child),
  child: Text('$count', key: ValueKey(count)),
)
```

`MotionSwitcher` has `AnimatedSwitcher`'s API: the same `transitionBuilder`
(defaulting to `AnimatedSwitcher.defaultTransitionBuilder`, a fade) and
`layoutBuilder`. As with `AnimatedSwitcher`, a child that can't update the
previous one (a different type or key) switches.

The `Animation<double>` each child gets is its presence spring (a Motor
`SingleMotionController`): `motion` takes new children from 0 to 1,
`exitMotion` (usually a tighter spring) takes old ones to 0. Its status is
`forward` while entering and `reverse` while leaving. A child whose key comes
back while it is still leaving turns around from where it is, with its
velocity, and keeps its state.

The animation is the raw spring value and can overshoot 0..1; see
`MotionSwitcher`.

`MotionSizeSwitcher` adds a `MotionSize` around it, so the size springs to
the new child too:

```dart
MotionSizeSwitcher(
  motion: const .smoothSpring(),
  child: loading ? const Spinner() : Text(result),
)
```

### Layout groups

`MotionLayoutGroup` flies each of its `MotionLayoutItem`s from where it was
painted to its new place when a rebuild moves it. Give each item its
identity as its `id`:

```dart
MotionLayoutGroup(
  child: Column(
    children: [
      for (final todo in todos)
        MotionLayoutItem(id: todo.id, child: TodoTile(todo)),
    ],
  ),
)
```

- Reorders, inserts and removals around an item all fly, and so does a
  move to another container of the same group, such as another column of a
  board.
- An item is found by its id, not by its widget. It flies even when a lazy
  list builds it anew, so the list needs no keys or
  `findChildIndexCallback`.
- An item checks whether it moved only when it is rebuilt. Scrolling never
  makes it fly, and nothing runs in frames without a rebuild.
- A neighbor that grows on its own, such as a `MotionSize`, moves an item
  without a rebuild, so the item follows it frame by frame instead of
  flying.
- An item that wasn't on screen in the last frame appears in place.
- Hit testing and semantics stay at the layout position.

### Dragging

`MotionDraggable` is Flutter's `Draggable` with a feedback that is animated
from pickup to landing. It uses Flutter's `Draggable` underneath, so plain
`DragTarget`s get the same data and callbacks as before.

When the drag ends, the feedback flies to where the item now lives. Like a
`Hero` looks for its tag, it looks for the landing site with its `id`
(`data` by default) once the drop has been laid out:

- **Accepted, and the item moved** (for example to another column): it
  flies to the new place.
- **Rejected or canceled:** it springs back to where the drag started.
- **Nowhere to land** (the target removed the item): it plays its exit at
  the drop point, by default shrinking and fading out.

Landing sites are `MotionLayoutItem`s and the draggable itself, and ids
only need to be unique within a `MotionLayoutGroup`. An accepted drop lands
in the group that the target names (a `MotionReorderable` names its own),
else in the innermost group under the pointer, else in the group it was
dragged from.

The feedback flies in the `Overlay` only while it has to. Once it is inside
the destination item's visible area, usually the frame after the drop, it
hands the rest of the landing to the item's spring. The item then finishes
in the tree with the feedback's velocity, scale, rotation and opacity,
clipped and stacked like itself. `handoff` picks when that happens:
`.onEnter` (the default), `.immediate`, or `.never`.

```dart
MotionDraggable<Task>(
  data: task,
  start: .longPress,
  // Out of the layout while dragged, so a gap can open in its place.
  childWhenDragging: (context, size) => const SizedBox.shrink(),
  transitions: (drag) => switch (drag.phase) {
    .dragging => [MotionDraggableTrack.scale([.to(1.05)])],
    _ => const [],
  },
  feedback: (context, drag) => Transform.rotate(
    angle: (drag.velocity.dx / 3000).clamp(-0.12, 0.12),
    child: TaskCard(task),
  ),
  child: TaskCard(task),
)
```

- `start: .longPress` starts the drag after a long press, like
  `LongPressDraggable`, with a selection click unless
  `hapticFeedbackOnStart` is false.
- With `handleOnly`, only a pointer on a `MotionDragHandle` inside the
  child starts the drag. The whole draggable flies.
- `childWhenDragging` and `feedback` get the child's measured size.
  `childWhenDragging` defaults to the child, hidden but keeping its room.
  `feedback` is laid out at `drag.size`; wrap it in an `Align` to give it
  its own size.
- `transitions` returns Motor track animations of `scale`, `rotation` and
  `opacity` for each phase. It runs again when the destination is found or
  lost, and the tracks it doesn't mention spring back to rest.
- `drag.morph` springs from 0 to 1 while an accepted drop lands on its
  destination. A `feedback` that reads it can turn into what it lands on,
  such as a button into a card.
- Grabbing a card while it lands, on the feedback or on its slot, picks the
  landing up again.

Differences from `Draggable`:

- `onLanded` is called when the feedback has landed, even after the
  draggable has left the tree.
- A plain `DragTargetDetails.offset` is the unscaled top-left Flutter
  computes, not the transformed feedback's.

### Reordering

`MotionReorderable` takes drags over its content and tells its builder
where they would drop: between `drop.after` and `drop.before`. It lays
nothing out and adds no children, so the builder decides how a drop shows:

```dart
MotionReorderable<Task>(
  items: tasks,
  // The index counts after the task has left its old place, so this is
  // the whole job for a reorder within the list.
  onMove: (move) => setState(() {
    tasks
      ..remove(move.item)
      ..insert(move.index, move.item!);
  }),
  builder: (context, drop) => ListView(
    children: [
      for (final task in tasks) ...[
        if (drop?.before == task) const MotionDropGap(child: TaskSlot()),
        MotionReorderableItem(
          item: task,
          child: MotionDraggable<Task>(
            data: task,
            childWhenDragging: (context, size) => const SizedBox.shrink(),
            child: TaskTile(task),
          ),
        ),
      ],
      if (drop != null && drop.before == null)
        const MotionDropGap(child: TaskSlot()),
    ],
  ),
)
```

- Each `MotionReorderableItem` is a `MotionLayoutItem`, so the items fly
  aside when the drop moves them. The reorderable makes its own
  `MotionLayoutGroup` unless one is already above it.
- A `MotionDropGap` opens room for the drop, and the feedback lands in it.
  To mark the drop with a line instead, draw it on the items on either side
  of it, and let the dragged item keep its room (the default
  `childWhenDragging`), so nothing moves.
- `onMove` covers reorders within the list, drops from other reorderables
  and moves by a screen reader. `onWillAccept` takes other data, such as a
  new item dragged in from a button.
- Geometry places the drop. The pointer, or the feedback's center with
  `point: .feedbackCenter`, picks a line of items and passes their painted
  centers, with a few pixels of slack so the drop doesn't flicker. Lists,
  grids and wraps work alike, and the order comes from `items`.
- The whole content takes drags, headers included. A drop past the items
  goes to the nearest end.
- When the drag leaves, the drop stays, so nothing around the reorderable
  changes size. Letting go outside drops there. `keepsDropOnLeave: false`
  removes the drop as the drag leaves.
- When `onMove` returns a `Future`, the drop stays pending
  (`drop.pending`) and the feedback waits over the gap. If the future
  throws, or completes without the item in `items`, the card flies back.
- `MotionReorderable.sliver` takes drags over a sliver, such as one section
  of a `CustomScrollView`. It must be inside a `MotionLayoutGroup`.

### Scrolling while dragging

`MotionDragToScroll` scrolls the nearest scroll view below it while a drag
is near one of its edges: faster the closer to the edge, with a speed that
follows a spring, and on for as long as the drag holds still.

- Each scroll view that should scroll gets its own. On a board, one goes
  around the board's horizontal scroll view and one around each column's
  list. Of two on the same axis, the inner one scrolls first.
- It runs on frames only while a drag is in an edge band, or while its
  speed springs back to zero.
- A `MotionDraggable` is tracked wherever its pointer is. With `outside`
  (the default), a scroll view that is already scrolling keeps going while
  the drag stays past its edge. A drag elsewhere never starts it.
- A plain `Draggable` is only seen while it is over the widget. A
  `MotionReorderable` inside passes it on.

## Reduced motion

The widgets take whatever motion you pass. To honor reduced motion, pass
`Motion.instant()` (or a short spring) when
`MediaQuery.disableAnimationsOf(context)` is true, ideally once, in your
design system's motion tokens.
