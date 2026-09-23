## Unreleased

> Note: This is the Motor 2.0 development release. It has significant breaking
> changes. Existing `Motion.*` factories, `MotionController`, `MotionBuilder`,
> `MotionSequence`, `SequenceMotionController`, and `SequenceMotionBuilder` stay
> source-compatible, but several runtime behaviors have changed (see below).

### Tracks: a new multi-property animation system

 - **FEAT**: add `Track<T>`, the identity-based key for one animated property. A track carries a `MotionConverter`, an optional `initial` value, an optional default `motion`/`motionPerDimension`, and an optional `debugLabel`. Build instructions with `track.to(...)`, `track(...)` (multi-step), `track.free(...)`, `track.value(...)`, and `track.velocity(...)`.
 - **FEAT**: add `TrackStep<T>`, the unit of a track animation: `TrackStep.to` (animate to a target), `TrackStep.at` (a keyframe that arrives exactly at an absolute time), `TrackStep.hold`, `TrackStep.free` (run a self-directed `FreeMotion`), and `TrackStep.sync` (a barrier shared by tracks through a token). `.at` stretches its motion over the gap when the preceding step ends early enough, and otherwise cuts the preceding step so its motion runs its natural duration; the two cases meet continuously, and with no time left the value arrives instantly.
 - **FEAT**: add `TrackAnimation<T>` (one track's steps plus its own `from`/`withVelocity`), `TrackTimeline` (a reusable, value-equatable multi-track clip that owns its `LoopMode`), and `TrackPhaseTimeline<P>` (phases flattened into one timeline with sync barriers at phase boundaries, one-time `from`/`withVelocity` seeds, and `phaseLoop`).
 - **FEAT**: add `TrackController`, a multi-track controller on one ticker:
   - `play`/`animate` start plans for the named tracks, `set` jumps without animating, and `stop` settles springs gracefully or halts with `canceled: true` (which does not report `completed`). Returned futures complete when the whole controller settles.
   - `pause`, `resume`, and `scrubTo` work on one playback timeline that only advances while the controller ticks, so pausing, restarting, and scrubbing never rewind or misalign tracks. Flutter's `timeDilation` applies as usual.
   - Sync barriers release at the exact moment the last participant arrives, independent of the frame rate, and hold every cycle in looping plans. Scrubbing resolves them the same way playback does.
   - Playback is a function of time alone: each step's duration is resolved once and kept, so ticking live, jumping ahead, and scrubbing back always agree, and loops that repeat use constant memory.
   - `onStep` reports every step a track enters, in order, even within one frame.
   - `animationOf(track)` returns a cached `Animation<T>` for one track that composes with tweens, curves, and transitions and reports that track's own status.
 - **FEAT**: add `PhaseTrackController<P>` with `playPhases`, `goToPhase`, `setTimeline`, and `currentPhase`, reporting `PhaseTransitioning`/`PhaseSettled`. `phaseLoop` supports `loop`, `seamless`, and `pingPong` (phases in reverse order on the way back).
 - **FEAT**: add `TrackBuilder` (inline `animations:` + `loop:`, or `TrackBuilder.timeline(...)`) and `PhaseTrackBuilder<P>` (manual `currentPhase` or auto-advancing `playing`). Equal animation lists and timelines do not restart playback on rebuild; `restartTrigger` replays from the start (including the timeline's seeds). Both accept `velocityTracking`, which can change without restarting playback, as can `TrackController.velocityTracking`.

### Inspection and tooling

 - **FEAT**: add an `@experimental` inspection library at `package:motor/inspection.dart`, which may change in minor releases. `MotorInspectionRegistry` lets a tool discover controllers created while it is attached. `inspectPlayback()` returns immutable snapshots with each track's plan, resolved segments, loop cycle and repetition, playhead, barrier state, recorded and estimated step durations, and the controller's recent plans. Two hooks change playback: controller-local `playbackSpeed` and `motionOverride`.
 - **FEAT**: while a tool is attached, controllers keep their recent plans, resolve new plans ahead for accurate duration estimates, and let `scrubTo` show plans a track was redirected away from (resuming there continues them). Without a tool none of this is kept.
 - **FEAT**: controllers, builders (`TrackBuilder`, `PhaseTrackBuilder`, the motion builders, `MotionDraggable`), and tracks accept an optional `debugLabel` shown by inspection tools.
 - **FEAT**: the separate `motor_devtools` package provides an in-app inspector built on this library.

### Deprecations

 - **DEPRECATION**: the legacy sequence stack — `MotionSequence` (including `StateSequence`, `StepSequence`, `SpanningSequence`, and `ValueWithMotion`), `SequenceMotionController`, and `SequenceMotionBuilder` — is deprecated and will be removed in motor 3.0. It remains fully functional in 2.x. Migrate to `Track`/`TrackPhaseTimeline` with `PhaseTrackBuilder` or `PhaseTrackController`; see [MIGRATION.md](./MIGRATION.md) for a step-by-step guide.

### Motion type hierarchy

 - **BREAKING** **FEAT**: introduce the sealed `MotionBase` root. `Motion` now extends `MotionBase` and remains the target-based motion type (all existing `Motion.*` factories are unchanged). Custom motions that previously extended the motion root directly must now extend `Motion` (target-based) or `FreeMotion` (self-directed); the root itself is sealed. Simulations created by custom motions must be pure functions of time, because motor re-samples them when scrubbing.
 - **FEAT**: add `FreeMotion`, a self-directed motion that evolves from a position and velocity without an end value (decay, friction, gravity, …). Includes `FreeMotion.friction` / `FrictionMotion` (with `drag` and `constantDeceleration`), plus `finalValue` and `project` to anticipate the resting value without running the full simulation.
 - **FEAT**: add `MotionBase.scaleTo(Duration)` to force a motion to complete in an exact duration. It is exact for curves, linear, and none, and falls back to `FixedDurationMotion` / `FixedDurationFreeMotion` wrappers for springs and free motions.
 - **FEAT**: add `Motion.duration`, exposing the characteristic duration of a motion (exact for fixed-duration motions, the settling time for springs, `null` when unknown).
 - **FEAT**: `Motion.customSpring` / `SpringMotion` now accept a `snapToEnd` flag.
 - **BREAKING** **FIX**: all spring motions now default `snapToEnd` to `true` again, so values settle exactly on their target (e.g. exactly `0.0`/`1.0`). This prevents off-target settling from breaking conditionals based on a motion's value. If you relied on the previous behavior, pass `snapToEnd: false`. This may reintroduce small visual jumps in `MotionSequence`s; set `snapToEnd: false` on those spring instances if needed.

### Controllers

 - **REFACTOR**: `MotionController` is now a thin wrapper over a single-track `TrackController`, so the single-value and multi-track stacks share one engine. This is an internal change and should be fully compatible with 1.x.
 - **FEAT**: add `MotionController.play(List<TrackStep<T>>, {loop, onStep})` for step-based and looping single-value playback (steps without a motion use the controller's), plus `trackedVelocityEstimate`.
 - **REFACTOR**: the deprecated sequence APIs (`SequenceMotionController` and `SequenceMotionBuilder`) now run on the 2.0 track engine; the internal legacy controller copy is deleted. `SequenceMotionController` is a subtype of the exported `MotionController` again, restoring 1.x source compatibility. Phase timing is unchanged (pinned by the legacy sequence semantics tests). Observable deltas:
   - `playSequence`'s returned `TickerFuture` for LOOPING sequences now resolves at the end of the first cycle instead of never (matching `PhaseTrackController.playPhases` — do not `await` a looping sequence).
   - phase-boundary values are sampled at the simulation's exact completion time (a sub-tolerance difference, visible only to non-snapping springs).
   - three goldens changed within anti-aliasing tolerance: `loop_mode_seamless.png` (the seamless jump renders one frame earlier because the continuation is synchronous instead of legacy's post-frame callback — raster visibility only, the value timeline anchors identically), `spanning.png` (trimmed-motion leg boundaries sample at exact done-time slightly before the nominal end, where legacy sampled past-done and clamped to the end value — sub-tolerance anti-aliasing drift), and `state_sequence_1d_animation.png` (the non-snapping-spring boundary-sampling delta above).

### Velocity tracking

 - **BREAKING** **FEAT**: add automatic velocity tracking. `MotionController` and all motion builders now track velocity when their value is set manually, so animations started without an explicit velocity keep their momentum. This is enabled by default; opt out with `VelocityTracking.off()`. New public API: `VelocityTracking`, `MotionVelocityTracker`, and `MotionVelocityEstimate`. When you do have gesture velocity (e.g. `DragEndDetails`), prefer passing it via `withVelocity` for accuracy.

### Motion converters

 - **BREAKING** **FEAT**: add directionality support to `MotionConverter`. New `DirectionalMotionConverter` mixin, `ComparableMotionConverter` mixin, and `MotionConverter.customDirectional` factory let controllers report `AnimationStatus.reverse` when animating toward a "smaller" value. `SingleMotionConverter` (and other comparable converters) are now directional, so `MotionController.status` now reports `reverse` when animating downward — previously it always reported `forward`.
 - **FEAT**: add `MotionConverter.lerp` for per-dimension interpolation between two values.

### Looping and phases

 - **REFACTOR**: extract `LoopMode` into its own file (still re-exported from `motion_sequence.dart`, so this is source-compatible). `LoopMode` (`none`, `loop`, `pingPong`, `seamless`) now drives track and timeline playback as well.
 - **BREAKING** **REFACTOR**: `PhaseTransition` drops the `PhaseTransition.settled` / `PhaseTransition.transitioning` factory constructors and adds a `phase` getter (the current or target phase). Construct `PhaseSettled` / `PhaseTransitioning` directly.

### Performance

 - **PERF**: per-frame work allocates far less (in-place sampling, reused buffers, lazy velocity estimates). With 500 tracks on one controller, per-frame cost relative to one `AnimationController` per track went from +62% to about +11% to +18% in the [benchmark suite](./benchmark/) (thanks to [definev](https://github.com/definev) for the harness and the original allocation work).

### Fixes

 - **FIX**: two-keyframe `SpanningSequence`s with `LoopMode.seamless` now use the full return slice instead of a degenerate zero-extent motion.
 - **FIX**: `SpringMotion` equality (and `hashCode`) now includes `snapToEnd`, so spring motions differing only in `snapToEnd` compare unequal. This affects motion swaps on `MotionController`, which previously ignored a `snapToEnd` change.
 - **FIX**: `CupertinoMotion.copyWith` now reads its defaults from the stored `duration`/`bounce` fields instead of round-tripping them through `SpringDescription`, so unchanged values are preserved exactly.
 - **FIX**: motion builders no longer stop and reset their value on every rebuild while inactive; they only do so on the active→inactive transition.
 - **FIX**: `MotionDraggable` skips the return animation when a dragged item is released already within the motion's tolerance of its target position, avoiding a spurious overlay and animation.

## 1.1.0

 - **FEAT**: added `MotionPadding`, motors equivalent to `AnimatedPadding` that can handle negative values.
 - **FEAT**: allow swapping `MotionConverter` on `MotionController` and `MotionBuilder` types.

    This enables animating supertypes (such as `EdgeInsetsGeometry`, as long as you make sure to always set the converter to match the right subtype.

 - **DOCS**: correct `PhaseMotionController` to `SequenceMotionController`.

## 1.0.1

 - **FIX**: velocity scaling when overdragging with resistance.
 - **DOCS**: updated README.

## 1.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 1.0.0-dev.10

> Note: This release has breaking changes.

 - **FIX**: accept any motion in `SingleMotionController`.
 - **FIX**: Motion changes in sequences are now picked up correctly.
 - **BREAKING** **REFACTOR**: rename `TrimmedMotion` parameters and `MotionTrimming` extension methods to be more intuitive.
 - **BREAKING** **FEAT**: on phase changed callback now returns the full transition.

## 1.0.0-dev.9

 - **FIX**: import internal from package:meta again.

## 1.0.0-dev.8

> Note: This release has breaking changes.

 - **FIX**: all motion controllers now correctly report their status, even for imprecise simulations.
 - **BREAKING** **REFACTOR**: `Motion.none` will not jump to target anymore, but hold at current value instead.
 - **BREAKING** **FEAT**: all spring motions now default to `snapToEnd: false` to reduce unexpected jitter when animating.

## 1.0.0-dev.7

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: `SequenceMotionController` will not skip the initial phase (#164).

    However, all sequences with a single provided motion will now return `NoMotion` for the very initial phase only. This retains the expected playing behavior, while working better with customized motions per phase.


## 1.0.0-dev.6

> Note: This release has breaking changes.

 - **FEAT**: add constants for included MotionConverters.
 - **FEAT**: add sequence animations to motor.
 - **FEAT**: add TrimmedMotion as a way to take subsets of any motion.
 - **DOCS**: add phase animation to readme.
 - **DOCS**: way better examples.
 - **BREAKING** **REFACTOR**: use `MotionConverter.custom()` if you want to pass custom normalization callbacks.
 - **BREAKING** **REFACTOR**: use const constructors for material springs and make default constructor private.
 - **BREAKING** **REFACTOR**: use positional parameters for `CurvedMotion`.
 - **BREAKING** **BUILD**: require Flutter 3.32.

## 1.0.0-dev.5
 - Nothing relevant

## 1.0.0-dev.4

 - **FIX**: use the correct parameters for `MaterialSpringMotion` (#127).

## 1.0.0-dev.3

 - **DOCS**: add title gif to README.
 - **DOCS**: add title slide to example.

## 1.0.0-dev.2

> Note: This release has breaking changes.

 - **FEAT**: add Material 3 Expressive spring tokens.
 - **BREAKING** **REFACTOR**: turned `CupertinoMotion` constants into constructors so parameters can be adjusted on the fly.

## 1.0.0-dev.1

Small updates


## 1.0.0-dev.0

Initial release 🥂
