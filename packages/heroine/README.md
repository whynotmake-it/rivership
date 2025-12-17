# Heroine

[![Code Coverage](./coverage.svg)](./test/)
[![Powered by Mason][mason_badge]][mason_link]
[![lints by lintervention][lintervention_badge]][lintervention_link]
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

The queen of hero transitions. Flutter's most addictive interactions.

![Showcase GIF](doc/main.gif)


> "this will be such an addictive #FlutterDev interaction!"
>
> ~ [Mike Rydstrom](https://x.com/RydMike/status/1876323718194184657)

## Features 🎯

- 🌊 Smooth spring-based hero transitions with customizable bounce and duration
- 🔄 Drag-to-dismiss gestures with velocity-aware animations
- 🎨 Beautiful transition effects with customizable shuttle builders
- 📱 Route-aware transitions that adapt to navigation gestures
- 🎯 Seamless integration with Flutter's navigation system

## Try it out

[Open Example](https://whynotmake-it.github.io/rivership/#/heroine)

## Installation 💻

**❗ In order to start using Heroine you must have the [Flutter SDK][flutter_install_link] installed on your machine.**

Add to your `pubspec.yaml`:

```yaml
dependencies:
  heroine: ^latest_version
```

Or install via `flutter pub`:

```sh
flutter pub add heroine
```

## Usage 💡

### Set up HeroineController for your app

To use heroines in your app, it is important that you register a `HeroineController` in your app's navigator.

```dart
MaterialApp( // or CupertinoApp, or WidgetsApp
  home: MyHomePage(),
  navigatorObservers: [HeroineController()],
)
```

> **Note:** In some nested routing scenarios, `HeroineController` might have to be registered in all of the nested navigators as well.

### Basic Hero Transition

Use `Heroine` for spring-based hero transitions between routes, just like you would with the `Hero` widget:

```dart
// In the source route
Heroine(
  tag: 'unique-tag',
  child: MyWidget(),
)

// In the destination route
Heroine(
  tag: 'unique-tag',
  child: MyExpandedWidget(),
)
```

### Custom Transition Effects

Choose from predefined shuttle builders or create your own:

```dart
Heroine(
  tag: 'unique-tag',
  flightShuttleBuilder: const FlipShuttleBuilder(
    axis: Axis.vertical,
    halfFlips: 1,
  ),
  motion: Motion.bouncySpring(),
  child: MyWidget(),
)
```

Available shuttle builders:
- `FadeShuttleBuilder` - Smooth fade transition between heroes
- `FlipShuttleBuilder` - 3D flip animation with customizable axis and direction
- `SingleShuttleBuilder` - Only displays the destination widget – like Flutter's default hero transition
- `FadeThroughShuttleBuilder` - Fades through a specified color during transition
- `ChainedShuttleBuilder` - Combines multiple shuttle builders for complex effects
- `HeroineShuttleBuilder.fromHero()` - Use existing `HeroFlightShuttleBuilder` implementations


#### Chaining Multiple Effects

Combine multiple shuttle builders for complex transitions:

```dart
Heroine(
  tag: 'unique-tag',
  flightShuttleBuilder: const FlipShuttleBuilder()
    .chain(const FadeShuttleBuilder()),
  // or using ChainedShuttleBuilder directly:
  // flightShuttleBuilder: const ChainedShuttleBuilder(
  //   builders: [FlipShuttleBuilder(), FadeShuttleBuilder()],
  // ),
  child: MyWidget(),
)
```

#### Custom Color Fade Through

Fade through a specific color during transition:

```dart
Heroine(
  tag: 'unique-tag',
  flightShuttleBuilder: const FadeThroughShuttleBuilder(
    fadeColor: Colors.white,
  ),
  child: MyWidget(),
)
```

### Drag-to-Dismiss

Enable drag-to-dismiss gestures with spring return animations, by wrapping your `Heroine` in a `DragDismissable` widget:

```dart
DragDismissable(
  onDismiss: () => Navigator.pop(context),
  child: Heroine(
    tag: 'unique-tag',
    child: MyWidget(),
  ),
)
```

### Fullscreen Transitions (aka Container Transform)

Like with Flutter's default hero transition, heroine does not support nested transitions.

Unlike Flutter however, it will allow you to nest heroines, as long as they are not part of the same transition.
This allows you to have fullscreen transitions, in multiple, nested routes like in the fullscreen example.

[Fullscreen Example](doc/fullscreen.gif)

Check out the fullscreen example code: [full_screen.dart](example/lib/full_screen.dart).

### Heroine-aware routes

Make your routes respond to `Heroine` dismiss gestures:

```dart
class MyCustomRoute<T> extends PageRoute<T> with HeroinePageRouteMixin {
  // ... your route implementation, see example for more details
}

// React to dismiss gestures in your UI
ReactToHeroineDismiss(
  builder: (context, progress, offset, child) {
    return Opacity(
      opacity: 1 - progress,
      child: child,
    );
  },
  child: MyWidget(),
)
```

This will fade out `MyWidget` progressively, as the user dismisses the heroine.

If you look closely at the example GIF, you will see that the details page fades out as the user drags the heroine away.


**Warning:** While Heroine throws an assertion error if it detects that you are trying to fly two nested heroines at the same time, it can't check for this in release builds, since it needs to walk the widget tree. If you miss an occurrence of this, it will break your heroine transitions.

## Motion Configuration 🎯

Heroine uses [Motor](https://pub.dev/packages/motor) for motion animations. You can customize the motion:

```dart
final springMotion = Motion.spring(
  Spring.withDurationAndBounce(
    duration: Duration(milliseconds: 500), 
    bounce: 0.5,
  ),
);

final cupertinoMotion = CupertinoMotion.smooth();

final linearMotion = Motion.linear(Duration(milliseconds: 300));

final ease = Motion.curved(Duration(milliseconds: 300), Curves.easeInOut);

// Then pass it to the Heroine widget
return Heroine(
  tag: 'unique-tag',
  motion: springMotion,
  child: MyWidget(),
);
```

## Advanced Features 🚀

### Continuously Track Target

Enable `continuouslyTrackTarget` to handle dynamic layout changes during hero animations:

```dart
Heroine(
  tag: 'unique-tag',
  continuouslyTrackTarget: true,
  child: MyWidget(),
)
```

When enabled on the destination `Heroine`, the animation will check the target widget's position on every frame. If the target moves (e.g., keyboard appears/disappears, device rotates, or any layout change occurs), the animation will smoothly redirect to the new position.

This is particularly useful when:
- Pushing a route with an autofocus text field (keyboard appears mid-animation)
- Handling device rotation during transitions
- Any scenario where layout shifts occur during the hero flight

This works best with spring-based motions like `CupertinoMotion` or `SpringMotion` that can dynamically redirect while retaining velocity. Disabled by default for performance reasons.

### Velocity-Aware Transitions

Provide velocity information for smoother transitions from gestures using `HeroineVelocity`:

```dart
HeroineVelocity(
  velocity: dragVelocity,
  child: Heroine(
    tag: 'unique-tag',
    child: MyWidget(),
  ),
)
```

The `HeroineVelocity` widget automatically provides velocity context to any `Heroine` widgets below it in the widget tree. This is particularly useful when transitioning from gesture-based interactions.

Check out the implementation of `DragDismissable`, to see how that widget uses `HeroineVelocity` to pass the user's drag velocity to the heroine.

For full control however, just pass in a custom `Motion` to the `Heroine` widget with whatever duration you want.

## Available Tools & Widgets 🛠️

### Core Widgets
- **`Heroine`** - The main hero widget with spring-based animations
- **`HeroineController`** - Navigator observer for managing hero transitions
- **`DragDismissable`** - Wrapper for drag-to-dismiss functionality
- **`HeroineVelocity`** - Provides velocity context for gesture-based transitions
- **`ReactToHeroineDismiss`** - Responds to dismiss gestures in your UI

### Route Integration
- **`HeroinePageRouteMixin`** - Mixin for creating heroine-aware routes
- **`HeroinePageRoute`** - Pre-built page route with heroine support

### Shuttle Builders
- **`FadeShuttleBuilder`** - Cross-fade between heroes
- **`FlipShuttleBuilder`** - 3D flip transitions (customizable axis, direction, and flip count)
- **`SingleShuttleBuilder`** - Show only source or destination hero
- **`FadeThroughShuttleBuilder`** - Fade through a specified color
- **`ChainedShuttleBuilder`** - Combine multiple effects
- **`HeroineShuttleBuilder.fromHero()`** - Adapter for existing Flutter hero builders
- **Extension methods** - `.chain()` method for fluent builder chaining

## Best Practices 📝

1. Use unique tags for each hero pair
2. Keep heroine widget's shapes similar in both routes
3. Register `HeroineController` in your app's navigator observers
4. Use `HeroineVelocity` for gesture-driven transitions
5. Test transitions with different motion configurations
6. Handle edge cases with custom shuttle builders
7. Avoid nested heroines in the same transition

---

[mason_link]: https://github.com/felangel/mason
[mason_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40
[flutter_install_link]: https://docs.flutter.dev/get-started/install

