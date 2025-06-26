# Springster

[![Pub Version](https://img.shields.io/pub/v/springster)](https://pub.dev/packages/springster)
[![Coverage](./coverage.svg)](./test/)
[![lintervention_badge]]([lintervention_link])
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

A simple animation system that unifies physics-based animations with Flutter's animation system.

## Features 🎯

- 🎨 Simple spring-based animations with customizable bounce and duration
- 💡 A unified API for any animation - physics-based or otherwise
- 🎯 Spring curves for use with standard Flutter animations
- 📱 Multi-dimensional spring animations for complex movements
- 🔄 Spring-based draggable widgets with smooth return animations

## Try it out
[Open Example](https://whynotmake-it.github.io/rivership/#/springster)

## Installation 💻

**❗ In order to start using Springster you must have the [Dart SDK][dart_install_link] installed on your machine.**

Add to your `pubspec.yaml`:

```yaml
dependencies:
  springster: ^latest_version
```

Or install via `dart pub`:

```sh
dart pub add springster
```

## Usage 💡

### Motion

The core of Springster's animation configuration is the `Motion` class. It represents the **kind** of motion that will be used to animate the widget.

```dart
final classic = Motion.duration(Duration(seconds: 1));

final withCurve = Motion.durationAndCurve(
  duration: Duration(seconds: 1), 
  curve: Curves.easeInOut,
);

final spring = Motion.spring(Spring.bouncy);
```

At the moment, two types of motions are supported out of the box, but you can create your own custom motions by implementing the `Motion` interface.

- `SpringMotion` - A motion that animates using a dynamically redirecting spring simulation. The default on Apple platforms and in SwiftUI.
- `DurationAndCurve` - A motion that animates over a given duration with a curve, very much what Flutter does everywhere.

### Simple Animation

Use `SingleMotionBuilder` for basic, one-dimensional animations:

![1D Hover example gif](./doc/1d_hover.gif)

```dart
SingleMotionBuilder(
  motion: Motion.spring(Spring.bouncy),
  value: targetValue, // Changes trigger smooth spring animation
  builder: (context, value, child) {
    return Container(
      width: value,
      height: value,
      color: Colors.blue,
    );
  },
)
```

If you want to animate more complex types, such as `Offset`, `Size`, or `Rect`, you can use `MotionBuilder` and pass a so-called `MotionConverter` to it:

![2D Redirection example gif](./doc/2d_redirect.gif)

```dart
MotionBuilder(
  motion: Motion.spring(Spring.bouncy),
  value: const Offset(100, 100),
  from: Offset.zero,
  converter: OffsetMotionConverter(),
  builder: (context, value, child) {
    return Transform.translate(
      offset: Offset(value.x, value.y),
      child: child,
    );
  },
  child: Container(
    width: 100,
    height: 100,
    color: Colors.blue,
  ),
)
```


### MotionConverter

Flutter's basic animation system often relies on a combination of one-dimensional animations, combined with `Tween`s to animate more complex types.

For high-fidelity simulation-based animations however, it is often necessary to simulate each dimension independently.

Let's say for example, you want to animate a draggable icon (see below for an example). The user might fling this icon horizontally, which means
the horizontal velocity is high, but the vertical velocity is low. If we would run the same animation to drive the `Offset` of the icon, we would
loose control over this difference, and the animation would feel unnatural.

This is where `MotionConverter`s come in. They allow you to convert any type into a multi-dimensional array.

For often-used Flutter types, these are already implemented:

- `OffsetMotionConverter`
- `SizeMotionConverter`
- `RectMotionConverter`
- `AlignmentMotionConverter`

However, you might want your very custom type to be animated as well. For this, you can implement your own `MotionConverter` and pass it to the `MotionBuilder` constructor.

```dart
class My3DMotionConverter implements MotionConverter<Vector3> {
  @override
  List<double> normalize(Vector3 value) => [value.x, value.y, value.z];

  @override
  Vector3 denormalize(List<double> values) => Vector3(values[0], values[1], values[2]);
}

Widget build(BuildContext context) {
  return MotionBuilder(
    motion: Motion.spring(spring: Spring.bouncy),
    value: Vector3(100, 100, 100),
    converter: My3DMotionConverter(),
    // ...
  );
}
```

Or, just use `MotionConverter` directly and pass the converter functions to its constructor:

```dart
final converter = MotionConverter(
  normalize: (value) => [value.x, value.y, value.z],
  denormalize: (values) => Vector3(values[0], values[1], values[2]),
);
```



### Motion Draggable

`springster` also comes with a `MotionDraggable` widget that allows you to drag a widget around the screen with a dynamic return animation.
It works just like the `Draggable` widget in Flutter and supports native Flutter `DragTarget`s, however it comes with a few sensible defaults and extra features.

![Spring Draggable example gif](./doc/spring_draggable.gif)

```dart
MotionDraggable(
  motion: Motion.spring(Spring.bouncy),
  child: Container(
    width: 100,
    height: 100,
    color: Colors.blue,
  ),
  data: 'my-draggable-data',
)
```

### Low-level Animation/Simulation

If you need more control over your animations, you can use the `MotionController` for any of your types, or `SingleMotionController` for one-dimensional animations.

```dart
final controller = MotionController(
  motion: Motion.spring(Spring.bouncy),
  vsync: this,
);
```

They work similarly to the `AnimationController` class in Flutter and allow you to drive the spring simulation with a target value, while maintaining velocity between target changes.

#### Bounded vs. Unbounded Motion

In Flutter, the `AnimationController` can be either bounded or unbounded. `MotionController`s come in both flavors as well, but they differ in key ways:


##### `MotionController`:
- By default, `MotionController`s are unbounded.
- Unbounded `MotionController`s don't have `forward` or `reverse` methods, since they don't make sense in multi-dimensional space.

##### `BoundedMotionController`:
- requires you to specify a `lowerBound` and `upperBound` in the constructor.
- exposes `forward` and `reverse` methods, which internally animate towards the `upperBound` and `lowerBound` respectively.
- will clamp the animation value to be within the bounds, but they can still overshoot as part of their `Motion` simulation.

## Predefined Springs 🎯

Springster comes with several predefined spring configurations:

- `const Spring()` - Smooth spring with no bounce
- `Spring.instant` - An effectively instant spring
- `Spring.defaultIOS` - iOS-style smooth spring with no bounce
- `Spring.bouncy` - Spring with higher bounce
- `Spring.snappy` - Snappy spring with small bounce
- `Spring.interactive` - Lower response spring for interactive animations

You can also create custom springs:

```dart
const mySpring = Spring(
  duration: 0.5, // Settling duration
  bounce: 0.2,   // Bounce amount (-1 to 1)
);

// Or using damping fraction
const mySpring = Spring.withDamping(
  dampingFraction: 0.7,
  duration: 0.5,
);
```

## Migration Guide

### Migrating to 1.0.0

### From SpringDraggable to MotionDraggable

```dart
// Old code
SpringDraggable(
  data: icon,
  spring: Spring.bouncy,
  // ...
)

// New code
MotionDraggable(
  data: icon,
  motion: const SpringMotion(Spring.bouncy),
  // ...
)
```

### From SpringBuilder to SingleMotionBuilder

```dart
// Old code
SpringBuilder(
  value: 0.5,
  spring: Spring.bouncy,
  builder: (context, value, child) { /* ... */ },
)

// New code
SingleMotionBuilder(
  value: 0.5,
  motion: SpringMotion(Spring.bouncy),
  builder: (context, value, child) { /* ... */ },
)
```

### From SpringBuilder2D to MotionBuilder
This depends on what you are using 2D values for.

Let's say you are using 2D values to animate an `Offset`.

```dart
// Old code
SpringBuilder2D(
  value: (100, 100),
  spring: Spring.bouncy,
  builder: (context, value, child) {
    return Transform.translate(
      offset: Offset(value.x, value.y),
      child: child,
    );
  },
)

// New code
MotionBuilder(
  motion: Motion.spring(spring: Spring.bouncy),
  value: Offset(100, 100),
  converter: OffsetMotionConverter(),
  builder: (context, value, child) {
    return Transform.translate(
      offset: value,
      child: child,
    );
  },
)
```

### From SpringSimulationController to SingleMotionController

```dart
// Old code
final controller = SpringSimulationController(
  spring: Spring.bouncy,
  vsync: this,
  lowerBound: 0,
  upperBound: 1,
)

// New code
final controller = SingleMotionController.bounded(
  motion: SpringMotion(Spring.bouncy),
  vsync: this,
  lowerBound: 0,
  upperBound: 1,
)
```

---

## Acknowledgements

Springster's spring math was partially adapted from and heavily inspired by [fluid_animations](https://pub.dev/packages/fluid_animations).

[dart_install_link]: https://dart.dev/get-dart
[mason_link]: https://github.com/felangel/mason
[melos_link]: https://github.com/invertase/melos
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40