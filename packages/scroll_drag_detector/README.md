# Scroll Drag Detector


[![Pub Version](https://img.shields.io/pub/v/motor)](https://pub.dev/packages/scroll_drag_detector)
[![Coverage](./coverage.svg)](./test/)
[![lintervention_badge]]([lintervention_link])
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)


A special version of `GestureDetector` that picks up overscrolling ScrollViews inside of it.

Unlocks easy draggable scrollable sheets in Flutter.
## Installation 💻

**❗ In order to start using Scroll Drag Detector you must have the [Dart SDK][dart_install_link] installed on your machine.**

Or install via `dart pub`:

```sh
dart pub add scroll_drag_detector
```

## Usage

Choose how movement in each physical direction is routed:

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

Use `ScrollDragMode.scrollFirst` to let the child reach its boundary before
the surrounding draggable takes over. Use `ScrollDragDetector.legacy` to
migrate the previous `scrollableCanMoveBack` and
`onlyDragWhenScrollWasAtTop` configuration without changing conventional
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

--- 

[dart_install_link]: https://dart.dev/get-dart
[mason_link]: https://github.com/felangel/mason
[melos_link]: https://github.com/invertase/melos
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40