## 0.3.0-dev.10

 - Update a dependency to the latest release.

## 0.3.0-dev.9

 - Update a dependency to the latest release.

## 0.3.0-dev.8

 - Update a dependency to the latest release.

## 0.3.0-dev.7

 - Update a dependency to the latest release.

## 0.3.0-dev.6

 - Update a dependency to the latest release.

## 0.3.0-dev.5

> Note: This release has breaking changes.

 - **FIX**: removed an unnecessary rebuild for the arriving heroine (#121).
 - **BREAKING** **REFACTOR**: turned `CupertinoMotion` constants into constructors so parameters can be adjusted on the fly.

## 0.3.0-dev.4

> Note: This release has breaking changes.
 - **BREAKING** **REFACTOR**: export new `motor` package instead of `springster` (#117).

## 0.3.0-dev.3

 - **FEAT**: add `useMotion` hook and derived hooks for different types.
 - **DOCS**: added docs for `useMotion` to README.

## 0.3.0-dev.2

 - Update a dependency to the latest release.

## 0.3.0-dev.1

 - Update a dependency to the latest release.

## 0.3.0-dev.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: replace direct Spring-based APIs with new Motion type.

## 0.2.0+6

 - Update a dependency to the latest release.

## 0.2.0+5

 - Update a dependency to the latest release.

## 0.2.0+4

 - Update a dependency to the latest release.

## 0.2.0+3

 - Update a dependency to the latest release.

## 0.2.0+2

 - **DOCS**: add Bluesky badge to README files across packages.

## 0.2.0+1

 - **FIX**: updated to `hooks_riverpod` 2.6.1 and removed references to `AutoDisposeRef`.

## 0.2.0
> Note: This release has breaking changes.

 - **FEAT**: add export `heroine` package.
 - Update a dependency to the latest release.
 - **BREAKING** **FEAT**: remove `fadeShuttle`. Use `FadeShuttleBuilder` instead.

## 0.1.3+2

 - Update a dependency to the latest release.

## 0.1.3+1

 - Update a dependency to the latest release.

## 0.1.3

 - **FIX**: layout in `AnimatedSizeSwitcher` when `immediateResize` is true.
 - **FEAT**: add and export motor package.
 - **FEAT**: `usePageIndex` hook to only trigger rebuilds when the page changes, not any inbetween values.
 - **FEAT**: `useKeyedState`, which allows for setting keys that trigger a state re-evaluation.
 - **FEAT**: added `AnimatedText` that smoothly swaps out text content and style.
 - **FEAT**: `fadeShuttle`, a Hero transition that smoothly fades between the widgets.
 - **FEAT**: `AnimatedSizeSwitcher` widget that smoothly transitions between widget's sizes on top of animating.
 - **CHORE**: updated to support Flutter 3.27.

## 0.1.2

 - **FEAT**: `useFixedExtentScrollController`.
 - **FEAT**: `BrightnessTools` extensions.
 - **FEAT**: `String.ifNotEmpty` getter.
 - **FEAT**: `DurationFormatting` extension.
 - **FEAT**: `.tryAs<T>()` extension.
 - **FEAT**: added `IterableTools` extension.
 - **FEAT**: added `SimpleWidgetStates`.
 - **DOCS**: better READMEs.

## 0.1.1

 - **REFACTOR**: renamed packages to rivership.
 - **FIX**: `useDelayed` correctly disposes all timers on unmount.
 - **FEAT**: added `newestValue` and `newestValueOrNull`to AsyncValue.
 - **DOCS**: updated README.

## 0.1.0

- feat: initial commit 🎉
