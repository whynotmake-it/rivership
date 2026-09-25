> Note: This is the Motor 2.0 development release. Existing `Motion.*`
> factories, `MotionController`, `MotionBuilder`, `MotionSequence`,
> `SequenceMotionController`, and `SequenceMotionBuilder` stay
> source-compatible with a few exceptions, but several runtime behaviors
> have changed. Every change that can break 1.x code is listed under
> [Breaking changes](#breaking-changes), and [MIGRATION.md](./MIGRATION.md)
> shows how to migrate.

### Breaking changes

Each entry says what changed, how 1.x behaved, and how to migrate.

 - **BREAKING**: springs now snap exactly onto their target when they settle. `snapToEnd` defaults to `true` for every spring motion (`SpringMotion`, `CupertinoMotion`, `MaterialSpringMotion`, and the spring factories on `Motion`). In 1.1.0 it defaulted to `false`, so a spring stopped within tolerance of its target, for example at `0.9996` instead of `1.0`. To keep the 1.x behavior, pass `snapToEnd: false`.
 - **BREAKING**: controllers and motion builders now track velocity by default. When you set `value` yourself (for example while dragging) and then start an animation without `withVelocity`, the animation continues with the tracked velocity. In 1.x it started from rest. To restore that, pass `velocityTracking: const .off()`. If you have a gesture velocity, pass it via `withVelocity` for accuracy.
 - **BREAKING**: `status` reports `reverse` while a value moves down, but only when its `MotionConverter` is directional: `SingleMotionConverter` (used by the `Single*` controllers and builders) or a custom `DirectionalMotionConverter`. In 1.x, `MotionController.status` was always `forward` while animating. Most multi-dimensional values (`Offset`, `Size`, `Rect`, `Color`, custom converters) have no direction, so for them status stays `forward` while animating and `completed` at rest, as in 1.x. If you used `status == .forward` to mean "animating", use `isAnimating` instead.
 - **BREAKING**: with a directional converter, a move down now finishes `dismissed`, and anything else `completed`. This applies to every controller, builder, and status listener, and to setting `value` directly. For converters without a direction (such as `Offset`), status finishes `completed`, and `dismissed` only when exactly back at the initial value. In 1.x, status was `dismissed` only when the last animation target equaled the initial value, and `completed` otherwise, including after setting `value`. To detect the end of any move, check `!status.isAnimating` or await the returned `TickerFuture` instead of comparing with `completed`.
 - **BREAKING**: `BoundedMotionController` status no longer depends on its bounds; it follows the same rule as `MotionController`. In 1.x it was `dismissed` at the lower bound and `completed` at the upper bound. With a directional converter nothing changes in practice: `reverse()` ends `dismissed` and `forward()` ends `completed`. Without one (for example a bounded `Offset` controller), status is still `reverse` while `reverse()` runs, as in 1.x, but `reverse()` now ends `completed` unless the lower bound is the initial value. To know which bound you are at, compare `value` with `lowerBound` and `upperBound`.
 - **BREAKING**: `SequenceMotionController` and `SequenceMotionBuilder` report `reverse` while a phase moves down, for example on the way back in `LoopMode.pingPong`, and `dismissed` after a final move down. In 1.x they reported `forward` for the whole sequence and then `completed` (or `dismissed` if the final phase equaled the initial value). They still never report `completed` between loop cycles. Use `isAnimating` instead of comparing with `forward` or `completed`.
 - **BREAKING**: calling `animateTo` with the current value keeps the previous direction as status. In 1.x it reported `forward`.
 - **BREAKING**: `PhaseTransition.settled(...)` and `PhaseTransition.transitioning(...)` are removed. Construct `PhaseSettled(phase)` and `PhaseTransitioning(from: a, to: b)` directly. A new `phase` getter returns the current or target phase.
 - **BREAKING**: a curve's velocity is now its real rate of change. `CurvedMotion` and `LinearMotion` reported velocities 4× too large in 1.x, so a spring taking over a running curve (for example `animateTo` with a spring mid-curve) started 4× too fast. It now continues at the curve's actual speed, like `AnimationController`. If you tuned springs around the old overshoot, retune them.
 - **BREAKING**: the motion hierarchy is now rooted in a sealed `MotionBase`, with `Motion` for motions that animate toward a target and the new `FreeMotion` for self-directed ones. Custom motions that extend `Motion` keep working; code that switches over motion types must handle `FreeMotion`.
 - **BREAKING**: simulations created by custom motions (`Motion.createSimulation`, `FreeMotion.createSimulation`) must be pure functions of time. Motor queries them at any time: ahead to find when they finish, and backwards when scrubbing, seeking or looping. In 1.x, and in Flutter's `AnimationController`, a simulation was only queried at increasing times, so one that integrated step by step or kept state between calls worked. In 2.0 such a simulation shows wrong values, jumps to its end, or loops as a square wave. Motor's own simulations and every public Flutter simulation are pure. If yours integrates step by step, restart it from its initial state whenever it's asked about an earlier time than the last one; see [MIGRATION.md](./MIGRATION.md).
 - **BREAKING**: classes that `implements Motion` must now also provide `duration` and `scaleTo(Duration)`, which 2.0 added to `Motion` and `MotionBase` with default implementations. Classes that `extends Motion` inherit those defaults and keep compiling; extending is the recommended way to write a custom motion. See [MIGRATION.md](./MIGRATION.md).

### Tracks: a new multi-property animation system

 - **FEAT**: add `Track<T>`, the identity-based key for one animated property. A track carries a `MotionConverter`, an optional `initial` value, an optional default `motion`/`motionPerDimension`, and an optional `debugLabel`. Build instructions with `track.to(...)`, `track(...)` (multi-step), `track.free(...)`, `track.value(...)`, and `track.velocity(...)`.
 - **FEAT**: add `TrackStep<T>`, the unit of a track animation: `TrackStep.to` (animate to a target), `TrackStep.at` (a keyframe that arrives exactly at an absolute time), `TrackStep.hold`, `TrackStep.free` (run a self-directed `FreeMotion`), and `TrackStep.sync` (a barrier shared by tracks through a token). `.at` stretches its motion over the gap when the preceding step ends early enough, and otherwise cuts the preceding step so its motion runs its natural duration; the two cases meet continuously, and with no time left the value arrives instantly.
 - **FEAT**: add `TrackAnimation<T>` (one track's steps plus its own `from`/`withVelocity`), `TrackTimeline` (a reusable, value-equatable multi-track clip that owns its `LoopMode`), and `TrackPhaseTimeline<P>` (named phases with sync barriers at phase boundaries, one-time `initialValues`/`initialVelocities`, `phaseLoop`, and the phases as a plain clip via `flattened`). `TrackController(initialValues:)` sets a track's value the first time the controller sees it.
 - **FEAT**: add `TrackController`, a multi-track controller on one ticker:
   - `play`/`animate` start plans for the named tracks, `set` jumps without animating, and `stop` lets the running step settle when its motion needs to (for example a spring) or halts with `canceled: true`; either way, stopped tracks keep the direction they were moving in as status, as `MotionController` does in 1.x. Each call returns its own `TickerFuture`, which completes when that call's tracks finish and is canceled when one of them is restarted or stopped with `canceled: true`.
   - `pause`, `resume`, and `scrubTo` work on one playback timeline that only advances while the controller ticks, so pausing, restarting, and scrubbing never rewind or misalign tracks. Flutter's `timeDilation` applies as usual.
   - Sync barriers release at the exact moment the last participant arrives (or, when a participant is stopped or redirected, no earlier than that moment), independent of the frame rate, and hold every cycle in looping plans. Scrubbing resolves them the same way playback does.
   - Playback is a function of time alone: each step's duration is resolved once and kept, so ticking live, jumping ahead, and scrubbing back always agree, and loops that repeat use constant memory. Loops that cannot repeat exactly (for example with sync barriers) keep their two most recent cycles, or about a thousand steps while an inspection tool is attached.
   - `onStep` reports every step a track enters, in order, even within one frame.
   - `animationOf(track)` returns a cached `Animation<T>` for one track that composes with tweens, curves, and transitions and reports that track's own status.
   - `status` combines the tracks moved since the controller was last idle: `reverse` while all moving tracks head down, otherwise `forward`; once done, `dismissed` if all are dismissed, otherwise `completed`.
 - **FEAT**: add `PhaseTrackController<P>` with `playPhases`, `goToPhase`, `setTimeline`, and `currentPhase`, reporting `PhaseTransitioning`/`PhaseSettled`. `phaseLoop` supports `loop`, `seamless`, and `pingPong` (phases in reverse order on the way back).
 - **FEAT**: add `TrackBuilder` (inline `animations:` + `loop:`, or `TrackBuilder.timeline(...)`) and `PhaseTrackBuilder<P>` (manual `currentPhase` or auto-advancing `playing`). Equal animation lists and timelines do not restart playback on rebuild, and when an animation list or phase timeline changes, only the tracks whose animation changed restart, so one track can follow user input while another plays keyframes. Changing `currentPhase` while `playing` continues auto-advancing from that phase. As on the motion builders, `active: false` moves the tracks straight to where their animations (or the current phase) end, without animating; `restartTrigger` replays from the start (including the timeline's seeds). Both accept `velocityTracking`, which can change without restarting playback, as can `TrackController.velocityTracking`.

### Inspection and tooling

 - **FEAT**: add an `@experimental` inspection library at `package:motor/inspection.dart`, which may change in minor releases. `MotorInspectionRegistry` lets a tool discover controllers created while it is attached. `inspectPlayback()` returns immutable snapshots with each track's plan, resolved segments, loop cycle and repetition, playhead, barrier state, recorded and estimated step durations, the controller's timeline `position`, and its recent plans. Two hooks change playback: controller-local `playbackSpeed` and `motionOverride`. `isMuted` tells whether a controller's ticker is muted, such as by a `TickerMode`. In debug builds, `debugCreator` returns the builder `Element` that created a controller. `MotorInspectionScope(group:, inspectable:)` and each controller's `inspectionGroup` and `inspectable` decide how tools group or hide controllers; a controller's own setting beats the nearest scope. Apps that never attach a tool compile the inspection hooks away.
 - **FEAT**: while a tool is attached, controllers keep their recent plans, resolve new plans ahead for accurate duration estimates, and let `scrubTo` show plans a track was redirected away from (resuming there continues them). Without a tool none of this is kept.
 - **FEAT**: controllers, builders (`TrackBuilder`, `PhaseTrackBuilder`, the motion builders, `MotionDraggable`), and tracks accept an optional `debugLabel` shown by inspection tools.
 - **FEAT**: the separate `motor_devtools` package provides an in-app inspector built on this library.

### Deprecations

 - **DEPRECATION**: the legacy sequence stack — `MotionSequence` (including `StateSequence`, `StepSequence`, `SpanningSequence`, and `ValueWithMotion`), `SequenceMotionController`, `SequenceMotionBuilder`, and the helpers that build sequences (`toSteps`, `toStates`, `spanning`, `withSingleMotion`, `SingleMotionPhaseSequence`) — is deprecated and will be removed in motor 3.0. It remains fully functional in 2.x. Migrate to `Track`/`TrackPhaseTimeline` with `PhaseTrackBuilder` or `PhaseTrackController`; see [MIGRATION.md](./MIGRATION.md) for a step-by-step guide.
 - **DEPRECATION**: `Motion.unboundedWillSettle` is deprecated and will be removed in motor 3.0. Motor never read it. It now defaults to `true`, and motor's own motions no longer override it, so springs report `true` too (in 1.x they reported `false`). Remove your overrides.

### Motion type hierarchy

 - **FEAT**: introduce the sealed `MotionBase` root. `Motion` extends it and remains the target-based motion type; all existing `Motion.*` factories are unchanged. See [Breaking changes](#breaking-changes).
 - **FEAT**: add `FreeMotion`, a self-directed motion that evolves from a position and velocity without an end value (decay, friction, gravity, …). Includes `FreeMotion.friction` / `FrictionMotion` (with `drag` and `constantDeceleration`), plus `finalValue` and `project` to anticipate the resting value without running the full simulation. `needsSettle` stays on `Motion`, where graceful stops read it, so a `FreeMotion` doesn't implement it.
 - **FEAT**: add `MotionBase.scaleTo(Duration)` to force a motion to complete in an exact duration. It is exact for curves, linear, and none, and falls back to `FixedDurationMotion` / `FixedDurationFreeMotion` wrappers for springs and free motions.
 - **FEAT**: add `Motion.duration`, exposing the characteristic duration of a motion (exact for fixed-duration motions, the settling time for springs, `null` when unknown).
 - **FEAT**: `Motion.customSpring` / `SpringMotion` now accept a `snapToEnd` flag, which defaults to `true` (see [Breaking changes](#breaking-changes)). Snapping may cause small visual jumps in `MotionSequence`s; set `snapToEnd: false` on those springs if needed.

### Controllers

 - **REFACTOR**: `MotionController` is now a thin wrapper over a single-track `TrackController`, so the single-value and multi-track stacks share one engine. This is an internal change and should be fully compatible with 1.x.
 - **FEAT**: add `MotionController.play(List<TrackStep<T>>, {loop, onStep})` for step-based and looping single-value playback (steps without a motion use the controller's), plus `trackedVelocityEstimate`.
 - **REFACTOR**: the deprecated sequence APIs (`SequenceMotionController` and `SequenceMotionBuilder`) now run on the 2.0 track engine; the internal legacy controller copy is deleted. `SequenceMotionController` is a subtype of the exported `MotionController` again, restoring 1.x source compatibility. Phase timing is unchanged (pinned by the legacy sequence semantics tests). Observable deltas:
   - phase-boundary values are sampled at the simulation's exact completion time (a sub-tolerance difference, visible only to non-snapping springs).
   - three goldens changed within anti-aliasing tolerance: `loop_mode_seamless.png` (the seamless jump renders one frame earlier because the continuation is synchronous instead of legacy's post-frame callback — raster visibility only, the value timeline anchors identically), `spanning.png` (trimmed-motion leg boundaries sample at exact done-time slightly before the nominal end, where legacy sampled past-done and clamped to the end value — sub-tolerance anti-aliasing drift), and `state_sequence_1d_animation.png` (the non-snapping-spring boundary-sampling delta above).

### Velocity tracking

 - **FEAT**: add automatic velocity tracking. `MotionController` and all motion builders track velocity when their value is set manually, so animations started without an explicit velocity keep their momentum. It is on by default (see [Breaking changes](#breaking-changes)). New public API: `VelocityTracking`, `MotionVelocityTracker`, and `MotionVelocityEstimate`.

### Motion converters

 - **FEAT**: add directionality support to `MotionConverter`. New `DirectionalMotionConverter` mixin, `ComparableMotionConverter` mixin, and `MotionConverter.customDirectional` factory let controllers report `AnimationStatus.reverse` when animating toward a "smaller" value, and `dismissed` after a move down. `SingleMotionConverter` is directional; the other built-in converters are not. See [Breaking changes](#breaking-changes).

### Looping and phases

 - **REFACTOR**: extract `LoopMode` into its own file (still re-exported from `motion_sequence.dart`, so this is source-compatible). `LoopMode` (`none`, `loop`, `pingPong`, `seamless`) now drives track and timeline playback as well.
 - **FEAT**: `PhaseTransition` has a `phase` getter (the current or target phase). Its factory constructors are removed; see [Breaking changes](#breaking-changes).

### Fixed tick rates

 - **FEAT**: motor widgets can tick at a fixed rate with [`fixed_ticker`](https://pub.dev/packages/fixed_ticker). `MotionBuilder`, `VelocityMotionBuilder`, `TrackBuilder`, `PhaseTrackBuilder`, `SequenceMotionBuilder`, `MotionDraggable` and `MotionPadding` take an optional `tickerRate` and follow the nearest `TickerRateScope`; `tickerRate` overrides the scope. Without either, they tick every frame as before. Controllers are unchanged: pass them a `FixedTickerProviderStateMixin` state for a fixed rate. `TickerRate`, `TickerRateScope`, `FixedTickerProviderStateMixin` and `SingleFixedTickerProviderStateMixin` are exported from `package:motor`.

### Performance

 - **PERF**: per-frame work allocates far less (in-place sampling, reused buffers, lazy velocities and segment ends). In AOT release benchmarks against the equivalent `AnimationController` setup, 10 to 1000 tracks on one controller cost 0.89× to 1.06× per frame, a single value about 1.8×, starting or retargeting a spring 1.4× to 4.2× (down from up to 39×), and following a drag with velocity tracking 1.2× to 2.4×. Methodology and all results are in [benchmark/ANALYSIS.md](https://github.com/whynotmake-it/rivership/blob/main/packages/motor/benchmark/ANALYSIS.md) (thanks to [definev](https://github.com/definev) for the original harness and allocation work).

### Fixes

 - **FIX**: two-keyframe `SpanningSequence`s with `LoopMode.seamless` now use the full return slice instead of a degenerate zero-extent motion.
 - **FIX**: `SpringMotion` equality (and `hashCode`) now includes `snapToEnd`, so spring motions differing only in `snapToEnd` compare unequal. This affects motion swaps on `MotionController`, which previously ignored a `snapToEnd` change.
 - **FIX**: `NoMotion` compares by `duration`. In 1.x only the same instance was equal, so setting an equal `NoMotion` on a `MotionController` redirected the animation.
 - **FIX**: `CupertinoMotion.copyWith` now reads its defaults from the stored `duration`/`bounce` fields instead of round-tripping them through `SpringDescription`, so unchanged values are preserved exactly.
 - **FIX**: motion builders no longer stop and reset their value on every rebuild while inactive; they only do so on the active→inactive transition.
 - **FIX**: the velocity of a curve (`CurvedMotion`, `LinearMotion`) is now its actual rate of change instead of 4× too large (see [Breaking changes](#breaking-changes)). A step following a curve in the same plan inherits the full speed the curve ended with.
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
