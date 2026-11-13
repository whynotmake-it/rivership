## 0.1.0-dev.0

 - **FEAT**: first release. Spring-driven versions of Flutter's implicit animation widgets, built on [Motor](../motor): every widget takes a `motion` instead of a `duration` and `curve`, and a retarget mid-flight keeps the velocity instead of restarting.
 - **FEAT**: `MotionOpacity`, `MotionAlign`, `MotionPositioned`, `MotionScale`, `MotionRotation` and `MotionSlide`, the Motor versions of `AnimatedOpacity`, `AnimatedAlign`, `AnimatedPositioned`, `AnimatedScale`, `AnimatedRotation` and `AnimatedSlide`.
 - **FEAT**: `MotionPadding` and `PaddingExtended`, moved here from `motor`. `MotionPadding` gains `onEnd` and `debugLabel`, and its `child` is optional, as in `AnimatedPadding`.
 - **FEAT**: `MotionContainer`, the Motor version of `AnimatedContainer`. Each property is its own track on one `TrackBuilder`, so changing one property never disturbs another in flight.
 - **FEAT**: per-track motions. `MotionContainer`, `MotionAlign` and `MotionPositioned` declare their tracks on `MotionContainerTrack`, `MotionAlignTrack` and `MotionPositionedTrack`, and take `motions: {.color: …}` to override `motion` for single tracks. The keys are typed per widget and the motions compare by value.
 - **FEAT**: `MotionSize`, the Motor version of `AnimatedSize`: a render object that springs its size toward its child's and keeps its velocity when the child's size changes mid-flight.
 - **FEAT**: `MotionSwitcher`, the Motor version of `AnimatedSwitcher`, with the same `transitionBuilder` and `layoutBuilder`. Every child's `Animation<double>` is a presence spring (`motion` in, `exitMotion` out), unclamped so springs can overshoot, and a child that comes back while leaving turns around from its current presence and velocity, keeping its state.
 - **FEAT**: `MotionSizeSwitcher`, a `MotionSwitcher` inside a `MotionSize`, the Motor version of rivership's `AnimatedSizeSwitcher`.
