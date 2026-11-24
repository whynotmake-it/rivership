# Scroll Drag Detector

[![Pub Version](https://img.shields.io/pub/v/scroll_drag_detector)](https://pub.dev/packages/scroll_drag_detector)
[![Coverage](./coverage.svg)](./test/)
[![lints by lintervention][lintervention_badge]][lintervention_link]
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

A drag gesture detector that coordinates with nested scroll views — picking up overscroll at the boundary so you can build draggable sheets, drawers, and swipe-to-dismiss routes in Flutter.

## Installation

```sh
flutter pub add scroll_drag_detector
```

## Usage

Choose how movement in each physical direction is routed with a `ScrollDragMode`:

- `none` — the scrollable keeps control.
- `scrollFirst` — the scrollable moves first, then the detector takes over at its boundary.
- `dragFirst` — the detector takes over before the scrollable moves.
- `boundaryStart` — the detector takes over at the boundary only when the gesture also started there.

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

Use `ScrollDragDetector.legacy` to migrate from the previous `scrollableCanMoveBack` and `onlyDragWhenScrollWasAtTop` options without changing conventional sheet behavior.

### Overriding child scroll behavior

When a child overrides its `ScrollBehavior`, wrap it in `ScrollDragBehavior` so the detector can still pause scrolling during a drag:

```dart
ScrollConfiguration(
  behavior: ScrollDragBehavior(
    parent: const ScrollBehavior().copyWith(scrollbars: false),
  ),
  child: ListView.builder(itemBuilder: buildItem),
)
```

`ScrollDragBehavior` also works with per-view overrides such as `CustomScrollView(scrollBehavior: ScrollDragBehavior(parent: customBehavior))`. It preserves your settings (including `copyWith(...)` overrides) and delegates unchanged when no ancestor detector is present.

### Content with its own drags

`ScrollDragDetector` competes in the gesture arena like a `GestureDetector`, so its axis drag wins over a descendant pan — meaning a sheet, drawer, or swipe-back route can steal drags from a map, canvas, or draggable card. Wrap that content in `ExcludeScrollDrag` so drags starting inside it are ignored by ancestor detectors on the excluded axes. Any detectors inside `ExcludeScrollDrag` keep working as usual.

```dart
// A map inside a sheet.
ExcludeScrollDrag(child: MapView())

// A draggable card inside a drawer.
ExcludeScrollDrag(child: DraggableCard())

// Any draggable canvas inside a swipe-back route.
ExcludeScrollDrag(child: Whiteboard())
```

Pass `axes` to exclude only specific directions — for example, a horizontal carousel inside a vertically draggable sheet:

```dart
ExcludeScrollDrag(
  axes: {Axis.horizontal},
  child: Carousel(),
)
```

[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40