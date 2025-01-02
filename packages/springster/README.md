# Springster

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Spring animations and simulations, simplified.

Mostly adapted and heavily inspired by [fluid_animations](https://pub.dev/packages/fluid_animations).

## Features 🎯

- 🎨 Simple spring-based animations with customizable bounce and duration
- 🔄 Spring-based draggable widgets with smooth return animations
- 🎯 Spring curve for use with standard Flutter animations
- 🪝 Flutter Hooks support for spring animations
- 📱 2D spring animations for complex movements

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

### Simple Spring Animation

Use `SpringBuilder` for basic spring animations:

```dart
SpringBuilder(
  spring: SimpleSpring.bouncy,
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

### Spring Draggable

Create draggable widgets with spring return animations:

```dart
SpringDraggable(
  spring: SimpleSpring.interactive,
  child: Container(
    width: 100,
    height: 100,
    color: Colors.blue,
  ),
  feedback: Container(
    width: 100,
    height: 100,
    color: Colors.blue.withOpacity(0.5),
  ),
  data: 'my-draggable-data',
)
```

### Spring Curve

Use spring physics in standard Flutter animations:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 500),
  curve: SpringCurve(spring: SimpleSpring.bouncy),
  width: targetWidth,
  height: targetHeight,
)
```

### Hook Usage

For more control using Flutter Hooks:

```dart
final animatedValue = useSpringAnimation(
  value: targetValue,
  spring: SimpleSpring.smooth,
);

// For 2D animations
final (x, y) = use2DSpringAnimation(
  value: (targetX, targetY),
  spring: SimpleSpring.bouncy,
);
```

## Predefined Springs 🎯

Springster comes with several predefined spring configurations:

- `SimpleSpring.instant` - An effectively instant spring
- `SimpleSpring.defaultIOS` - iOS-style smooth spring with no bounce
- `SimpleSpring.bouncy` - Spring with higher bounce
- `SimpleSpring.smooth` - Smooth spring with no bounce
- `SimpleSpring.snappy` - Snappy spring with small bounce
- `SimpleSpring.interactive` - Lower response spring for interactive animations

You can also create custom springs:

```dart
const mySpring = SimpleSpring(
  duration: 0.5, // Settling duration
  bounce: 0.2,   // Bounce amount (-1 to 1)
);

// Or using damping fraction
const mySpring = SimpleSpring.withDamping(
  dampingFraction: 0.7,
  duration: 0.5,
);
```

## Additional Information 📚

- This package is built with [Mason][mason_link]
- Maintained with [Melos][melos_link]
- Licensed under MIT

[dart_install_link]: https://dart.dev/get-dart
[mason_link]: https://github.com/felangel/mason
[melos_link]: https://github.com/invertase/melos
