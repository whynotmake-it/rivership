## Unreleased

> Note: This release has breaking changes to the track APIs.

 - **BREAKING** **REFACTOR**: `Track.origin` is now the optional `Track.initial`. When a track is first needed and no value/`from`/`initial` is available, it falls back to a zero value inferred from the animation's first target (the `MotionConverter.zero` idea was dropped).
 - **BREAKING** **FEAT**: per-track `from`/`withVelocity` now live on `Track.call`/`.to`/`.free` (i.e. on `TrackAnimation`) instead of on `TrackController.animate`, `TrackTimeline`, and the multi-track builder.
 - **BREAKING** **REFACTOR**: rename `MultiTrackMotionBuilder` to `TrackBuilder`, with a default constructor (`animations:` + `loop:`, mirroring `TrackController.animate`) and a `TrackBuilder.timeline(...)` constructor (mirroring `TrackController.play`). The `timeline`/`play` duality and its assertion are gone.
 - **FIX**: `TrackBuilder` no longer restarts playback on every rebuild — inline animation lists are compared deeply and timelines compare by value.
 - **BREAKING** **FEAT**: `TrackController.animate` gains a `loop` parameter and drops its `from`/`withVelocity` list parameters.
 - **BREAKING** **REFACTOR**: `TrackPhaseTimeline` keeps its one-time `from`/`withVelocity` seeds; `PhaseTrackBuilder` drops its builder-level `from` (seed via the timeline instead).

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