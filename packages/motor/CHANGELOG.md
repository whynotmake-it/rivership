## 2.0.0-dev.0

Motor 2.0 adds a multi-track animation engine and rebuilds the 1.x controllers on it. Most 1.x code compiles unchanged, but several runtime behaviors differ. [MIGRATION.md](./MIGRATION.md) shows how to move over.

### Breaking changes

Behavior

 - Springs snap exactly onto their target when they settle (`snapToEnd` now defaults to `true`). Pass `snapToEnd: false` for the 1.x behavior.
 - Controllers and motion builders track velocity by default. If you set `value` yourself (for example while dragging) and then animate without `withVelocity`, the animation continues with the tracked velocity. Pass `velocityTracking: const .off()` to start from rest as in 1.x.
 - `status` follows direction. With a directional converter (`SingleMotionConverter` or a custom `DirectionalMotionConverter`), a controller reports `reverse` while moving down and settles as `dismissed` after a move down, otherwise `completed`. Converters without a direction (such as `Offset`) keep reporting `forward` while animating and settle as `completed`. This also applies to `BoundedMotionController` (it no longer depends on its bounds) and to the sequence controllers. Use `isAnimating`, not `status == .forward`, to ask whether something is animating.
 - A graceful `stop()` completes pending `MotionFuture`s once the tracks come to rest instead of canceling them. Use `stop(canceled: true)` to cancel.
 - A curve's velocity is now its real rate of change. 1.x reported it 4 times too large, so a spring that took over from a running curve started too fast. Retune springs you adjusted around that.
 - A spring now settles only once it stays within `tolerance` for good. Futures, `status` and the next sequence phase can arrive up to about 0.3 s later than in 1.x. The motion itself is unchanged.
 - `CupertinoMotion()` defaults to 500 ms instead of 550 ms, and `CupertinoMotion.interactive()` uses bounce 0.15 instead of 0.14. Both now match SwiftUI.
 - `ColorRgbMotionConverter.denormalize` no longer clamps channels to 0..1. The shown value is still clamped, but the spring state is not.

API

 - `MotionController.animateTo` and `stop`, and `BoundedMotionController.animateTo`, `forward` and `reverse`, return `MotionFuture` instead of `TickerFuture`. Only subclasses that override them need to change.
 - `PhaseTransition.settled(...)` and `.transitioning(...)` are removed. Use `PhaseSettled(phase)` and `PhaseTransitioning(from: a, to: b)`.
 - `Motion` now sits under a sealed `MotionBase`, next to the new `FreeMotion`. Code that switches over motion types must handle `FreeMotion`.
 - Classes that `implements Motion` must add `duration` and `scaleTo(Duration)`. Classes that `implements MotionConverter` must add `dimensions` (return `null` to keep the old behavior). Classes that extend them are unaffected.
 - Simulations from custom motions must be pure functions of time, because motor now queries them backwards (scrubbing, looping) and ahead (finding when they settle). A simulation that integrates step by step must restart from its initial state when asked about an earlier time.
 - A `MotionConverter` must not keep or change the lists motor passes in. Copy them with `List.of(values)` if you need to.
 - `MotionSequence` and its subclasses no longer depend on `equatable`. They still compare by value. If you customized equality through `props`, override `==` and `hashCode` instead.

Moved to `motor_widgets`

 - `MotionPadding`, `PaddingExtended` and `MotionDraggable` are no longer exported from `package:motor`. Add `motor_widgets` and import `package:motor_widgets/motor_widgets.dart`. `MotionDraggable` was rebuilt there to animate every drop. See its changelog for the changed parameters.

### New

 - Tracks: `Track`, `TrackStep` (`to`, `at`, `hold`, `free`, `sync`), `TrackTimeline` and `TrackPhaseTimeline`, played by `TrackController`, `PhaseTrackController`, `TrackBuilder` and `PhaseTrackBuilder`. They support pause, resume, scrubbing, looping (`loop`, `seamless`, `pingPong`) and `delay`. When a new animation replaces a running one, the running motion hands over its velocity, so staggered items keep their momentum.
 - Timing: every controller call returns a `MotionFuture`. Awaiting it waits until the motion has settled. Its `ended` completes at the motion's `duration`, and `WaitUntil.ended` lets the next step start then.
 - Motions: `Motion.instant`, `FreeMotion` (including `FreeMotion.friction`), `MotionBase.scaleTo(Duration)` and `Motion.duration`. `SettlingSimulation` lets a simulation report when it settles.
 - Converters: `MotionDimension` (`linear`, `periodic`, `bounded`), `MotionConverter.angle`, which turns the short way round, and `DirectionalMotionConverter`.
 - Velocity tracking: `VelocityTracking`, `MotionVelocityTracker` and `MotionVelocityEstimate`.
 - Fixed tick rates: builders take `tickerRate` and follow the nearest `TickerRateScope`, with [`fixed_ticker`](https://pub.dev/packages/fixed_ticker).
 - Inspection: an experimental API at `package:motor/inspection.dart` that the new `motor_devtools` package builds on. Controllers, builders and tracks accept a `debugLabel`, and `TrackBuilder` takes `initialValues`.
 - Performance: less allocation per frame. In release benchmarks, 10 to 1000 tracks on one controller cost 0.89 to 1.06 times an equivalent `AnimationController` setup per frame. See [benchmark/README.md](https://github.com/whynotmake-it/rivership/blob/main/packages/motor/benchmark/README.md). Thanks to [definev](https://github.com/definev) for the original harness.

### Deprecated

 - `MotionSequence` (with `StateSequence`, `StepSequence`, `SpanningSequence` and `ValueWithMotion`), `SequenceMotionController`, `SequenceMotionBuilder` and the helpers that build sequences. They still work in 2.x and run on the new engine. Migrate to `TrackPhaseTimeline` with `PhaseTrackBuilder` or `PhaseTrackController`. They will be removed in 3.0.
 - `NoMotion` and `Motion.none`. Use `Motion.instant`, or a `TrackStep.hold`. They will be removed in 3.0.
 - `Motion.unboundedWillSettle`, which motor never read. It will be removed in 3.0.

### Fixes

 - A motion that never settles (such as an undamped spring) keeps animating until it is retargeted or stopped, and its future doesn't complete. Settle searches now stop after two minutes, not at shorter fixed limits.
 - `stop()`, `pause()` and `resume()` no longer notify value listeners, since they change no value.
 - An animation that is already at its only target doesn't play.
 - `LoopMode.pingPong` reverses each step to where the step before it ended, also across holds, syncs and free steps.
 - `TrackStep.at` keyframes and `TrimmedMotion` hand their real velocity to the next step, and `TrimmedMotion` settles exactly on its target.
 - Equality is consistent. `SpringMotion` and `CurvedMotion` include `snapToEnd` and `tolerance`. Equal `NoMotion`s no longer redirect an animation. Converters made without `const` compare equal by their functions, so rebuilding them doesn't restart anything.
 - Motion builders no longer stop and reset their value on every rebuild while inactive.
 - A `CupertinoMotion` bounce above 1 or at or below -1 asserts in debug builds.

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
