<p align="center">
  <img src="doc/logo.png" width="128" alt="Stupid Simple Sheet logo" />
</p>

# Stupid Simple Sheet

[![Pub Version](https://img.shields.io/pub/v/stupid_simple_sheet)](https://pub.dev/packages/stupid_simple_sheet)
[![Coverage](./coverage.svg)](./test/)
[![lintervention_badge]]([lintervention_link])
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

The only Flutter sheet that **seamlessly transitions between scrolling content and sheet dragging** -- with real spring physics.

Put a `ListView`, `CustomScrollView`, `PageView`, or any scrollable inside the sheet. When the user scrolls to the edge, the gesture hands off to the sheet drag automatically. You don't need to worry about stuff like `DraggableScrollableSheet`. Just smooth, physics-driven motion powered by [motor](https://pub.dev/packages/motor).

## Installation

```sh
flutter pub add stupid_simple_sheet
```

## Quick start

Push a sheet like you push any route:

```dart
Navigator.of(context).push(
  StupidSimpleGlassSheetRoute(
    child: YourContent(),
  ),
);
```

That gives you an iOS 26 glass sheet with spring physics and seamless scroll-to-drag transitions out of the box.

## Important

Content inside the sheet should **not** define any custom `ScrollConfiguration`. The sheet relies on default scroll behavior to detect scroll boundaries and transition between scrolling and dragging.

## Cookbook

Each recipe below is a self-contained pattern you can copy into your project. Full runnable examples live in the [`example/`](./example/lib/) directory.

---

### Glass sheet (iOS 26)

The modern iOS sheet style with liquid glass blur. Glass sheets stack seamlessly -- only the first sheet blurs the backdrop.

> [Full example](./example/lib/presets/glass_sheet_preset.dart)

 ![Glass Sheet](doc/glass.gif)

```dart
Navigator.of(context).push(
  StupidSimpleGlassSheetRoute(
    child: YourContent(),
  ),
);
```

---

### Cupertino sheet

The classic iOS modal sheet with push-back transitions on the route behind.

> [Full example](./example/lib/presets/cupertino_sheet_preset.dart)

![Cupertino Sheet](doc/cupertino.gif)

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    child: CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Sheet'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => CupertinoListTile(
                title: Text('Item #$index'),
              ),
              childCount: 50,
            ),
          ),
        ],
      ),
    ),
  ),
);
```

---

### Customizing preset routes

Both `StupidSimpleCupertinoSheetRoute` and `StupidSimpleGlassSheetRoute` accept
`shape` and `backgroundColor` to tweak their appearance without building a
custom route:

```dart
StupidSimpleCupertinoSheetRoute(
  backgroundColor: CupertinoColors.systemGroupedBackground,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  child: YourContent(),
)
```

---

### Non-draggable sheet

A sheet that can only be closed programmatically. Useful for confirmation dialogs or critical flows.

> [Full example](./example/lib/recipes/non_draggable.dart)

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    draggable: false,
    child: YourContent(), // Must include a close button
  ),
);
```

---

### Preventing dismiss with PopScope

Wrap content in Flutter's `PopScope` to prevent drag-to-dismiss while still
allowing the user to drag the sheet between snap points. The sheet automatically
applies rubber-band resistance when dragged below the lowest snap.

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    snappingConfig: SheetSnappingConfig([0.5, 1.0]),
    child: PopScope(
      canPop: false, // prevents drag-to-dismiss
      child: YourContent(),
    ),
  ),
);
```

> This differs from `draggable: false`, which disables all drag gestures
> entirely. `PopScope` only prevents the dismiss -- the sheet is still
> draggable between its snap points.

---

### Snapping sheet (multi-stop)

A sheet that snaps to specific positions. Combine `SheetSnappingConfig` with
`initialSnap` to control where the sheet opens.

> [Full example](./example/lib/recipes/snapping_recipe.dart)

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    snappingConfig: SheetSnappingConfig(
      [0.5, 1.0], // half-open and full
      initialSnap: 0.5,
    ),
    child: YourContent(),
  ),
);
```

You can dynamically change snapping at runtime from inside the sheet:

```dart
final controller = StupidSimpleSheetController.maybeOf(context);
// Remove intermediate snaps, animate to comply
controller?.overrideSnappingConfig(
  SheetSnappingConfig.full,
  animateToComply: true,
);
// Reset back to original config
controller?.overrideSnappingConfig(null);
```

---

### Sheet with a persistent footer (shrink dismissal)

Use `DismissalMode.shrink` to make the sheet collapse from the top instead of
sliding down. Because `ShrinkTransition` pins content to the **bottom**, any
footer stays visible as the sheet shrinks -- perfect for share sheets, action
bars, or confirmation buttons.

> [Full example](./example/lib/recipes/sticky_footer_recipe.dart)

![Shrink Sheet](doc/shrink.gif)

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    dismissalMode: DismissalMode.shrink,
    snappingConfig: SheetSnappingConfig([0.5, 1.0]),
    child: SafeArea(
      child: Column(
        children: [
          // Header
          Text('Share with...'),

          // Scrollable content — shrinks away first
          Expanded(child: ListView(...)),

          // Footer — stays pinned at bottom during shrink
          Row(
            children: [
              Expanded(child: CupertinoButton(child: Text('Copy Link'), ...)),
              Expanded(child: CupertinoButton.filled(child: Text('Send'), ...)),
            ],
          ),
        ],
      ),
    ),
  ),
);
```

**How it works:** With `DismissalMode.slide` (the default), the entire sheet
translates downward. With `DismissalMode.shrink`, the visible height of the
sheet decreases instead. The child is laid out at full size and clipped from the
top, so bottom-aligned content (footers, buttons) remains on screen the longest.

---

### Resizing sheet (content-sized)

A small floating card that sizes to fit its content. Use
`originateAboveBottomViewInset` to keep the sheet above the keyboard at all times.

> [Full example](./example/lib/recipes/content_sized_above_keyboard.dart)

![Resizing Sheet](doc/resizing.gif)

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    originateAboveBottomViewInset: true,
    motion: CupertinoMotion.smooth(),
    child: SafeArea(
      child: Card(
        margin: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // size to content
          children: [
            CupertinoTextField(placeholder: 'Type something...'),
            // Content can grow dynamically
          ],
        ),
      ),
    ),
  ),
);
```

Note: `StupidSimpleSheetRoute` provides **no background, shape, or SafeArea by
default** -- you style everything yourself. This is what lets you build floating
cards, full-bleed layouts, or anything else.

---

### Unstyled sheet (`StupidSimpleSheetRoute`)

`StupidSimpleSheetRoute` is the bare-bones base. It provides no background,
shape, or safe area -- giving you total control. Wrap content in
`SheetBackground` if you want the standard look:

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    child: SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: SheetBackground(
        child: YourContent(),
      ),
    ),
  ),
);
```

`SheetBackground` gives you:
- Rounded superellipse shape (24px radius)
- Theme surface color
- Anti-aliased clipping
- Automatic background extension to cover overdrag

Customize it:

```dart
SheetBackground(
  backgroundColor: Colors.blue.shade50,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  child: YourContent(),
)
```

---

### Programmatic control

Use `StupidSimpleSheetController` from inside the sheet to animate position or
change snapping:

```dart
Builder(
  builder: (context) {
    final controller = StupidSimpleSheetController.maybeOf<void>(context);

    return ElevatedButton(
      onPressed: () => controller?.animateToRelative(0.5),
      child: Text('Half Open'),
    );
  },
)
```

| Method                                              | Description                                                                                 |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `animateToRelative(position, {snap})`               | Animate to a position between 0.0-1.0. Pass `snap: true` to snap to the nearest snap point. |
| `overrideSnappingConfig(config, {animateToComply})` | Change or reset (`null`) snapping at runtime.                                               |

To **close** the sheet, use `Navigator.pop(context)`.

---

### Background snapshotting

Rasterize the route behind the sheet into a GPU texture for smoother transitions:

```dart
StupidSimpleCupertinoSheetRoute(
  backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
  child: YourContent(),
)
```

| Mode             | Snapshots when                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------ |
| `never`          | Never (default). Background is always painted live.                                        |
| `always`         | Entire lifetime. Best for static backgrounds.                                              |
| `animating`      | During animations and drags only. Live when settled.                                       |
| `settled`        | When settled only. Live during animations.                                                 |
| `openAndForward` | During the opening animation and while settled at max snap. Live during drags and closing. |

---

### Custom routes (maximum control)

For full control, create a custom route using `StupidSimpleSheetTransitionMixin`:

```dart
class MySheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T> {
  MySheetRoute({required this.child});

  final Widget child;

  @override
  final Motion motion = CupertinoMotion.smooth(snapToEnd: true);

  @override
  final SheetSnappingConfig snappingConfig = SheetSnappingConfig.full;

  @override
  Widget buildContent(BuildContext context) => child;

  @override
  double get overshootResistance => 50;

  @override
  Color? get barrierColor => Colors.black26;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;
}
```

---

[flutter_install_link]: https://flutter.dev/docs/get-started/install
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40
