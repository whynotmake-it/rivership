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
| `Draggable`, `LongPressDraggable` | `MotionDraggable`, `MotionLongPressDraggable` | The feedback lands with a spring; plain `DragTarget`s work unchanged. See [Dragging](#dragging). |
| (none) | `MotionReorder` | Flies an item from its old place to its new one when a list, grid or board reorders. See [Reordering](#reordering). |
| `ReorderableListView` | `MotionDropZone` | Makes room for an item dragged over any list, grid or wrap, and takes the drop there. See [Drop zones](#drop-zones). |
| (none) | `MotionEdgeScroll` | Scrolls the scrollables around it while a drag is near their edges. See [Edge scrolling](#edge-scrolling). |

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

### Dragging

`MotionDraggable` is Flutter's `Draggable` with a feedback that is animated
from pickup to landing. It uses Flutter's `Draggable` underneath, so plain
`DragTarget`s get the same data and callbacks as before.

When the drag ends, the feedback flies to where the item now lives. Like a
`Hero`, it looks for the mounted `MotionDraggable` with the same `tag`
(`data` by default) once the drop has been laid out:

- **Accepted, and the item moved** (for example to another column): it
  flies to the new place.
- **Rejected or canceled:** it springs back to the source.
- **Nowhere to land** (the target removed the item, or the source is
  gone): it stays where it was dropped and plays its exit, by default
  shrinking and fading out.

The landing starts with the release velocity and follows where its
destination is painted, also while that scrolls, resizes or flies in a
`MotionReorder`. While the feedback lands, the destination keeps its place
but hides its child. Grabbing the feedback mid-landing drags it on from
where it is.

The feedback flies in the `Overlay`, above everything, only while it has
to. Inside a `MotionReorder`, it hands the rest of the landing to it as
soon as its center is inside the destination's scrollables, usually the
frame after the drop. The item then finishes in the tree with its velocity,
scale, rotation and opacity, clipped and stacked like itself, and a reorder
redirects it. While the destination's slot is scrolled out of view, the
feedback stays in the overlay, clipped to the destination's scrollables.
Without a `MotionReorder`, the feedback lands in the overlay.

`handoff` picks when the landing moves into the tree:

| `handoff` | The landing moves into the tree |
|---|---|
| `MotionDragHandoff.onEnter` (default) | once the card's center is inside the destination's scrollables |
| `MotionDragHandoff.immediate` | on the frame after the drop, wherever the card is, so the destination clips it at once |
| `MotionDragHandoff.never` | never: the whole landing flies in the overlay |

Without a `MotionReorder` above the destination, every value behaves like
`never`.

```dart
MotionDraggable<Task>(
  data: task,
  transitions: (drag) => switch ((drag.phase, drag.destination)) {
    (.dragging, _) => [MotionDraggableTrack.scale([.to(1.05)])],
    (.accepted, null) => [
      MotionDraggableTrack.scale([.to(0)]),
      MotionDraggableTrack.opacity([.to(0)]),
    ],
    _ => const [],
  },
  feedbackBuilder: (context, drag, feedback) => Transform.rotate(
    angle: (drag.velocity.dx / 3000).clamp(-0.12, 0.12),
    child: feedback,
  ),
  child: TaskCard(task),
)
```

`transitions` returns Motor track animations for each phase (`dragging`,
`accepted`, `rejected`). It runs again when the destination is found or
lost. The visual tracks it doesn't mention (`scale`, `rotation`, `opacity`)
spring back to rest. `drag.velocity` is in logical pixels per second: it is
smoothed while dragging, and it is the landing spring's velocity afterwards.

The feedback is laid out at the child's measured size. A `feedback` that
wants its own size loosens the constraints itself, for example with
`Align`.

Differences from `Draggable`:

- `childWhenDragging` defaults to the child, hidden but keeping its place.
- `onLanded` is called when the feedback has landed, even after the
  draggable has left the tree.
- A plain `DragTargetDetails.offset` is the unscaled top-left Flutter
  computes, not the transformed feedback's.
- `createRecognizer` isn't overridable: `MotionLongPressDraggable` covers
  the long press.

### Reordering

`MotionReorder` flies an item from where it was painted to where layout puts
it, whenever its `flightKey` changes. Give it the item's identity as its
`key` and its index as its `flightKey`:

```dart
ListView.builder(
  itemCount: tasks.length,
  // Without it, the list matches items by index and nothing flies.
  findChildIndexCallback: (key) => indexOfTask(key),
  itemBuilder: (context, i) => MotionReorder(
    key: ValueKey(tasks[i].id),
    flightKey: i,
    child: TaskTile(tasks[i]),
  ),
)
```

- Only a `flightKey` change starts a flight. Scrolling, a sibling resizing
  or the window resizing move the item with layout, at once.
- Flights run in content coordinates, the position plus the offset of every
  enclosing scrollable, on both axes. Scrolling mid-flight carries the flight
  along, so this works in nested scrollables such as a board of scrolling
  columns.
- A new `flightKey` mid-flight redirects the flight with its velocity. A
  change of layout alone mid-flight moves the whole flight instead, so it
  never bends toward a layout shift.
- Hit testing and semantics stay at the layout position.
- `scope` (such as a board column) makes a change snap instead of fly.
  `enabled: false` hands the item to another animation, such as a
  `MotionDraggable` landing on it.

### Drop zones

`MotionDropZone` is one `DragTarget` around a list, grid or wrap. While a
compatible item hovers over it, the zone opens a gap where the item would
go, and the items after the gap fly aside on their `MotionReorder` springs.
A drop calls `onInsert` with the gap's index, and the feedback flies into
the gap. The app owns the data and lays the slots out with any list widget:

```dart
MotionDropZone<Task>(
  items: tasks,
  // The index counts after the task has left its old place, so this is
  // the whole job for a reorder within the list.
  onInsert: (task, index) => setState(() {
    tasks
      ..remove(task)
      ..insert(index, task);
  }),
  builder: (context, slots) => ListView.builder(
    itemCount: slots.length,
    findChildIndexCallback: slots.indexOfKey,
    itemBuilder: (context, i) => slots.build(
      i,
      (context, task) => MotionDraggable<Task>(
        data: task,
        child: TaskTile(task),
      ),
    ),
  ),
)
```

- The gap goes before the first item whose painted center is past the
  pointer, within the pointer's row for a grid or a wrap. It holds still
  within a few pixels of a center, so it doesn't flicker. `probe:
  .feedbackCenter` places it by the card instead of the finger.
- The gap is as large as the dragged item. `placeholderBuilder` draws it
  and can pick its own size.
- Dragging an item of the zone turns its slot into the gap. One callback,
  `onInsert`, covers drops from this list, from other lists, and moves by a
  screen reader.
- When `onInsert` returns a `Future`, the gap stays open and the feedback
  waits on it until the future completes. If it throws, or completes
  without the item in `items`, the drop counts as rejected.

### Edge scrolling

`MotionEdgeScroll` scrolls every `Scrollable` around it while a
`MotionDraggable` is dragged near one of its edges: faster the closer to the
edge, smoothly, and on for as long as the drag holds still. Put it anywhere
inside the scrollable; its own size doesn't matter, because the edges are
the viewport's. A `MotionDropZone` includes one.

## Reduced motion

The widgets take whatever motion you pass. To honor reduced motion, pass
`Motion.instant()` (or a short spring) when
`MediaQuery.disableAnimationsOf(context)` is true, ideally once, in your
design system's motion tokens.
