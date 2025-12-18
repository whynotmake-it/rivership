# Stupid Simple Sheet

[![Pub Version](https://img.shields.io/pub/v/stupid_simple_sheet)](https://pub.dev/packages/stupid_simple_sheet)
[![Coverage](./coverage.svg)](./test/)
[![lintervention_badge]]([lintervention_link])
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

A simple yet powerful sheet widget for Flutter with seamless scroll-to-drag transitions.

## What makes it unique

**Smooth transitioning from any scrolling child to the drag gestures of the mobile sheet.** The sheet automatically detects when scrollable content reaches its bounds and seamlessly transitions to sheet dragging behavior - no complex gesture coordination required.

**Powered by Motor physics simulations** to make the sheet feel incredibly natural and responsive. The spring physics create smooth, realistic motion that feels right at home on any device.

The sheet works perfectly with:
- `ListView`
- `CustomScrollView` 
- `PageView`
- Any scrollable widget

## Important Warning

**Content inside the sheet should not define any custom `ScrollConfiguration`.** The sheet relies on the default Flutter scroll behavior to properly detect scroll boundaries and transition between scrolling and dragging states.

## Installation

**In order to start using Stupid Simple Sheet you must have the [Flutter SDK][flutter_install_link] installed on your machine.**


Install via `flutter pub`:

```sh
flutter pub add stupid_simple_sheet
```

## Usage

### Understanding the Base Sheet

`StupidSimpleSheetRoute` is intentionally minimal - it provides **no background, shape, or SafeArea by default**. This gives you complete freedom to build any style of sheet:

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    child: YourSheetContent(), // You control all styling
  ),
);
```

This design lets you create sheets that don't look like traditional sheets at all - floating cards, full-bleed content, custom shapes, or anything else you can imagine.

### Common Use Cases

#### 1. Standard Modal Sheet with Background

For a typical modal sheet with rounded corners and a background, wrap your content in `SheetBackground`:

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    child: SafeArea(
      // Most sheets should only avoid the top safe area, the rest should be avoided
      // inside the sheet content as needed.
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

`SheetBackground` provides:
- Rounded superellipse shape (24px radius at top)
- Theme's surface color as background
- Anti-aliased clipping
- Automatic background extension to handle overdrag

You can customize it:

```dart
SheetBackground(
  backgroundColor: Colors.blue.shade50,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  clipBehavior: Clip.hardEdge,
  child: YourContent(),
)
```

#### 2. Cupertino-style Sheet

For iOS-style modal sheets that push the previous screen back:

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

#### 3. Small Floating Sheet (Resizing Content)

For sheets that size to fit their content and can grow/shrink dynamically:

![Resizing Sheet](doc/resizing.gif)

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    motion: CupertinoMotion.smooth(),
    originateAboveBottomViewInset: true, // Stays above keyboard
    child: SafeArea(
      child: Card(
        margin: EdgeInsets.all(8),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Size to content
          children: [
            // Your content here
            CupertinoTextField(placeholder: 'Type something...'),
            // Content can grow dynamically
          ],
        ),
      ),
    ),
  ),
);
```

#### 4. Sheet with Snapping Points

Create sheets that snap to specific positions (e.g., half-open, full):

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    snappingConfig: SheetSnappingConfig.relative(
      [0.5, 1.0], // Snap at 50% and 100%
      initialSnap: 0.5, // Start half-open
    ),
    child: YourContent(),
  ),
);
```

#### 5. Non-Draggable Sheet

For sheets that can only be closed programmatically:

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    draggable: false,
    child: YourContent(), // Must include a close button
  ),
);
```

#### 6. Sheet with PageView

The sheet handles horizontal paging seamlessly:

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    child: CupertinoPageScaffold(
      child: PageView(
        children: [
          CustomScrollView(/* Page 1 content */),
          CustomScrollView(/* Page 2 content */),
        ],
      ),
    ),
  ),
);
```

### Customizing Motion

Control the sheet's animation physics:

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    motion: CupertinoMotion.bouncy(snapToEnd: true),
    child: YourContent(),
  ),
);
```

### Programmatic Control with StupidSimpleSheetController

Control the sheet's position from within its content:

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    child: Builder(
      builder: (context) {
        final controller = StupidSimpleSheetController.maybeOf<void>(context);
        
        return Column(
          children: [
            ElevatedButton(
              onPressed: () {
                // Animate to half-open position
                controller?.animateToRelative(0.5);
              },
              child: Text('Half Open'),
            ),
            ElevatedButton(
              onPressed: () {
                // Animate to fully open with snapping
                controller?.animateToRelative(0.8, snap: true);
              },
              child: Text('Almost Full (with snap)'),
            ),
          ],
        );
      },
    ),
  ),
);
```

#### Controller Methods

- **`maybeOf<T>(BuildContext context)`**: Retrieves the controller from a context within the sheet. Returns `null` if called from outside a sheet.
- **`animateToRelative(double position, {bool snap = false})`**: Animates the sheet to a relative position between 0.0 (closed) and 1.0 (fully open).
- **`overrideSnappingConfig(SheetSnappingConfig? config, {bool animateToComply = false})`**: Dynamically change or disable snapping behavior.

**Note**: The controller cannot close the sheet programmatically. To close the sheet, use `Navigator.pop(context)`.

### Custom Routes with Maximum Control

For advanced use cases, create custom routes using `StupidSimpleSheetTransitionMixin`:

```dart
class MyCustomSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T> {
  MyCustomSheetRoute({
    required this.child,
    this.motion = const CupertinoMotion.smooth(snapToEnd: true),
  });

  final Widget child;
  
  @override
  final Motion motion;

  @override
  Widget buildContent(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: -1000,
            child: Material(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  double get overshootResistance => 50;
  
  @override
  Color? get barrierColor => Colors.black26;
}
```

## Features

- **Seamless scroll transitions**: Automatically handles the transition between scrolling content and sheet dragging
- **Spring physics**: Natural motion using the `motor` package physics engine  
- **Programmatic control**: Use `StupidSimpleSheetController` to animate the sheet position
- **Flexible styling**: Build any sheet style with `SheetBackground` or custom widgets
- **Cupertino integration**: Native iOS-style sheets with `StupidSimpleCupertinoSheetRoute`
- **Snapping**: Configure snap points for multi-stop sheets
- **Gesture coordination**: No need to manually handle gesture conflicts
- **Multiple scroll types**: Supports all Flutter scrollable widgets
- **Extensible architecture**: Use the mixin to create custom routes with full control


## Examples

Check out the [example app](./example/) to see the sheet in action with:
- Cupertino-style sheets with navigation bars
- Paged content with PageView
- Dynamically resizing sheets
- Snapping sheets with multiple stops
- Non-draggable sheets

---

[flutter_install_link]: https://flutter.dev/docs/get-started/install
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40
