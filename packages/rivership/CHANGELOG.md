## 0.3.0-dev.4

> Note: This release has breaking changes.

 - **FIX**: update intl dependency (#107).
 - **FIX**: fixed `flutter_hooks` dependency.
 - **FIX**: update flutter_hooks dependency.
 - **BREAKING** **REFACTOR**: remove experimental changes from `springster` and add to new `motor` package instead (#117).

    * refactor!: remove legacy `Spring` widgets. Use `Motion` widgets instead
    
    * refactor!: renamed package to `motor`
    
    * chore: version
    
    * chore: add back springster at last released version
    
    * chore: add back legacy springster
    
    * rename `Spring` to `SpringMotion`
    
    * refactor!: renamed `Spring` to `SpringMotion`
    
    * more stuff
    
    * feat!: add `VelocityMotionBuilder`
    
    * feat: add `VelocityMotionBuilder`, which also passes the current velocity to the builder
    
    * add velocity stuff to example
    
    * linter love
    
    * docs: mention motor upgrade in springster readme
    
    * return springster version

 - **BREAKING** **FIX**: removed `useOnListenableChange` hook since it is now part of `flutter_hooks`.
 - **BREAKING** **FEAT**: migrate to Flutter SDK SpringDescription and add comprehensive migration guide.

    - Rename Spring to CupertinoMotion with predefined motion constants (smooth, bouncy, snappy, interactive)
    - Replace SpringMotion with Spring class that wraps SpringDescription
    - Deprecate SimpleSpring (formerly DurationSpring) with detailed migration documentation
    - Add comprehensive migration guide documenting mathematical differences for negative bounce values
    - Update all examples and tests to use new CupertinoMotion API
    - Add SpringDescriptionExtension with copyWith methods for convenience
    - Document behavioral differences between SimpleSpring and Flutter SDK's SpringDescription.withDurationAndBounce
    - Add extensive test coverage validating migration behavior differences
    - Update deprecation messages to reference migration guide for negative bounce values
    - Add README warning about overdamped spring behavior differences during migration
    
    
    - SpringMotion replaced with Spring wrapper around SpringDescription
    - SimpleSpring deprecated in favor of Flutter SDK's SpringDescription.withDurationAndBounce
    - Negative bounce values behave differently between SimpleSpring and Flutter SDK due to different damping formulas
    - Default motion parameters changed to use Flutter SDK's SpringDescription.withDurationAndBounce


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
