## 0.5.0-dev.4

> Note: This release has breaking changes.

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
