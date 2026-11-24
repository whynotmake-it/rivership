# Scroll Drag Detector


[![Pub Version](https://img.shields.io/pub/v/scroll_drag_detector)](https://pub.dev/packages/scroll_drag_detector)
[![Coverage](./coverage.svg)](./test/)
[![lintervention_badge]][lintervention_link]
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)


A special version of `GestureDetector` that picks up overscrolling ScrollViews inside of it.

Unlocks easy draggable scrollable sheets in Flutter.
## Installation 💻

**❗ In order to start using Scroll Drag Detector you must have the [Flutter SDK][flutter_install_link] installed on your machine.**

```sh
flutter pub add scroll_drag_detector
```

## Usage

Choose how movement in each physical direction is routed with a `ScrollDragMode`:

- `none`: the scrollable keeps control.
- `scrollFirst`: the scrollable moves first, then the detector takes over at its boundary.
- `dragFirst`: the detector takes over before the scrollable moves.
- `boundaryStart`: the detector takes over at the boundary only when the gesture also began there.

```dart
ScrollDragDetector(
  up: ScrollDragMode.dragFirst,
  down: ScrollDragMode.boundaryStart,
  left: ScrollDragMode.none,
  right: ScrollDragMode.none,
  onVerticalDragUpdate: (details, wouldScroll) {
    // Move the surrounding draggable.
  },
  child: scrollable,
)
```

Use `ScrollDragDetector.legacy` to migrate the previous `scrollableCanMoveBack`
and `onlyDragWhenScrollWasAtTop` configuration without changing conventional
sheet behavior.

### Overriding child scroll behavior

When a child overrides its scroll behavior, wrap it in `ScrollDragBehavior` so
the detector can still stop scrolling during a drag:

```dart
ScrollConfiguration(
  behavior: ScrollDragBehavior(
    parent: const ScrollBehavior().copyWith(scrollbars: false),
  ),
  child: ListView.builder(itemBuilder: buildItem),
)
```

The wrapper also works with per-view overrides such as
`CustomScrollView(scrollBehavior: ScrollDragBehavior(parent: customBehavior))`.
It preserves the consumer's settings, including `copyWith(...)` overrides, and
delegates unchanged when there is no ancestor detector.

### Content with its own drags

A `ScrollDragDetector` competes in the gesture arena like a `GestureDetector`,
and its axis drag beats a descendant pan, so a sheet, drawer or swipe-back route
can steal drags from a map, a canvas or a draggable card. Wrap that content in
`ExcludeScrollDrag`: a drag that starts inside it is never taken by an ancestor
detector on the excluded axes, so the content gets the gesture as if no
detector were there. Detectors inside it work as usual.

```dart
// A map in a sheet.
ExcludeScrollDrag(child: MapView())

// A draggable card on a drawer page.
ExcludeScrollDrag(child: DraggableCard())

// Any content of a full-screen swipe-back route that drags.
ExcludeScrollDrag(child: Whiteboard())
```

Pass `axes` to exclude only some directions, for example a horizontal slider in
a sheet that should still be dragged down:

```dart
ExcludeScrollDrag(
  axes: {Axis.horizontal},
  child: Carousel(),
)
```

--- 

[flutter_install_link]: https://docs.flutter.dev/get-started/install
[mason_link]: https://github.com/felangel/mason
[melos_link]: https://github.com/invertase/melos
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40