## Unreleased

> Note: This is the Motor 2.0 development release. It has significant breaking
> changes. Existing `Motion.*` factories, `MotionController`, `MotionBuilder`,
> `MotionSequence`, `SequenceMotionController`, and `SequenceMotionBuilder` stay
> source-compatible, but several runtime behaviors have changed (see below).

### Docs

 - **DOCS**: fix broken README samples and clarify SDK syntax, timeline equality, track value readers, sync-barrier seeking, and custom motion extension points.

### Deprecations

 - **DEPRECATION**: the legacy sequence stack — `MotionSequence` (including `StateSequence`, `StepSequence`, `SpanningSequence`, and `ValueWithMotion`), `SequenceMotionController`, and `SequenceMotionBuilder` — is deprecated and will be removed in motor 3.0. It remains fully functional in 2.x. Migrate to `Track`/`TrackPhaseTimeline` with `PhaseTrackBuilder` or `PhaseTrackController`; see [MIGRATION.md](./MIGRATION.md) for a step-by-step guide.

### Naming

 - **BREAKING** **REFACTOR**: rename the track-step type `Step` to `TrackStep` (file `src/step.dart` → `src/track_step.dart`) and `SyncStep` to `StepSync`, so importing motor alongside `package:flutter/material.dart` (which exports the `Stepper` row widget `Step`) no longer requires `hide Step` workarounds, and the step subclasses are uniformly prefixed (`StepTo`, `StepAt`, `StepHold`, `StepFree`, `StepSync`). This only affects code written against the unreleased 2.0 dev branch; dot-shorthand call sites (`.to(...)`, `.sync(...)`) are unaffected.

### Tracks: a new multi-property animation system

 - **FEAT**: add a read-only playback inspection API at `package:motor/inspection.dart`, exposing immutable snapshots of live track plans, timing, loop, synchronization, and playhead state for debug tooling.
 - **FEAT**: add `Track<T>`, the immutable, identity-based key for a single animated property. A track carries a `MotionConverter`, an optional `initial` value, and an optional default `motion`/`motionPerDimension`. Build instructions with `track.to(...)`, `track(...)` (multi-step), `track.free(...)`, `track.value(...)`, and `track.velocity(...)`.
 - **FEAT**: add `TrackStep<T>` as the unit of a track animation: `TrackStep.to` (animate to a target), `TrackStep.at` (reach a target at an absolute time), `TrackStep.hold` (hold the current value), `TrackStep.free` (run a self-directed `FreeMotion`), and `TrackStep.sync` (a barrier that waits for sibling tracks sharing a token before releasing them together).
 - **FEAT**: add `TrackAnimation<T>` (the per-track instruction, carrying its own `from`/`withVelocity`), `TrackTimeline` (a reusable, value-equatable multi-track clip that owns its `LoopMode`), and `TrackPhaseTimeline<P>` (a phase-organized timeline that flattens phases into one timeline with `StepSync` barriers at boundaries, plus one-time `from`/`withVelocity` seeds and `phaseLoop`).
 - **FEAT**: add `TrackController`, a multi-track controller backed by one ticker. Supports lazy per-track initialization, `play`/`animate`/`set`/`scrubTo`/`resume`/`stop`, per-track graceful settling, velocity preservation across redirection, sync barriers, `onStep` callbacks, and whole-controller `TickerFuture` completion semantics.
 - **FEAT**: add `PhaseTrackController<P>`, a `TrackController` that understands phases via `playPhases`, `goToPhase`, `setTimeline`, and `currentPhase`, reporting `PhaseTransitioning`/`PhaseSettled` through a transition callback.
 - **FEAT**: add `TrackBuilder` (declarative multi-track playback) with a default constructor (inline `animations:` + `loop:`, mirroring `TrackController.animate`) and a `TrackBuilder.timeline(...)` constructor (mirroring `TrackController.play`). Inline animation lists compare deeply and timelines compare by value, so an equal-but-new list on rebuild does not restart playback. `restartTrigger` jumps every track back to its start value and replays.
 - **FEAT**: add `PhaseTrackBuilder<P>`, the track-based replacement for phase-driven UI. It supports manual phase control (via `currentPhase`) and auto-advance (via `playing`), with `restartTrigger`, `active`, and transition callbacks.

### Motion type hierarchy

 - **BREAKING** **FEAT**: introduce the sealed `MotionBase` root. `Motion` now extends `MotionBase` and remains the target-based motion type (all existing `Motion.*` factories are unchanged). Custom motions that previously extended the motion root directly must now extend `Motion` (target-based) or `FreeMotion` (self-directed); the root itself is sealed.
 - **FEAT**: add `FreeMotion`, a self-directed motion that evolves from a position and velocity without an end value (decay, friction, gravity, …). Includes `FreeMotion.friction` / `FrictionMotion` (with `drag` and `constantDeceleration`), plus `finalValue` and `project` to anticipate the resting value without running the full simulation.
 - **FEAT**: add `MotionBase.scaleTo(Duration)` to force a motion to complete in an exact duration. It is exact for curves, linear, and none, and falls back to `FixedDurationMotion` / `FixedDurationFreeMotion` wrappers for springs and free motions.
 - **FEAT**: add `Motion.duration`, exposing the characteristic duration of a motion (exact for fixed-duration motions, the settling time for springs, `null` when unknown).
 - **FEAT**: `Motion.customSpring` / `SpringMotion` now accept a `snapToEnd` flag.
 - **BREAKING** **FIX**: all spring motions now default `snapToEnd` to `true` again, so values settle exactly on their target (e.g. exactly `0.0`/`1.0`). This prevents off-target settling from breaking conditionals based on a motion's value. If you relied on the previous behavior, pass `snapToEnd: false`. This may reintroduce small visual jumps in `MotionSequence`s; set `snapToEnd: false` on those spring instances if needed.

### Controllers

 - **REFACTOR**: `MotionController` is now a thin wrapper over a single-track `TrackController`, so the single-value and multi-track stacks share one engine. This is an internal change and should be fully compatible with 1.x.
 - **FEAT**: add `MotionController.play(List<TrackStep<T>>, {loop, onStep})` for step-based and looping single-value playback, plus `trackedVelocityEstimate`.
 - **REFACTOR**: move the legacy sequence engine and `SequenceMotionController` to `controllers/legacy/`. `SequenceMotionController` and `SequenceMotionBuilder` remain exported and functional as compatibility shims; new phase/multi-property work should use `PhaseTrackBuilder` / `TrackPhaseTimeline`.
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

### Fixes

 - **FIX**: stopping a track no longer releases sync barriers early for the remaining tracks.
 - **FIX**: `PhaseTrackBuilder` now recreates its controller and restarts playback when `velocityTracking` changes at runtime.
 - **FIX**: two-keyframe `SpanningSequence`s with `LoopMode.seamless` now use the full return slice instead of a degenerate zero-extent motion.
 - **FIX**: `LoopMode.loop` timelines without a target motion now restart from their initial values after free, hold, or sync-only steps instead of continuing from the final state.
 - **FIX**: canceled controller stops no longer report `AnimationStatus.completed`; they stop immediately without emitting a status notification.
 - **FIX**: looping `PhaseTrackController` playback now reports `AnimationStatus.forward` once at startup instead of flapping through `completed` between cycles.
 - **FIX**: `PhaseTrackController` now plays `pingPong` phase loops in reverse phase order after each forward pass instead of replaying phases forward like `loop`.
 - **FIX**: `TrackStep.at` segments in `pingPong` loops now mirror their forward scheduled duration on the reverse leg instead of using the motion's unscaled duration and re-triggering absolute-time boundaries.
 - **FIX**: swapping a `MotionController`'s `converter` no longer leaks the replaced track's internal state in the underlying `TrackController`.
 - **FIX**: `PhaseTrackController` now re-applies a timeline's one-time `from`/`withVelocity` seeds when a *different* timeline starts playing on the same controller. Previously the seeds were applied only once per controller, so swapping timelines (e.g. changing `PhaseTrackBuilder.timeline`) silently kept the previous timeline's values. Replaying an equal-value timeline still does not re-seed.
 - **FIX**: `PhaseTrackBuilder` resumes playback when `active` is toggled from `false` back to `true`. Previously only the deactivation transition was handled, so a reactivated builder stayed frozen.
 - **FIX**: `SpringMotion` equality (and `hashCode`) now includes `snapToEnd`, so spring motions differing only in `snapToEnd` compare unequal. This affects rebuild-restart detection in `TrackBuilder` and motion swaps on `MotionController`, which previously ignored a `snapToEnd` change.
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
