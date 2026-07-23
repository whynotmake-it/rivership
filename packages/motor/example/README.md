# Motor example

An interactive teaching app for building interruptible, physics-based Flutter
motion with Motor.

## Feel the difference

- **Instant vs. Animated** — see why continuous motion preserves context.
- **The Curve Trap** — compare a curve’s velocity reset with a spring redirect.
- **Spring Character** — tune duration and bounce to shape motion’s personality.
- **More Than One Dimension** — carry gesture velocity across independent axes.

## Tracks

- **Meet Tracks** — give animated values stable identity and remembered velocity.
- **Timelines & Steps** — compose ordered motion, inspect it live, and scrub it.
- **Sync Barriers** — watch independent clocks converge on a recorded barrier.
- **Phases** — model interruptible UI stories as named, settled states.

## Gestures × timelines

- **Toggle** — pass drag velocity into a settling spring.
- **Pull to Refresh** — project a release before deciding whether to commit.
- **Card Stack** — turn gesture outcomes into composable motion phases.
- **Payment Success** — coordinate many tracks around a shared checkpoint.
- **Boarding Pass** — inspect a five-lane choreography while interrupting it.

## Recipes

- **Snap Carousel** — project momentum toward the nearest snap point.
- **Toast** — preserve swipe velocity when dismissing transient content.
- **Picture in Picture** — project two-dimensional motion toward a stable corner.
- **Draggable Icons** — add spring-backed drag and drop with `MotionDraggable`.

## Run the app

From this directory:

```sh
flutter run
```

See the [Motor package README](../README.md) for installation and API
documentation.

## FAQ

**What is a Motion?** A `Motion` describes how a value travels to its target:
a spring, curve, or custom simulation. The same widget code works with any of
them.

**Do I need an AnimationController?** No. Motor manages the ticker. Its builders
animate implicitly whenever their target changes.

**Can motion be interrupted?** Yes. Springs preserve velocity when the target
changes mid-flight, so redirected motion stays smooth.

**How do I animate many properties?** Use tracks. Each property can have its own
steps and motion while all tracks advance on a shared clock.

**Can I inspect a running timeline?** Yes. The timeline examples attach a live
inspector directly to `TrackController`. Solid segments are engine-recorded
timings, dotted segments are estimates, and dragging pauses, scrubs, and resumes
the real controller.
