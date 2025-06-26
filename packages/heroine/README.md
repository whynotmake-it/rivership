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
  spring: Spring.bouncy, // Customize your springs!
  child: MyWidget(),
)
```

Available shuttle builders:
- `FadeShuttleBuilder` - Smooth fade transition
- `FlipShuttleBuilder` - 3D flip animation
- `SingleShuttleBuilder` - Only displays the destination widget – like Flutter's default hero transition

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

## Spring Configuration 🎯

Heroine uses [Motor](https://pub.dev/packages/motor) for motion animations. You can customize the motion:

```dart
final springMotion = SpringMotion(
  Spring.withDurationAndBounce(
    duration: Duration(milliseconds: 500), 
    bounce: 0.5,
  ),
);

final cupertinoMotion = CupertinoMotion.smooth;

final linearMotion = DurationAndCurve(duration: Duration(milliseconds: 300));

// Then pass it to the Heroine widget
return Heroine(
  tag: 'unique-tag',
  spring: springMotion,
  child: MyWidget(),
);
```

## Advanced Features 🚀

### Velocity-Aware Transitions

Provide velocity information for smoother transitions from gestures:

```dart
HeroineVelocity(
  velocity: dragVelocity,
  child: Heroine(
    tag: 'unique-tag',
    child: MyWidget(),
  ),
)
```

Check out the implementation of `DragDismissable`, to see how that widget uses `HeroineVelocity` to pass the user's drag velocity to the heroine.

### Route Transition Duration

You can have `Heroine` adjust the timing of its spring to match the duration of the route transition:

```dart
Heroine(
  tag: 'unique-tag',
  adjustToRouteTransitionDuration: true,
  child: MyWidget(),
)
```

For full control however, just pass in a custom `Spring` to the `Heroine` widget with whatever duration you want.

## Best Practices 📝

1. Use unique tags for each hero pair
2. Keep heroine widget's shapes similar in both routes
3. Consider using `adjustToRouteTransitionDuration` for smoother transitions
4. Test transitions with different spring configurations
5. Handle edge cases with custom shuttle builders

---

[mason_link]: https://github.com/felangel/mason
[mason_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40
[flutter_install_link]: https://docs.flutter.dev/get-started/install

