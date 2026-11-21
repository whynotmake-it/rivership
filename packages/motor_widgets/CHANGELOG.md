## 0.1.0-dev.0

First preview: spring-driven versions of Flutter's implicit animation widgets, plus drag and drop. Requires `motor` 2.0.

Implicit animations

 - `MotionOpacity`, `MotionScale`, `MotionRotation`, `MotionSlide`, `MotionAlign`, `MotionPositioned`, `MotionPadding`, `MotionContainer` and `MotionSize` replace the matching `Animated*` widgets. They take `motion` instead of `duration` and `curve`.
 - `MotionContainer`, `MotionAlign` and `MotionPositioned` animate each property on its own track, so changing one never disturbs another in flight. Override a single track with `motions: {.color: .snappySpring()}`.
 - `MotionSize` springs its size toward its child's and keeps its velocity when the child's size changes mid-flight.
 - `MotionSwitcher` replaces `AnimatedSwitcher`, and `MotionSizeSwitcher` replaces rivership's `AnimatedSizeSwitcher`. Each child has a presence spring, so a child whose key comes back while leaving turns around with its velocity and keeps its state. `MotionSizeSwitcher` requires `motion`, and `sizeMotion` sets the size spring apart from the fade.
 - `MotionPadding` and `PaddingExtended` moved here from `motor`. `MotionPadding` gains `onEnd` and `debugLabel`.

Layout and drag and drop

 - `MotionLayoutGroup` and `MotionLayoutItem` fly an item from where it was painted to its new place when a rebuild moves it. Items are matched by `id`, so lazy lists need no keys, and an item can fly into another container of the same group. Scrolling never makes an item fly.
 - `MotionDraggable` moved here from `motor` and was rebuilt. The feedback animates from pickup to landing. An accepted drop flies to the `MotionLayoutItem` with the same `id`, like a `Hero`. A rejected drop springs back, and a drop with nowhere to land plays an exit. Plain `DragTarget`s work unchanged.
   - `start: .longPress` replaces `MotionLongPressDraggable`, and `handleOnly` with `MotionDragHandle` starts the drag from a handle.
   - `transitions` animates `scale`, `rotation` and `opacity` per phase, and `MotionDragDetails.morph` lets the feedback turn into its destination.
   - `feedback` and `childWhenDragging` get the measured size. `onlyReturnWhenCanceled` and `feedbackMatchesConstraints` are removed, and `motion` defaults to `CupertinoMotion.smooth()`.
 - `MotionReorderable` handles drags over any list, grid, wrap or sliver (`MotionReorderable.sliver`) and tells its builder where a drop would land. The builder places a `MotionDropGap` or draws a line. `onMove` covers reorders, drops from other reorderables and screen-reader moves, and may return a `Future` to keep the drop pending.
 - `MotionDragToScroll` scrolls the nearest scroll view while a drag is near its edge, faster the closer it gets. It needs the `Draggable`'s data to be non-null.
