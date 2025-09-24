## 0.5.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.5.0-dev.13

 - Update a dependency to the latest release.

## 0.5.0-dev.12

 - Update a dependency to the latest release.

## 0.5.0-dev.11

 - Update a dependency to the latest release.

## 0.5.0-dev.10

 - Update a dependency to the latest release.

## 0.5.0-dev.9

> Note: This release has breaking changes.

 - **FEAT**: add TrimmedMotion as a way to take subsets of any motion.
 - **DOCS**: update readme in heroine to reflect new changes.
 - **BREAKING** **REFACTOR**: use positional parameters for `CurvedMotion`.

## 0.5.0-dev.8

 - **FIX**: export all motor motion types from heroine.
 - **FIX**: heroine transitions flicker with flutter 3.35.

## 0.5.0-dev.7

 - Update a dependency to the latest release.

## 0.5.0-dev.6

 - Update a dependency to the latest release.

## 0.5.0-dev.5

> Note: This release has breaking changes.

 - **FIX**: removed an unnecessary rebuild for the arriving heroine (#121).
 - **FEAT**: add optional z-index to `Heroine` (#122).
 - **BREAKING** **REFACTOR**: turned `CupertinoMotion` constants into constructors so parameters can be adjusted on the fly.

## 0.5.0-dev.4

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: remove experimental changes from `springster` and add to new `motor` package instead (#117).
 - **BREAKING** **FEAT**: migrate to motor's Motion system and add comprehensive migration guide.
    - Support all kinds of motions, not just springs.
    - Check out the [package documentation](https://pub.dev/packages/motor) for more details on how to use the new APIs.

## 0.5.0-dev.3

> Note: This release has breaking changes.

 - **DOCS**: improved zoom transition examples.
 - **BREAKING** **FEAT**: Heroine now accepts any `Motion`, not just springs.
 - **BREAKING** **FEAT**: Add `HeroineMode`, an equivalent to `HeroMode` for Heroine.

    Heroine does not respect `HeroMode` anymore, use `HeroineMode` instead.
    This allows for better parallel use of Heroine and Hero in the same tree.


## 0.5.0-dev.2

 - **FEAT**: support nested heroines if they are not part of the same transition.
 - **FEAT**: update examples to use new motor motion APIs.
 - **DOCS**: added fullscreen gif.
 - **DOCS**: add mention to nested heroines in README.

## 0.5.0-dev.1

 - **REFACTOR**: `MotionController` now uses a single `Ticker`, which should also improve performance.
 - **FEAT**: support separate motion per dimension.

## 0.5.0-dev.0

> Note: This release has breaking changes.

 - **FEAT**: use new `Motion` based APIs from motor internally.
 - **BREAKING** **FEAT**: add `MotionConverter` API to simplify the usage of controllers.

## 0.4.0+1

 - Update a dependency to the latest release.

## 0.4.0

> Note: This release has breaking changes.

 - **FIX**: null check error when interacting really quickly (#71).
 - **FIX**: `DragDismissable.pop` calls `maybePop` to better respect the routes wishes.
 - **FEAT**: `DragDismissable` now also dismisses when drag velocity exceeds a threshold.
 - **FEAT**: `HeroineShuttleBuilder` can now be passed a `Curve` to better customize its animation.
 - **BREAKING** **REFACTOR**: Removed `DragDismissble.pop` and the default constructor of `DragDismissible` now pops the page. Use `DragDismissible.custom` if you want to pass a custom callback.
 - **BREAKING** **REFACTOR**: `Heroine` doesn't accept `HeroFlightShuttleBuilder` functions directly anymore. Use `HeroineShuttleBuilder.fromHero` to keep using your existing functions.

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**: `Heroine`s now correctly dispose any Tickers they created.
 - **FEAT**: Add `FadeThroughShuttleBuilder` that fades through a given color. Try to chain it with `FlipShuttleBuilder` for cool effects.
 - **FEAT**: got rid of sleight visual jank that sometimes occured when a heroine arrived at her destination.
 - **BREAKING** **REFACTOR**: rename `SimpleSpring` to `Spring`.
 - **BREAKING** **FEAT**: support chaining `HeroineShuttleBuilder`s for more complex animations.

## 0.2.0+1

 - **FIX**: fixed example dependencies (#62).

## 0.2.0

> Note: This release has breaking changes.

 - **DOCS**: add Bluesky badge to README files across packages.
 - **BREAKING** **REFACTOR**: unified `SpringSimulationController` interface to match `AnimationController` more closely.

## 0.1.1
 - **DOCS**: added animation to README.     
 - **FEAT**: update README files with example links.
 - **FEAT**: added unified example to monorepo.
 - **FEAT**: add motor dependency and enhance Hero widget documentation.

## 0.1.0

- feat: initial commit 🎉
