## 2.0.0-dev.0

> Note: This is the first Motor 2.0 pre-release. Existing `Motion.*` factories,
> `MotionController`, `MotionBuilder`, `MotionSequence`,
> `SequenceMotionController`, and `SequenceMotionBuilder` stay
> source-compatible with a few exceptions, though several runtime behaviors
> have changed. Every change that can break 1.x code is listed under
> [Breaking changes](#breaking-changes), and [MIGRATION.md](./MIGRATION.md)
> walks through migrating.

### Breaking changes

Each entry explains what changed, how 1.x behaved, and how to migrate.

 - **BREAKING**: Springs now snap exactly onto their target when they settle (`snapToEnd` defaults to `true` on `SpringMotion`, `CupertinoMotion`, `MaterialSpringMotion`, and the spring factories on `Motion`). In 1.1.0 it defaulted to `false`, so a spring could stop slightly short of its target (such as `0.9996` instead of `1.0`). Pass `snapToEnd: false` to keep the 1.x behavior.
 - **BREAKING**: Controllers and motion builders track velocity by default. When you set `value` manually (for example while dragging) and then animate without `withVelocity`, the animation continues with the tracked velocity instead of starting from rest as in 1.x. Pass `velocityTracking: const .off()` to restore the old behavior, or pass gesture velocity directly via `withVelocity` for best accuracy.
 - **BREAKING**: `status` now reports `reverse` while a value moves down when using a directional `MotionConverter` (`SingleMotionConverter` or a custom `DirectionalMotionConverter`). In 1.x, `MotionController.status` was always `forward` while animating. Non-directional multi-dimensional converters (`Offset`, `Size`, `Rect`, `Color`, and plain custom converters) still report `forward` while animating and `completed` at rest. Use `isAnimating` instead of `status == .forward` to check whether a controller is running.
 - **BREAKING**: With a directional converter, a move down now settles as `dismissed` and any other move settles as `completed` (including after setting `value` directly). For non-directional converters, status settles as `completed`, and `dismissed` only when settling exactly on the initial value. In 1.x, status was `dismissed` only when the last animation target equaled the initial value. Check `!status.isAnimating` or await the returned `MotionFuture` instead of comparing against `completed`.
 - **BREAKING**: `BoundedMotionController` status now follows the same rule as `MotionController` instead of being `dismissed` at `lowerBound` and `completed` at `upperBound`. Directional converters behave the same in practice (`reverse()` ends `dismissed`, `forward()` ends `completed`); for non-directional bounded controllers (such as a bounded `Offset`), `reverse()` now ends `completed` unless `lowerBound` is the initial value. Compare `value` with `lowerBound` and `upperBound` to check which bound you are at.
 - **BREAKING**: `SequenceMotionController` and `SequenceMotionBuilder` report `reverse` while a phase moves down (for example on the way back in `LoopMode.pingPong`) and `dismissed` after a final move down. They still never report `completed` between loop cycles. Use `isAnimating` instead of checking `forward` or `completed`.
 - **BREAKING**: Calling `animateTo` with the current value keeps the previous direction as `status` (in 1.x it reported `forward`).
 - **BREAKING**: `MotionController.animateTo` and `stop`, and `BoundedMotionController.animateTo`, `forward`, and `reverse`, now return `MotionFuture` instead of `TickerFuture`. Callers are unaffected because `MotionFuture` implements `TickerFuture`; subclasses overriding these methods must update their return type to `MotionFuture`.
 - **BREAKING**: `PhaseTransition.settled(...)` and `PhaseTransition.transitioning(...)` are removed. Construct `PhaseSettled(phase)` and `PhaseTransitioning(from: a, to: b)` directly. A new `phase` getter returns the current or target phase.
 - **BREAKING**: Curve velocities now report their actual rate of change. In 1.x, `CurvedMotion` and `LinearMotion` reported velocities 4× too large, causing a spring taking over mid-curve to launch 4× too fast. If you tuned springs around that overshoot, retune them.
 - **BREAKING**: The motion hierarchy is now rooted in a sealed `MotionBase`, with `Motion` for target-based motions and `FreeMotion` for self-directed ones. Custom classes extending `Motion` continue to work; exhaustive switches over motion types must now handle `FreeMotion`.
 - **BREAKING**: Simulations created by custom motions (`Motion.createSimulation`, `FreeMotion.createSimulation`) must be pure functions of time. Motor queries them ahead to compute settle times and backward when scrubbing, seeking, or looping. Stateful step-by-step simulations must reset from their initial state when queried at an earlier time; see [MIGRATION.md](./MIGRATION.md).
 - **BREAKING**: `MotionConverter` implementations must not retain or mutate the lists Motor hands them. `denormalize` now receives a reused internal buffer and Motor may keep the list returned by `normalize`. Converters that construct a new value from the numbers are unaffected and now allocate less; if yours returns or stores the list itself, copy it with `List.of(values)`.
 - **BREAKING**: Motor no longer depends on `equatable`. `MotionSequence` and its subclasses no longer mix in `EquatableMixin` (no `props` or `stringify`). They still compare by value; custom subclasses that overrode `props` should override `==` and `hashCode` instead.
 - **BREAKING**: Classes that `implements Motion` (instead of extending it) must now implement `duration` and `scaleTo(Duration)`. Classes that `extends Motion` inherit default implementations.
 - **BREAKING**: `CupertinoMotion()` and `Motion.cupertino()` now default to `500 ms` (matching SwiftUI's default `Spring()`, identical to `CupertinoMotion.smooth()`) instead of `550 ms`. Pass `duration: const Duration(milliseconds: 550)` to keep the 1.x timing.
 - **BREAKING**: `CupertinoMotion.interactive()` and `Motion.interactiveSpring()` now use bounce `0.15` instead of `0.14` to match SwiftUI's current `Animation.interactiveSpring`, and `extraBounce` adds to `0.15`. Use `CupertinoMotion(duration: const Duration(milliseconds: 150), bounce: 0.14)` for the 1.x spring.
 - **BREAKING**: A graceful `stop()` no longer cancels pending futures on `MotionController`, `BoundedMotionController`, `TrackController`, and `PhaseTrackController`. It completes `ended` immediately and the future itself once the motion settles, matching `AnimationController.stop(canceled: false)`. Pass `stop(canceled: true)` to cancel.
 - **BREAKING**: `ColorRgbMotionConverter.denormalize` no longer clamps channels to `0..1` itself; the converter now declares bounded dimensions so the displayed value is clamped while internal spring state and velocity are preserved. Code calling `denormalize` directly may see out-of-range channels.
 - **BREAKING**: Classes that `implements MotionConverter` must add the `dimensions` getter (return `null` for linear dimensions). Classes that `extends MotionConverter` or use `MotionConverter.custom` keep compiling.
 - **BREAKING**: `MotionPadding`, `PaddingExtended`, and `MotionDraggable` moved to the new [`motor_widgets`](../motor_widgets) package and are no longer exported from `package:motor`. `MotionDraggable` now animates every drop (accepted, rejected, or removed), takes builder callbacks for `feedback` and `childWhenDragging`, removes `onlyReturnWhenCanceled` and `feedbackMatchesConstraints`, and defaults `motion` to `CupertinoMotion.smooth()`. See [MIGRATION.md](./MIGRATION.md).

### Tracks: multi-property motion orchestration

 - **FEAT**: Add `Track<T>`, an identity-based key for one animated property carrying a `MotionConverter`, optional `initial` value, optional default `motion`/`motionPerDimension`, and optional `debugLabel`. Call a track with a list of steps to build a `TrackAnimation<T>` (`track([.to(1)])`), or use `track.value(..., velocity:)` / `track.velocity(...)` to build snapshots for `set` and `initialValues`.
 - **FEAT**: Add `TrackStep<T>`, the building block of track choreography:
   - `TrackStep.to(value, motion:, until:)` — animate toward a target, handing off at `WaitUntil.settled` (default) or `WaitUntil.ended` (after the motion's `duration`, carrying current value and velocity into the next step).
   - `TrackStep.at(time, value, motion:)` — keyframe that arrives at `value` at an exact time on the track's clock, stretching when there is spare time or trimming the previous step so the keyframe lands on schedule.
   - `TrackStep.hold(duration)` — hold at the current value while letting any preceding `WaitUntil.ended` spring finish settling.
   - `TrackStep.free(motion:)` — hand off to a self-directed `FreeMotion` (such as `FrictionMotion`) until rest.
   - `TrackStep.sync(token:)` — coordinate tracks on the same controller so every track sharing `token` waits until the last one arrives before continuing together.
   - `TrackStep.loop(steps, mode:, count:, together:)` — repeat any slice of steps with `LoopMode` (`.loop`, `.pingPong`, `.seamless`, `.none`), optional finite `count:`, and optional `together:` token to keep sibling loops synchronized each cycle.
 - **FEAT**: Add `TrackController`, a single-ticker multi-track controller that backs every widget and controller in Motor:
   - `animate` starts or redirects tracks, `set` jumps immediately, `stop` settles springs or halts with `canceled: true`, and `pause`, `resume`, and `scrubTo` operate on a single controller timeline.
   - Sync barriers release at the exact arrival moment independent of frame rate, release cleanly if a participant is stopped or redirected, and resolve identically when scrubbing.
   - Playback is a pure function of time: ticking live, jumping ahead, and scrubbing back always agree, and repeating loops run in constant memory.
   - `onStep` fires in order for every step a track enters, even when multiple steps occur within one frame.
   - `animationOf(track)` returns a cached `Animation<T>` for interop with Flutter transitions and tweens, reporting that track's own `AnimationStatus`.
   - `status` combines all tracks moved since the controller was last idle.
 - **FEAT**: Add `TrackPhaseTimeline<P>`, `PhaseTrackController<P>`, and `PhaseTrackBuilder<P>` for named UI states with automatic sync barriers between phases, `initialValues` (with optional starting velocities), `loop` modes, `onTransition` (`PhaseTransitioning` / `PhaseSettled`), and `flattened` for playing phases once inside a plain `TrackBuilder` or `TrackController`.
 - **FEAT**: Add `TrackBuilder` for declarative multi-track playback with `animations`, `initialValues`, `active`, `restartTrigger`, `velocityTracking`, `tickerRate`, and `debugLabel`. Rebuilds only redirect tracks whose animation changed, so one track can follow live input while others keep playing.
 - **FEAT**: Add `delay:` on track animations (`track([...], delay:)`) for staggering. When redirecting a running track with a delay, the running motion keeps playing through the delay (and any leading holds or barriers) before handing off its value and velocity to the first moving step.
 - **FEAT**: Mark `StepTo`, `StepFree`, `StepHold`, `StepAt`, `StepSync`, `StepLoop`, `TrackValue`, `TrackAnimation`, and `TrackPhaseTimeline` as `final`, and `Track` as `base`.

### Inspection and tooling

 - **FEAT**: Add an `@experimental` inspection library (`package:motor/inspection.dart`) for developer tools. `MotorInspectionRegistry` discovers live controllers, `inspectPlayback()` returns immutable snapshots (plans, resolved segments, loop cycles, playheads, barrier waits, and recorded/estimated step durations), and `playbackSpeed` / `motionOverride` let tools slow down or swap motions on a single controller. `MotorInspectionScope` and per-controller `inspectionGroup` / `inspectable` control grouping and visibility. When no tool is attached, inspection overhead is skipped.
 - **FEAT**: Add `debugLabel` to controllers, builders, and tracks so they appear with readable names in inspection tools.
 - **FEAT**: Introduce the companion [`motor_devtools`](../motor_devtools) package for an optional in-app timeline inspector and spring tuner.

### Deprecations

 - **DEPRECATION**: `MotionSequence` (`StateSequence`, `StepSequence`, `SpanningSequence`, `ValueWithMotion`, `SingleMotionPhaseSequence`), `SequenceMotionController`, `SequenceMotionBuilder`, and sequence helper extensions are deprecated and will be removed in 3.0. They continue to work on the 2.0 track engine; migrate to `Track` and `TrackPhaseTimeline` using [MIGRATION.md](./MIGRATION.md).
 - **DEPRECATION**: `NoMotion` and `Motion.none` are deprecated and will be removed in 3.0. Use `Motion.instant` to jump to a target immediately, or `TrackStep.hold` to pause at the current value.
 - **DEPRECATION**: `Motion.unboundedWillSettle` is deprecated and will be removed in 3.0. Motor no longer reads it; remove your overrides.

### Motion type hierarchy

 - **FEAT**: Add `Motion.instant` for immediate target updates (useful for reduced motion or toggling animations off).
 - **FEAT**: Introduce the sealed `MotionBase` root with `Motion` (target-based) and `FreeMotion` (self-directed), including `FrictionMotion` (`FreeMotion.friction`) with `finalValue` and `project` helpers.
 - **FEAT**: Add `MotionBase.scaleTo(Duration)` to retime any motion to a given `duration` (`FixedDurationMotion` and `FixedDurationFreeMotion` preserve spring bounce and start velocity).
 - **FEAT**: Add `Motion.duration` and `FreeMotion.duration` for perceived motion length, `MotionFuture` (a `TickerFuture` with `.ended` completing at `duration`), and the `SettlingSimulation` mixin (`settlesAt` and `Simulation.simulateSettleTime()`).
 - **FEAT**: Add `snapToEnd` (defaulting to `true`) to `Motion.customSpring`, matching `SpringMotion`.

### Single-value controllers, velocity tracking, and converters

 - **REFACTOR**: Rebuild `MotionController` as a thin wrapper over a single-track `TrackController`, and rebuild the deprecated sequence stack on the same engine.
 - **FEAT**: Add `MotionController.play(List<TrackStep<T>>, {onStep})` for multi-step and looping single-value playback, plus `trackedVelocityEstimate`.
 - **FEAT**: Add automatic velocity tracking (`VelocityTracking`, `MotionVelocityTracker`, `MotionVelocityEstimate`), enabled by default on all controllers and builders.
 - **FEAT**: Add `DirectionalMotionConverter`, `ComparableMotionConverter`, and `MotionConverter.customDirectional` for directional `AnimationStatus` reporting.
 - **FEAT**: Add `MotionDimension` (`linear()`, `periodic(period)`, `bounded(min, max)`), `MotionConverter.dimensions`, and `MotionConverter.angle` for shortest-path radian animations.
 - **REFACTOR**: Extract `LoopMode` into its own file (still re-exported from `motion_sequence.dart`).

### Fixed tick rates

 - **FEAT**: Add `tickerRate` and `TickerRateScope` support via [`fixed_ticker`](https://pub.dev/packages/fixed_ticker) across all Motor builders, and re-export `TickerRate`, `TickerRateScope`, `FixedTickerProviderStateMixin`, and `SingleFixedTickerProviderStateMixin` from `package:motor`.

### Performance

 - **PERF**: Significantly reduced per-frame allocations (in-place sampling, reused buffers, lazy velocities and segment ends). In AOT release benchmarks against equivalent `AnimationController` setups, 10–1000 tracks on one `TrackController` cost 0.89×–1.06× per frame. See [benchmark/README.md](https://github.com/whynotmake-it/rivership/blob/main/packages/motor/benchmark/README.md) (thanks to [definev](https://github.com/definev) for the original benchmark harness and allocation work).
 - **PERF**: Starting `N` tracks sharing a sync token now runs in linear `O(N)` time instead of `O(N²)` (4096 staggered tracks with three sync barriers dropped from 355 ms to 15 ms in AOT).

### Fixes

 - **FIX**: Motions that never settle (undamped springs, non-terminating free motions, or simulations whose `simulateSettleTime()` is `null`) now keep animating until redirected or stopped instead of settling artificially at a fixed horizon; settle searches cap at 120 s consistently.
 - **FIX**: Zero-period, single-step, or stalled loops settle cleanly instead of ticking forever.
 - **FIX**: `CupertinoMotion` asserts in debug mode if `bounce` is outside `(-1, 1]` and clamps `bounce > 1` to `1` in release builds (matching SwiftUI) instead of producing negative damping.
 - **FIX**: `stop()`, `pause()`, and `resume()` no longer notify value listeners when no value changes (unless releasing a sync barrier), matching `AnimationController.stop` and allowing render objects to stop controllers during layout.
 - **FIX**: Animations already resting on their only target don't tick, notify, or change status, and their futures complete immediately.
 - **FIX**: Instant downward moves (such as `Motion.instant()`) now report `reverse` and `dismissed` instead of `forward` and `completed`.
 - **FIX**: `LoopMode.pingPong` reverses each step to where the preceding step ended even when holds, barriers, or free steps sit between targets.
 - **FIX**: `TrackStep.at` and `TrimmedMotion` now hand off their true arrival velocity to the following step, and `TrimmedMotion` settles accurately on its target.
 - **FIX**: Two-keyframe `SpanningSequence`s with `LoopMode.seamless` now use the full return slice instead of a degenerate zero-extent motion.
 - **FIX**: Fixed equality and `hashCode` on `SpringMotion` (`snapToEnd`, `tolerance`), `CurvedMotion` (`tolerance`), `NoMotion` (`duration`), steps/animations/sequences (comparing motions by movement equivalence), and `MotionConverter`s (by type or function identity).
 - **FIX**: `CupertinoMotion.copyWith` now reads defaults from its stored `duration`/`bounce` fields rather than round-tripping through `SpringDescription`.
 - **FIX**: Motion builders no longer stop and reset on every rebuild while `active` is `false` — only on the `true → false` transition.
 - **FIX**: Springs now settle only once they remain within `tolerance` permanently, rather than on the first frame passing through the target near a peak.

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
