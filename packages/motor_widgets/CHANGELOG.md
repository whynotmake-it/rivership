## 0.1.0-dev.0

 - **FEAT**: first release: spring-driven versions of Flutter's implicit animation widgets.
 - **FEAT**: `MotionOpacity`, `MotionAlign`, `MotionPositioned`, `MotionScale`, `MotionRotation` and `MotionSlide`, the Motor versions of `AnimatedOpacity`, `AnimatedAlign`, `AnimatedPositioned`, `AnimatedScale`, `AnimatedRotation` and `AnimatedSlide`.
 - **FEAT**: `MotionPadding` and `PaddingExtended`, moved here from `motor`. `MotionPadding` gains `onEnd` and `debugLabel`, takes any `EdgeInsetsGeometry`, and its `child` is optional, as in `AnimatedPadding`.
 - **FEAT**: `MotionContainer`, the Motor version of `AnimatedContainer`. Each property is its own track on one `TrackBuilder`, so changing one property never disturbs another in flight.
 - **FEAT**: per-track motions. `MotionContainer`, `MotionAlign` and `MotionPositioned` declare their tracks on `MotionContainerTrack`, `MotionAlignTrack` and `MotionPositionedTrack`, and take `motions: {.color: …}` to override `motion` for single tracks. The keys are typed per widget and the motions compare by value.
 - **FEAT**: `MotionSize`, the Motor version of `AnimatedSize`: a render object that springs its size toward its child's and keeps its velocity when the child's size changes mid-flight.
 - **FEAT**: `MotionSwitcher`: `AnimatedSwitcher` with a presence spring per child. A child that comes back while leaving turns around with its velocity and keeps its state.
 - **FEAT**: `MotionSizeSwitcher`, a `MotionSwitcher` inside a `MotionSize`, the Motor version of rivership's `AnimatedSizeSwitcher`. Unlike it, `motion` is required, `sizeMotion` sets the size's spring apart from the fade, and with `immediateResize` a leaving child keeps its layout instead of reflowing at the new size.
