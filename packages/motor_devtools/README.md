# Motor DevTools

An optional in-app inspector for [`motor`](https://pub.dev/packages/motor).
A small bubble floats above your app. Tap it to see every live Motor
controller; tap a controller to pause it, scrub its timeline, slow it down,
replay it, or try a different motion on one of its tracks.

| Bubble | Controllers | Controller | Scrubbing |
|---|---|---|---|
| ![The floating bubble](doc/bubble.png) | ![The controller list](doc/controller-list.png) | ![A controller's timeline and controls](doc/controller-detail.png) | ![Scrubbing a sync barrier in dark mode](doc/scrubbing-dark.png) |

## Use it

Add `motor_devtools` next to `motor`, then wrap your app:

```dart
import 'package:flutter/foundation.dart';
import 'package:motor_devtools/motor_devtools.dart';

MaterialApp(
  builder: (context, child) => MotorDevTools(
    enabled: kDebugMode,
    child: child!,
  ),
  home: const CheckoutPage(),
);
```

`MotorDevTools` also works around a `MaterialApp`, `CupertinoApp`, or
`WidgetsApp`. It brings its own neutral styling, follows the platform's light
or dark mode, and does not depend on Material or Cupertino.

## Name your controllers

The list shows each controller's `debugLabel`. Unnamed controllers show up as
"Controller 1", "Controller 2", and so on, so name the ones you care about.
Every controller and builder takes a `debugLabel`, and so does every track:

```dart
final controller = TrackController(
  vsync: this,
  debugLabel: 'Checkout confirmation',
);

final cardScale = Track<double>(
  MotionConverter.single,
  initial: 0,
  debugLabel: 'Card scale',
);

SingleMotionBuilder(
  value: expanded ? 1 : 0,
  motion: const Motion.smoothSpring(),
  debugLabel: 'Sheet expansion',
  builder: (context, value, child) => ...,
);
```

`MotionController`, `SingleMotionController`, `BoundedMotionController`,
`TrackBuilder`, `PhaseTrackBuilder`, `MotionBuilder`, `VelocityMotionBuilder`
and `MotionDraggable` all accept `debugLabel` too.

## What you can do

- **Move the bubble.** Drag it anywhere, or fling it. It settles on the
  nearest side of the screen.
- **See every controller.** The list shows whether each one is playing,
  paused or idle, and which tracks it animates.
- **Pause, resume and replay.** Play resumes where you paused or scrubbed to,
  and replays the latest plan once it has finished.
- **Scrub.** Drag across the timeline, or tap it, to move the controller to
  that point. Each lane is a track: bars are motions, thin lines are holds,
  dots are waits at a sync barrier. The part left of the playhead has
  played. Looping plans show one cycle at a time.
- **Slow down.** Run one controller at 0.1×, 0.25×, 0.5× or full speed
  without touching Flutter's global time dilation.
- **Try another motion.** Swap a track's motion for a spring, an ease or a
  linear motion, and tune its duration and bounce. The latest plan replays
  right away.

Speed and motion changes last for the session. They are undone when
`MotorDevTools` is disabled or removed.

To open or close the panel from code, pass a `MotorDevToolsController`.

## Production builds

`enabled` is a normal runtime flag, so you can deliberately ship the tools to
testers:

```dart
MotorDevTools(
  enabled: kDebugMode || featureFlags.motionLab,
  child: app,
)
```

When disabled, `MotorDevTools` returns its child and does not attach to
Motor's inspection registry. Motor keeps no global list of controllers until
a tool attaches, and apps that never import `motor_devtools` can tree-shake
it entirely. Debug labels are plain strings in your app, so don't put secrets
in them.

The tools use motor's inspection API (`package:motor/inspection.dart`), which
is experimental and may change in minor releases.
