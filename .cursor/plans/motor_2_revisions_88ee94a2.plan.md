---
name: Motor 2.0 Tracks
overview: "Revised Motor 2.0 tracks plan: preserve `Motion.*` source compatibility by introducing `MotionBase`, keep `Motion` as the targeted motion type, add `FreeMotion` for raw physics, and make `TrackTimeline` the reusable unit that owns looping."
todos:
  - id: motion-base
    content: Introduce `MotionBase`, keep `Motion` as the targeted compatibility API, and add `FreeMotion`.
    status: pending
  - id: fixed-duration
    content: Add fixed-duration wrappers for `Motion` and `FreeMotion`; add `scaleTo(Duration)` across the hierarchy.
    status: pending
  - id: track-core
    content: Implement `Track<T>`, `TrackFrom<T>`, `TrackPhases<P>`, `TrackAnimation<T>`, `TrackTimeline`, and `Step<T>`.
    status: pending
  - id: chained-simulation
    content: Implement `ChainedSimulation` with segment boundary detection, strict timing support, and loopable timeline playback.
    status: pending
  - id: track-slot
    content: Extract `_TrackSlot<T>` shared engine from `MotionController` internals.
    status: pending
  - id: motion-controller-play
    content: Add `play` to `MotionController<T>` for `List<Step<T>>` and single-track timelines.
    status: pending
  - id: track-controller
    content: Implement `TrackController` with multi-track playback, lazy init, timeline loops, redirection, and `onStep`.
    status: pending
  - id: multi-track-builder
    content: Implement `MultiTrackMotionBuilder` around `TrackTimeline` plus list convenience.
    status: pending
  - id: phase-motion-builder
    content: Implement `PhaseMotionBuilder<P>` for phase-driven multi-track state.
    status: pending
  - id: migration-shims
    content: Keep `SequenceMotionController` and `SequenceMotionBuilder` as shims over the new APIs for one minor version.
    status: pending
  - id: port-examples
    content: Port `card_stack`, `logo_animation`, `manual_phase`, and `loop_comparison` examples.
    status: pending
isProject: false
---

# Motor 2.0 Tracks

## Mental Model
- `MotionBase` is the sealed root for all motion descriptions.
- `Motion` remains the targeted, source-compatible 1.x motion type. It owns `Motion.curved`, `Motion.linear`, `Motion.smoothSpring`, `Motion.cupertino`, and the other existing target-based factories.
- `FreeMotion` is the new self-directed physics type for friction, gravity, decay, and other simulations that do not need an `end` value.
- `Track<T>` is pure, immutable identity for a logical animated property. It carries a `MotionConverter<T>` and an `initial: T`.
- `TrackAnimation<T>` is an instruction for one track: "animate this track through these steps."
- `TrackTimeline` is the reusable multi-track clip. It owns `List<TrackAnimation>`, `LoopMode`, and optional `from` overrides.
- `MotionController<T>` remains the 1.x single-value controller and gains additive step/timeline playback.
- `TrackController` is the new multi-track controller, backed by the same per-track engine as `MotionController`.
- Widgets stay declarative. `MotionBuilder<T>` remains source-compatible. `MultiTrackMotionBuilder` plays `TrackTimeline` or list convenience input. `PhaseMotionBuilder<P>` covers phase-driven multi-track state.

## Architecture Layers
```text
+-----------------------------------------------------+
|                   Widget layer                       |
|  MotionBuilder<T>    MultiTrackMotionBuilder         |
|  PhaseMotionBuilder<P>                               |
+-----------------------------------------------------+
|                 Controller layer                     |
|  MotionController<T>          TrackController        |
|  BoundedMotionController<T>   SingleMotionController |
+-----------------------------------------------------+
|              Shared internal engine                  |
|  _TrackSlot<T>  ChainedSimulation  loop resolution   |
|  per-track state: value, velocity, simulations       |
+-----------------------------------------------------+
```

`MotionController<T>` wraps one `_TrackSlot<T>`. `TrackController` wraps `Map<Track, _TrackSlot>`. Both tick slots from a ticker and share redirection, velocity preservation, chained simulation, and loop handling.

## Motion Type Hierarchy
```dart
sealed class MotionBase {
  const MotionBase({this.tolerance = Tolerance.defaultTolerance});
  final Tolerance tolerance;
  bool get needsSettle;
  bool get unboundedWillSettle;
  MotionBase scaleTo(Duration duration);
}

abstract class Motion extends MotionBase {
  const Motion({super.tolerance});

  const factory Motion.curved(Duration duration, [Curve curve]) = CurvedMotion;
  const factory Motion.linear(Duration duration) = LinearMotion;
  const factory Motion.none([Duration duration]) = NoMotion;
  const factory Motion.customSpring(SpringDescription spring) = SpringMotion;
  const factory Motion.cupertino({Duration duration, double bounce, bool snapToEnd}) = CupertinoMotion;
  const factory Motion.bouncySpring({Duration duration, double extraBounce, bool snapToEnd}) = CupertinoMotion.bouncy;
  const factory Motion.snappySpring({Duration duration, double extraBounce, bool snapToEnd}) = CupertinoMotion.snappy;
  const factory Motion.smoothSpring({Duration duration, double extraBounce, bool snapToEnd}) = CupertinoMotion.smooth;
  const factory Motion.interactiveSpring({Duration duration, double extraBounce, bool snapToEnd}) = CupertinoMotion.interactive;

  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  });

  @override
  Motion scaleTo(Duration duration) => FixedDurationMotion(this, duration: duration);
}

abstract class FreeMotion extends MotionBase {
  const FreeMotion({super.tolerance});

  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  });

  @override
  FreeMotion scaleTo(Duration duration) =>
      FixedDurationFreeMotion(this, duration: duration);
}
```

This avoids the `Motion.curved` type trap. Dart named factory constructors have the static type of their enclosing class, so if `Motion` were the sealed root and `Step.to` required a separate `TargetedMotion`, `Step.to(..., motion: Motion.curved(...))` would fail even though the runtime object is targeted.

## Motion Classification
- `SpringMotion`, `CupertinoMotion`, `MaterialSpringMotion`, `CurvedMotion`, `LinearMotion`, and `NoMotion` extend `Motion`.
- Friction, gravity, decay, and future self-directed physics extend `FreeMotion`.
- `NoMotion` stays under `Motion` for source compatibility with `Motion.none` and existing target-based APIs.
- `Step.hold(Duration)` is a first-class step primitive. It does not require `NoMotion` to be a `FreeMotion`.
- `TrimmedMotion` keeps its current shape-slicing role.
- Curves, linear, and none override `scaleTo` natively. Springs and other target-based motions fall back to `FixedDurationMotion`.

## Track
```dart
@immutable
class Track<T> {
  const Track(this.converter, {required this.initial});

  final MotionConverter<T> converter;
  final T initial;

  TrackAnimation<T> to(T value, {required Motion motion}) =>
      TrackAnimation.single(this, to: value, motion: motion);

  TrackAnimation<T> call(List<Step<T>> steps) =>
      TrackAnimation(this, steps);

  TrackFrom<T> from(T value) => TrackFrom(this, value);

  TrackAnimation<T> free(FreeMotion motion) =>
      TrackAnimation(this, [Step.free(motion: motion)]);

  TrackPhases<P> phases<P>(Map<P, T> values) =>
      _TrackPhasesImpl(this, values);
}
```

### Identity And Scope
- Tracks are immutable keys. They do not store animation state.
- Top-level tracks are good for file-wide identity; `static const` tracks are good for widget-local identity with const initials; `State` fields are good for dynamic initials.
- Two widgets using the same top-level track do not share animation state because each controller owns its own slot map.
- Track equality should be identity-based unless there is a compelling reason to support structural equality. This avoids accidental slot collisions between two equivalent-looking tracks.

### Initial Value Resolution
1. Existing controller state for this track, if any.
2. Timeline/controller/builder `from` override, if supplied.
3. Track's declared `initial`.

No runtime throw is needed for missing initial values.

## TrackAnimation
```dart
@immutable
class TrackAnimation<T> {
  const TrackAnimation(this.track, this.steps);

  const TrackAnimation.single(
    this.track, {
    required T to,
    required Motion motion,
  }) : steps = [Step.to(to, motion: motion)];

  final Track<T> track;
  final List<Step<T>> steps;
}
```

`TrackAnimation` is not a `MotionBase`. It is a routing instruction for a specific track. Heterogeneous collections use `List<TrackAnimation>`; each instance preserves its own generic type internally.

## TrackTimeline
```dart
@immutable
class TrackTimeline {
  const TrackTimeline(
    this.animations, {
    this.loop = LoopMode.none,
    this.from = const [],
  });

  final List<TrackAnimation> animations;
  final LoopMode loop;
  final List<TrackFrom> from;
}
```

`TrackTimeline` is the thing authors can predefine, reuse, test, and pass around:

```dart
final logoTimeline = TrackTimeline(
  [
    _logoOpacity([
      Step.hold(1.seconds),
      Step.to(1.0, motion: Motion.curved(1.seconds, Curves.ease)),
      Step.hold(4.seconds),
      Step.to(0.0, motion: Motion.curved(1.seconds, Curves.ease)),
    ]),
    _textOpacity([
      Step.hold(2.seconds),
      Step.to(1.0, motion: Motion.smoothSpring(duration: 1.seconds)),
      Step.hold(3.seconds),
      Step.to(0.0, motion: Motion.curved(1.seconds, Curves.ease)),
    ]),
  ],
  loop: LoopMode.seamless,
);
```

### Loop Semantics
- `LoopMode.none`: play once and stop.
- `LoopMode.loop`: restart from the timeline's resolved start snapshot after the clip duration.
- `LoopMode.seamless`: same timing as `loop`, with debug validation that each active track ends at its loop-start value.
- `LoopMode.pingPong`: alternate forward and reversed playback.
- `TrackController.play(..., loop:)` and `MultiTrackMotionBuilder(loop:)` can exist as overrides, but the timeline is the primary owner of loop intent.
- If a loop should animate back to the beginning before repeating, authors write that explicitly as the final step. The engine should not invent an implicit closing motion.

For deterministic loops, a timeline's start snapshot is resolved from `TrackTimeline.from`, then controller state, then track initial. Once playback starts, the loop uses that captured snapshot rather than drifting from whatever value the controller happens to hold later.

## Steps
```dart
sealed class Step<T> {
  const Step();

  const factory Step.to(T value, {required Motion motion}) = _StepTo<T>;
  const factory Step.free({required FreeMotion motion}) = _StepFree<T>;
  const factory Step.hold(Duration duration) = _StepHold<T>;
  const factory Step.at(
    Duration at, {
    required T to,
    required Motion motion,
  }) = _StepAt<T>;
}
```

`Step.at` uses absolute time from the start of its track animation inside the timeline:
1. Previous segment ends before `at`: segment duration is `at - previousEndTime`; use `motion.scaleTo(segmentDuration)`.
2. Previous segment would still be running at `at`: trim previous, snap to the boundary value, and start the next segment.
3. `at` earlier than an already placed step: throw at construction or timeline compilation.

## Controllers
```dart
class MotionController<T extends Object> extends Animation<T> {
  MotionController({
    required Motion motion,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior,
    VelocityTracking velocityTracking,
  });

  MotionController.motionPerDimension({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
  });

  Motion get motion;
  set motion(Motion value);
  List<Motion> get motionPerDimension;
  set motionPerDimension(Iterable<Motion> value);

  TickerFuture animateTo(T target, {T? from, T? withVelocity});
  TickerFuture play(
    List<Step<T>> steps, {
    LoopMode? loop,
    void Function(int stepIndex)? onStep,
  });
}
```

The public `MotionController` and `MotionBuilder` motion types remain `Motion`, preserving existing `Motion.curved(...)` and `Motion.smoothSpring(...)` call sites.

```dart
class TrackController with ChangeNotifier {
  TrackController({
    required TickerProvider vsync,
    List<TrackFrom>? from,
  });

  T value<T>(Track<T> track);
  T velocity<T>(Track<T> track);

  void play(
    TrackTimeline timeline, {
    LoopMode? loop,
    void Function(Track track, int stepIndex)? onStep,
  });

  void playAll(
    List<TrackAnimation> animations, {
    LoopMode loop = LoopMode.none,
    List<TrackFrom> from = const [],
    void Function(Track track, int stepIndex)? onStep,
  });

  void animateTo<T>(Track<T> track, T target, {required Motion motion});
  void scrubTo(Duration t);
  void resume();
  void stop({Track? track, bool canceled = false});
  bool get isAnimating;
  void resync(TickerProvider vsync);
  void dispose();
}
```

`playAll` is convenience sugar that internally creates a `TrackTimeline`. The canonical reusable API is `play(TrackTimeline)`.

## Widget APIs
### MotionBuilder
`MotionBuilder<T>` stays source-compatible with 1.x. Its `motion` and `motionPerDimension` parameters remain `Motion` and `List<Motion>`.

### MultiTrackMotionBuilder
```dart
MultiTrackMotionBuilder(
  timeline: logoTimeline,
  restartTrigger: tapCount,
  active: true,
  onStep: (track, stepIndex) {},
  builder: (context, value, child) => Transform.scale(
    scale: value(_scale),
    child: child,
  ),
  child: const FlutterLogo(),
)
```

Parameters:
- `timeline: TrackTimeline?` as the primary declarative input.
- `play: List<TrackAnimation>?` as convenience input for simple inline usage.
- `from: List<TrackFrom>?` as builder-level initial overrides.
- `loop: LoopMode?` as an optional override of `timeline.loop`.
- `restartTrigger: Object?` to replay on change.
- `active: bool` to pause/resume.
- `onStep: void Function(Track, int)?`.
- `onAnimationStatusChanged`, `velocityTracking`, `builder`, and `child`.

Keep the builder reader named `value(track)`.

### PhaseMotionBuilder
`PhaseMotionBuilder<P>` remains the replacement for phase-driven `SequenceMotionBuilder` use cases. It converts `TrackPhases<P>` entries into a `TrackTimeline` on phase change and calls `TrackController.play`.

```dart
PhaseMotionBuilder<ButtonState>(
  currentPhase: widget.state,
  motion: Motion.bouncySpring(),
  tracks: [
    _scale.phases({ButtonState.idle: 1.0, ButtonState.pressed: 0.95}),
    _offset.phases({ButtonState.idle: Offset.zero, ButtonState.pressed: const Offset(0, 2)}),
  ],
  motionPerTrack: {_offset: Motion.smoothSpring()},
  builder: (context, value, child) => Transform.scale(
    scale: value(_scale),
    child: Transform.translate(offset: value(_offset), child: child),
  ),
)
```

## Track Families
`Track.family` is not required for the first implementation, but it unlocks repeated dynamic UI where each item needs the same animated property with a different identity:

```dart
final itemOffset = Track.family<String, Offset>(
  MotionConverter.offset,
  initial: Offset.zero,
);

controller.animateTo(
  itemOffset(item.id),
  const Offset(0, 8),
  motion: Motion.smoothSpring(),
);
```

Without families, users must manually allocate and store a `Track<Offset>` per item id. A family makes the key a pair of `(family, argument)`, similar to `Provider.family`, so list rows, cards, tabs, reorderable items, particles, and route entries can have stable independent slots while sharing one declaration.

Defer this unless a 2.0 example needs dynamic collections. It adds real design work around equality, cache lifetime, and disposal of slots for arguments that disappear.

## Migration
- Existing target-based call sites using `Motion.curved`, `Motion.smoothSpring`, `Motion.cupertino`, concrete spring classes, `MotionController`, and `MotionBuilder` remain source-compatible.
- External custom motions migrate from `extends Motion` only if they are self-directed; target-based custom motions continue to extend `Motion`.
- New friction/gravity/decay-style motions extend `FreeMotion`.
- `MotionSequence`, `SequenceMotionController`, `SequenceMotionBuilder`, and `playSequence` become compatibility shims for one minor version.
- Phase-driven state machines migrate to `PhaseMotionBuilder<P>`.
- Looping multi-property animations migrate to predefined `TrackTimeline`s.

## New Files
- `lib/src/motion_base.dart` or update `lib/src/motion.dart` with `MotionBase` and `FreeMotion`.
- `lib/src/fixed_duration_motion.dart`.
- `lib/src/track.dart`.
- `lib/src/track_animation.dart`.
- `lib/src/track_timeline.dart`.
- `lib/src/step.dart`.
- `lib/src/simulations/chained_simulation.dart`.
- `lib/src/controllers/track_controller.dart`.
- `lib/src/controllers/_track_slot.dart`.
- `lib/src/widgets/multi_track_motion_builder.dart`.
- `lib/src/widgets/phase_motion_builder.dart`.

## Tests
- Motion hierarchy compatibility: `Motion.curved(...)` and `Motion.smoothSpring(...)` compile anywhere `Motion` is required.
- Free motion type safety: `Step.free` accepts `FreeMotion`; `Step.to` rejects `FreeMotion`.
- `scaleTo`: exact for curves/linear/none; fixed-duration wrapper fallback for springs and free motions.
- Track construction: `.to`, `.from`, `.free`, `.phases`, callable multi-step creation.
- Track timeline: loop ownership, start snapshot resolution, list convenience conversion.
- Chained simulation: boundary continuity, velocity continuity, strict `Step.at`, hold segments, raw free-motion segments.
- Looping: `none`, `loop`, `seamless`, and `pingPong` for `MotionController.play`, `TrackController`, and `MultiTrackMotionBuilder`.
- Redirection: mid-animation play preserves velocity for single-value and multi-track controllers.
- Builders: `from`, `restartTrigger`, dispose, active pause/resume, status callbacks, step callbacks.
- Phase builder: phase changes, `motionPerTrack`, initial seeding, transition callbacks.
- Migration shims: existing sequence tests pass against the compatibility layer.