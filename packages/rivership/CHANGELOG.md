## 0.1.3

 - **FIX**: layout in `AnimatedSizeSwitcher` when `immediateResize` is true.
 - **FEAT**: add springster package.
 - **FEAT**: `useSpringAnimation` and `SimpleSpring` for easier spring-backed animations.
 - **FEAT**: `usePageIndex` hook to only trigger rebuilds when the page changes, not any inbetween values.
 - **FEAT**: `useKeyedState`, which allows for setting keys that trigger a state re-evaluation.
 - **FEAT**: added `AnimatedText` that smoothly swaps out text content and style.
 - **FEAT**: `fadeShuttle`, a Hero transition that smoothly fades between the widgets.
 - **FEAT**: `AnimatedSizeSwitcher` widget that smoothly transitions between widget's sizes on top of animating.

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
