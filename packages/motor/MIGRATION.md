# Migrating to Motor 2.0

This guide covers upgrading from Motor 1.x to 2.0. It has three parts:

1. [Breaking changes](#breaking-changes) — every change that can break 1.x
   code, most of them runtime behavior that changes without a compile error.
2. [Sequences → Tracks](#sequences--tracks) — migrating off the deprecated
   `MotionSequence` stack.
3. [Deprecation timeline](#deprecation-timeline) — what gets removed in 3.0.

## Breaking changes

### Springs snap to their end value by default

All spring motions now default `snapToEnd` to `true`, so values settle
*exactly* on their target (e.g. exactly `0.0`/`1.0`). In 1.1.0 the default
was `false`, and springs stopped within tolerance of the target. Snapping
keeps conditionals on a motion's value reliable, but may cause small visual
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
  initialValue: 0.0,
  velocityTracking: const .off(),
);
```

When you do have gesture velocity (e.g. from `DragEndDetails`), still prefer
passing it explicitly via `withVelocity:` for accuracy.

### `status` is directional for directional converters

`SingleMotionConverter` is now directional, so a controller or builder
using it reports `AnimationStatus.reverse` when animating toward a smaller
value. Previously it always reported `forward`. The same applies to custom
converters that mix in `DirectionalMotionConverter` or
`ComparableMotionConverter`.

Most multi-dimensional values (`Offset`, `Size`, `Rect`, `Color`, and
custom converters) have no direction. For them, status works as in 1.x:
`forward` while animating and `completed` at rest (`dismissed` only when a
move ends exactly on the initial value).

```dart
// Before (1.x):
controller.animateTo(0); // status: AnimationStatus.forward

// After (2.0):
controller.animateTo(0); // status: AnimationStatus.reverse when moving down
```

If you branched on `status == .forward` to mean "animating",
use `controller.isAnimating` instead.

### Moves down finish `dismissed`

With a directional converter, the resting status follows the direction too.
A move down finishes `dismissed`, and anything else finishes `completed`. This applies to every
controller, builder, and status listener. For converters without a direction
(for example `Offset`), `dismissed` means exactly back at the initial value.

```dart
// Before (1.x): dismissed only when the last target equaled the initial
// value.
controller.animateTo(1); // from 3: ends completed

// After (2.0):
controller.animateTo(1); // from 3: ends dismissed
```

Setting `value` follows the same rule: a jump down reports `dismissed`, and
a jump up reports `completed`. In 1.x, setting `value` reported `dismissed`
only if the last animation target equaled the initial value.

If you waited for `completed` to detect the end of any move, check
`!status.isAnimating` or await the returned `TickerFuture` instead.

### `BoundedMotionController` status ignores its bounds

`BoundedMotionController` uses the same status rule as `MotionController`.
In 1.x it reported `dismissed` at the lower bound and `completed` at the
upper bound. With a directional converter, `reverse()` still ends
`dismissed` and `forward()` ends `completed`. Without one (for example a
bounded `Offset` controller), status is still `reverse` while `reverse()`
runs, as in 1.x, but `reverse()` now ends `completed` unless the lower bound
is the initial value.

```dart
// To know which bound you're at, compare the value:
final atLowerBound = controller.value == controller.lowerBound;
```

### Sequences report `reverse` on the way down

`SequenceMotionController` and `SequenceMotionBuilder` report `reverse`
while a phase moves down, for example on the way back in
`LoopMode.pingPong`, and `dismissed` after a final move down. In 1.x they
reported `forward` for the whole sequence, then `completed`. They still
never report `completed` between loop cycles. Use `isAnimating` instead of
comparing with `forward` or `completed`.

### `animateTo` the current value keeps the direction

Calling `animateTo` with the value the controller is already at keeps the
previous direction as its status (`reverse` after a move down). In 1.x it
reported `forward`.

### Curve velocity is no longer 4× too large

`CurvedMotion` and `LinearMotion` reported velocities 4× too large in 1.x.
A spring taking over a running curve, for example `animateTo` with a spring
motion mid-curve, started 4× too fast and overshot more. It now continues
at the curve's actual speed, like `AnimationController`. If you tuned
springs around the old overshoot, retune them.

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

### Converters must not keep motor's lists

`MotionConverter.denormalize` now receives motor's reused buffer, which
changes after the call, and motor may keep the list `normalize` returns.
In 1.x, `denormalize` got a fresh list each time. This only matters if your
converter keeps the list itself; converters that build a new value from the
numbers are unaffected.

```dart
// Before (1.x):
final converter = MotionConverter<List<double>>.custom(
  normalize: (value) => value,
  denormalize: (values) => values,
);

// After (2.0):
final converter = MotionConverter<List<double>>.custom(
  normalize: (value) => value,
  denormalize: List.of,
);
```

### Sealed `MotionBase` root

The motion hierarchy is now rooted in the sealed `MotionBase`, with `Motion`
for motions that animate toward a target and the new `FreeMotion` for
self-directed ones. Custom motions that extend `Motion` keep working. Code
that switches over motion types must handle `FreeMotion`.

```dart
class MyTargetMotion extends Motion { ... }     // unchanged from 1.x
class MyDecayMotion extends FreeMotion { ... }  // new: evolves from value+velocity
```

### Custom simulations must be pure functions of time

Motor queries a simulation at any time: ahead, to find when it finishes, and
backwards when scrubbing, seeking or looping. In 1.x, like Flutter's
`AnimationController`, motor only queried it at increasing times, so a
simulation that integrated step by step or kept state between calls worked.
In 2.0 it shows wrong values, jumps to its end, or loops as a square wave.

Motor's own simulations and every public Flutter simulation are pure, so most
code needs no change. If yours keeps state, make `x`, `dx` and `isDone`
depend only on the time passed in, without side effects. A step-by-step
integrator works if it restarts from its initial state whenever it's asked
about an earlier time:

```dart
void _advanceTo(double time) {
  if (time < _time) _reset(); // rewound: start over from the initial state
  while (_time < time) _step();
}
```

### Custom motions: extend `Motion` instead of implementing it

2.0 added `settlingDuration(...)` and `scaleTo(Duration)` to `Motion` and
`MotionBase`, with default implementations. A class that `implements Motion`
doesn't inherit them, so it no longer compiles until it provides both.
Extend `Motion` instead: you keep only the members 1.x required.

```dart
// Before (1.x):
class MyMotion implements Motion {
  const MyMotion();

  @override
  Tolerance get tolerance => .defaultTolerance;

  @override
  bool get needsSettle => true;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      SpringSimulation(_spring, start, end, velocity);
}

// After (2.0):
class MyMotion extends Motion {
  const MyMotion();

  @override
  bool get needsSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      SpringSimulation(_spring, start, end, velocity);
}

const _spring = SpringDescription(mass: 1, stiffness: 200, damping: 20);
```

If you can tell when your simulation is done, override `settlingDuration`
with the same arguments as `createSimulation`. Motor then ends its steps at
that time instead of sampling `isDone` to find it.

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
final sequence = MotionSequence.steps<double>(
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
final sequence = MotionSequence.spanning<double>({
  0.0: 0.0,
  1.0: 1.0,
  2.0: 0.0,
}, motion: .linear(Duration(seconds: 2)));

// After: `.at` steps hit values at absolute times from the track's start.
// Each `.at` needs a motion (here the track default); it is time-scaled to
// arrive exactly at the keyframe.
final opacity = Track(
  .single,
  initial: 0.0,
  motion: .linear(const Duration(seconds: 1)),
);

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
  `Motion.unboundedWillSettle` is `@Deprecated`: motor never reads it, so
  delete your overrides.
- **3.0**: the legacy stack and `unboundedWillSettle` are deleted.

3.0 deletion checklist:

> Note: the legacy engine copy (`lib/src/controllers/legacy/`) was already
> removed in 2.0 itself — `SequenceMotionController` now runs on the 2.0
> track engine. The 3.0 removal covers only the deprecated API symbols and
> their tests.

- [ ] Delete `lib/src/controllers/sequence_motion_controller.dart` (the
      deprecated `SequenceMotionController`, a part of
      `motion_controller.dart`).
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
- [ ] Delete `MotionBase.unboundedWillSettle`.

### Behavioral notes from the 2.0 parity tests

- For `LoopMode.loop`, the legacy `SequenceMotionController` and the new
  `PhaseTrackController` visit phases in the same order
  (`0 → 1 → 2 → 0 → …`); no divergence was found.
- `LoopMode.pingPong` visits phases in the same order on both stacks
  (`0 → 1 → 2 → 1 → 0 → 1 → …`); each phase's own steps still play forward.
- Animations inside a `TrackPhaseTimeline` phase can't set their own `from:`
  (asserted). Use the timeline's one-time `initialValues:` /
  `initialVelocities:` instead.
