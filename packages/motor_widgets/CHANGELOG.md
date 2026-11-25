## 0.1.0-dev.0

First preview of `motor_widgets`, built on [Motor](https://pub.dev/packages/motor) 2.0 pre-releases.

### Implicit animation widgets

- **FEAT**: Add spring-driven equivalents of Flutter's implicit animation widgets: `MotionOpacity`, `MotionAlign`, `MotionPositioned` (including `.fromRect`), `MotionScale`, `MotionRotation`, `MotionSlide`, `MotionContainer`, `MotionSize`, `MotionSwitcher`, and `MotionSizeSwitcher`.
- **FEAT**: Move `MotionPadding` and `PaddingExtended` here from `motor`. `MotionPadding` gains `onEnd` and `debugLabel`, accepts any `EdgeInsetsGeometry`, and makes `child` optional.
- **FEAT**: Add per-property `motions:` overrides for `MotionContainer`, `MotionAlign`, and `MotionPositioned` via typed track keys (`MotionContainerTrack`, `MotionAlignTrack`, `MotionPositionedTrack`).

### Layout transitions & drag-and-drop

- **FEAT**: Add `MotionLayoutGroup` and `MotionLayoutItem` to animate items smoothly to their new positions whenever a rebuild moves them (matched by `id`, including across containers in the same group).
- **FEAT**: Move and rebuild `MotionDraggable` here from `motor` — feedback now animates on every drop (accepted, rejected, or removed), hands off to destination `MotionLayoutItem`s via `handoff`, supports `start: .longPress`, `handleOnly` + `MotionDragHandle`, per-phase `transitions`, and `MotionDragDetails.morph`. Removes `onlyReturnWhenCanceled` and `feedbackMatchesConstraints`.
- **FEAT**: Add `MotionReorderable` (and `MotionReorderable.sliver`), `MotionReorderableItem`, and `MotionDropGap` for spring-animated reordering in lists, grids, wraps, and slivers, including async pending drops.
- **FEAT**: Add `MotionDragToScroll` for spring-eased edge auto-scrolling during drags.
