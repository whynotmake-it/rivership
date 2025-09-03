## 1.0.0-dev.10

 - Update a dependency to the latest release.

## 1.0.0-dev.9

 - Update a dependency to the latest release.

## 1.0.0-dev.8

 - **FEAT**: stupid simple sheet and drag detector (#154).

## 1.0.0-dev.7

 - Update a dependency to the latest release.

## 1.0.0-dev.6

 - **DOCS**: added back springster example.

## 1.0.0-dev.5

 - Update a dependency to the latest release.

## 1.0.0-dev.4

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


## 0.4.0+1

 - **FIX**: `SpringSimulationController` doesn't update values if `from:` and `to:` are the same.

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: rename `SimpleSpring` to `Spring`.
 - **BREAKING** **FEAT**: `Spring` now supports value equality.

## 0.3.0

> Note: This release has breaking changes.

 - **FEAT**: implement SpringSimulationControllerBase interface for spring controllers.
 - **DOCS**: add Bluesky badge to README files across packages.
 - **BREAKING** **REFACTOR**: unified `SpringSimulationController` interface to match `AnimationController` more closely.
 - **BREAKING** **FEAT**: `.stop()` will now settle the spring simulation instead of interrupting it by default (#60).

## 0.2.1

 - **FIX**: status listener on 2D controller.
 - **FEAT**: update README files with example links.
 - **FEAT**: added unified example to monorepo.
 - **FEAT**: add onAnimationStatusChanged callback to SpringBuilder and SpringBuilder2D.
 - **DOCS**: fixed example links.

## 0.2.0

> Note: This release has breaking changes.

 - **FIX**: fixed missing updates when animating only the y dimension in 2D.
 - **FEAT**: add 'from' parameter to SpringBuilder and SpringBuilder2D for initial animation value.
 - **DOCS**: enhance documentation for SpringBuilder and SpringBuilder2D using templates.
 - **BREAKING** **FEAT**: removed `.smooth` constant in `SimpleSpring` since it is the default anyway.
 - **BREAKING** **FEAT**: removed `addBounce` in favor of `copyWith` methods on `SimpleSpring`.
 - **BREAKING** **FEAT**: renamed duration parameter in `SimpleSpring` to specify unit.

## 0.1.1+1

 - **FIX**: update README to reflect correct Pub version for Springster.

## 0.1.1

 - **FIX**: velocity calculation.
 - **FEAT**: polish in draggable.
 - **FEAT**: added `SpringDraggable`.
 - **FEAT**: add springster package.
 - **DOCS**: updated README.

## 0.1.0

- feat: initial commit 🎉
