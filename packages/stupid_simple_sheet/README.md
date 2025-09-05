# Stupid Simple Sheet

[![Pub Version](https://img.shields.io/pub/v/stupid_simple_sheet)](https://pub.dev/packages/stupid_simple_sheet)
[![Coverage](./coverage.svg)](./test/)
[![lintervention_badge]]([lintervention_link])
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

A simple yet powerful sheet widget for Flutter with seamless scroll-to-drag transitions.

## What makes it unique ✨

**Smooth transitioning from any scrolling child to the drag gestures of the mobile sheet.** The sheet automatically detects when scrollable content reaches its bounds and seamlessly transitions to sheet dragging behavior - no complex gesture coordination required.

**Powered by Motor physics simulations** to make the sheet feel incredibly natural and responsive. The spring physics create smooth, realistic motion that feels right at home on any device.

The sheet works perfectly with:
- `ListView`
- `CustomScrollView` 
- `PageView`
- Any scrollable widget

## ⚠️ Important Warning

**Content inside the sheet should not define any custom `ScrollConfiguration`.** The sheet relies on the default Flutter scroll behavior to properly detect scroll boundaries and transition between scrolling and dragging states.

## Installation 💻

**❗ In order to start using Stupid Simple Sheet you must have the [Flutter SDK][flutter_install_link] installed on your machine.**

Add it to your pubspec.yaml:

```yaml
dependencies:
  stupid_simple_sheet: ^0.3.0-dev.3
```

Or install via `flutter pub`:

```sh
flutter pub add stupid_simple_sheet
```

## Usage 🚀

### Basic Sheet

The basic sheet comes with very little styling.

You are responsible for wrapping your child in the appropriate shapes, paddings, `SafeArea` etc.

This might seem like a drawback, but it gives you all the freedom you could imagine.

Watch for example, how using a `SingleChildScrollView` effortlessly handles making overflowing content scrollable:

![Resizing Sheet](doc/resizing.gif)


```dart
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

// Show a basic sheet
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    child: YourSheetContent(),
  ),
);
```

### Cupertino-style Sheet

This library also provides a Cupertino-style modal sheet.

![Cupertino Sheet](doc/cupertino.gif)

```dart
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    child: CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Sheet'),
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

### Customizing Motion

```dart
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    motion: CupertinoMotion.bouncy(snapToEnd: true),
    child: YourContent(),
  ),
);
```

### Custom Routes with Maximum Control

For advanced use cases, you can create your own custom routes using the `StupidSimpleSheetTransitionMixin` for maximum control over the sheet behavior:

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
    // Build your custom sheet content with full control
    // For example you might want to render a background that extends past the bottom of the screen
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

  // Override any other properties for complete customization
  @override
  double get overshootResistance => 50; // Custom resistance
  
  @override
  Color? get barrierColor => Colors.black26;
}
```

This approach gives you complete control over the sheet's appearance, behavior, and physics while still benefiting from the smooth scroll-to-drag transitions.

## Features 🎯

- **Seamless scroll transitions**: Automatically handles the transition between scrolling content and sheet dragging
- **Spring physics**: Natural motion using the `motor` package physics engine  
- **Customizable appearance**: Control shape, clipping, and barrier properties
- **Cupertino integration**: Works perfectly with Cupertino design components
- **Gesture coordination**: No need to manually handle gesture conflicts
- **Multiple scroll types**: Supports all Flutter scrollable widgets
- **Extensible architecture**: Use the mixin to create custom routes with full control


## Examples 📱

Check out the [example app](./example/) to see the sheet in action with:
- Scrollable lists
- Paged content with PageView
- Dynamically resizing sheets
- Different motion configurations

---

[flutter_install_link]: https://flutter.dev/docs/get-started/install
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40