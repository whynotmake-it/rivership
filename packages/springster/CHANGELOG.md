## 0.4.0

> Note: This release has breaking changes.

 - **FEAT**: implement SpringSimulationControllerBase interface for spring controllers.
 - **DOCS**: add Bluesky badge to README files across packages.
 - **BREAKING** **REFACTOR**: unified `SpringSimulationController` interface to match `AnimationController` more closely.
 - **BREAKING** **FEAT**: `.stop()` will now settle the spring simulation instead of interrupting it by default (#60).

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
