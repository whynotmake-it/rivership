# Migrating to Motor 2.0

This guide covers upgrading from Motor 1.x to 2.0. It has three parts:

1. [Breaking behavior changes](#breaking-behavior-changes) — runtime behavior
   that changed without a compile error.
2. [Sequences → Tracks](#sequences--tracks) — migrating off the deprecated
   `MotionSequence` stack.
3. [Deprecation timeline](#deprecation-timeline) — what gets removed in 3.0.

## Breaking behavior changes

### Springs snap to their end value by default

All spring motions now default `snapToEnd` to `true`, so values settle
*exactly* on their target (e.g. exactly `0.0`/`1.0`) instead of stopping
within tolerance. This prevents off-target settling from breaking
conditionals based on a motion's value, but may reintroduce small visual
jumps in sequences whose targets are not continuous.

```dart
// Before (1.x): springs settled near, but not exactly on, the target.
final motion = CupertinoMotion.smooth();

// After (2.0): same code snaps to the target on settle. To keep the old
// behavior, opt out explicitly:
final motion = CupertinoMotion.smooth().copyWith(snapToEnd: false);
```

### Automatic velocity tracking is on by default

Controllers and motion builders now track velocity when their value is set
manually, so animations started without an explicit velocity keep their
momentum.

```dart
// Before (1.x): setting values directly never fed velocity into the next
// animation.
controller.value = draggedPosition;

// After (2.0): the same code preserves momentum automatically. To opt out:
final controller = MotionController(
  motion: .smoothSpring(),
  vsync: this,
  converter: .single,
  velocityTracking: const VelocityTracking.off(),
);
```

When you do have gesture velocity (e.g. from `DragEndDetails`), still prefer
passing it explicitly via `withVelocity:` for accuracy.

### `status` is now directional for comparable converters

`SingleMotionConverter` (and other comparable converters) are now
directional, so `MotionController.status` reports
`AnimationStatus.reverse` when animating toward a "smaller" value.
Previously it always reported `forward`.

```dart
// Before (1.x):
controller.animateTo(0); // status: AnimationStatus.forward

// After (2.0):
controller.animateTo(0); // status: AnimationStatus.reverse when moving down
```

If you branched on `status == AnimationStatus.forward` to mean "animating",
use `controller.isAnimating` instead.

### `PhaseTransition` factory constructors removed

`PhaseTransition.settled` and `PhaseTransition.transitioning` are gone.
Construct the subtypes directly (a `phase` getter was also added, returning
the current or target phase).

```dart
// Before (1.x):
final t = PhaseTransition.settled(phase);

// After (2.0):
final t = PhaseSettled(phase);
final u = PhaseTransitioning(from: a, to: b);
```

### Sealed `MotionBase` root

The motion hierarchy is now rooted in the sealed `MotionBase`. Custom
motions that previously extended the root directly must now extend `Motion`
(target-based) or `FreeMotion` (self-directed).

```dart
// Before (1.x):
class MyMotion extends Motion { ... } // Motion was the root

// After (2.0): pick the right base for your motion.
class MyTargetMotion extends Motion { ... }     // animates toward a target
class MyDecayMotion extends FreeMotion { ... }  // evolves from value+velocity
```

## Sequences → Tracks

The legacy sequence stack — `MotionSequence` (with `StateSequence`,
`StepSequence`, `SpanningSequence`, and `ValueWithMotion`),
`SequenceMotionController`, and `SequenceMotionBuilder` — is deprecated in
2.0 and will be removed in 3.0. The track stack replaces it.

| Legacy | Replacement |
|--------|-------------|
| `MotionSequence.states({...}, motion: m)` + `SequenceMotionBuilder` | `TrackPhaseTimeline({...})` with one `Track` + `PhaseTrackBuilder` |
| `MotionSequence.steps([...])` | one track animation with multiple `.to` steps (or a `TrackTimeline` with `loop:`) |
| `MotionSequence.spanning({...})` | `.at` absolute-time steps |
| `SequenceMotionController.playSequence` | `PhaseTrackController.playPhases` |
| `currentSequencePhase` / `isPlayingSequence` / `sequenceProgress` | `currentPhase` (see note below) |

### State sequences → phase timelines

```dart
// Before:
SequenceMotionBuilder<ButtonState, Offset>(
  sequence: .states({
    .idle: Offset(0, 0),
    .pressed: Offset(0, 5),
  }, motion: .bouncySpring()),
  converter: .offset,
  currentPhase: state,
  playing: false,
  builder: (context, offset, phase, child) => ...,
)

// After:
final offset = Track(.offset, initial: Offset.zero, motion: .bouncySpring());

PhaseTrackBuilder<ButtonState>(
  currentPhase: state,
  timeline: TrackPhaseTimeline({
    .idle: [offset.to(const Offset(0, 0))],
    .pressed: [offset.to(const Offset(0, 5))],
  }),
  builder: (context, value, phase, child) {
    final Offset o = value(offset); // read per-track values
    return ...;
  },
)
```

### Step sequences → multi-step track animations

```dart
// Before:
final sequence = MotionSequence.steps(
  [0.0, 0.5, 1.0],
  motion: .smoothSpring(),
  loop: .loop,
);

// After: one track with multiple steps, looped via the timeline.
final progress = Track(.single, initial: 0.0);

final timeline = TrackTimeline(
  [
    progress([
      .to(0.0, motion: .smoothSpring()),
      .to(0.5, motion: .smoothSpring()),
      .to(1.0, motion: .smoothSpring()),
    ]),
  ],
  loop: .loop,
);
```

### Spanning sequences → absolute-time steps

```dart
// Before: positions distribute one motion proportionally.
final sequence = MotionSequence.spanning({
  0.0: 0.0,
  1.0: 1.0,
  2.0: 0.0,
}, motion: .linear(Duration(seconds: 2)));

// After: `.at` steps hit values at absolute times from the track's start.
final opacity = Track(.single, initial: 0.0);

final animation = opacity([
  .at(const Duration(seconds: 1), 1.0),
  .at(const Duration(seconds: 2), 0.0),
]);
```

### Controllers

```dart
// Before:
final controller = SequenceMotionController<ButtonState, Offset>(
  motion: .smoothSpring(),
  vsync: this,
  converter: .offset,
  initialValue: .zero,
);
await controller.playSequence(sequence);

// After:
final controller = PhaseTrackController<ButtonState>(vsync: this);
await controller.playPhases(timeline);
```

State queries map as follows:

- `currentSequencePhase` → `currentPhase`.
- `isPlayingSequence` → check `isAnimating` while a phase timeline plays.
- `sequenceProgress` has no direct equivalent; derive progress from the
  `onTransition` callback (count `PhaseTransitioning` events against
  `timeline.phases.length`).

## Deprecation timeline

- **2.0**: `MotionSequence` (and `StateSequence`, `StepSequence`,
  `SpanningSequence`, `ValueWithMotion`), `SequenceMotionController`, and
  `SequenceMotionBuilder` are `@Deprecated` but fully functional.
- **3.0**: the legacy stack is deleted.

3.0 deletion checklist:

- [ ] Delete `lib/src/controllers/legacy/` (the legacy `MotionController`
      copy and `SequenceMotionController`).
- [ ] Delete `lib/src/motion_sequence.dart` and move its `LoopMode`
      re-export (`LoopMode` itself is *not* deprecated — it drives track
      playback too).
- [ ] Delete `lib/src/widgets/sequence_motion_builder.dart`.
- [ ] Delete their tests and goldens
      (`test/motion_sequence_test.dart`,
      `test/src/controllers/phase_sequence_controller_test.dart`,
      `test/src/controllers/legacy_sequence_semantics_test.dart`,
      `test/src/widgets/sequence_motion_builder_test.dart`,
      `test/src/widgets/sequence_motion_builder_golden_test.dart` and its
      goldens).
- [ ] Remove the "Sequence Animations (deprecated)" README section.

### Behavioral notes from the 2.0 parity tests

- For `LoopMode.loop`, the legacy `SequenceMotionController` and the new
  `PhaseTrackController` visit phases in the same order
  (`0 → 1 → 2 → 0 → …`); no divergence was found.
- `LoopMode.pingPong` was intentionally not compared across stacks: the new
  stack's *phase-level* pingPong is not yet supported. The legacy pingPong
  order (`0 → 1 → 2 → 1 → 0 → 1 → …`) is pinned by test.
