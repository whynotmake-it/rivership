## 0.1.0-dev.0

 - **FEAT**: first release. Spring-driven versions of Flutter's implicit animation widgets, built on [Motor](../motor): every widget takes a `motion` instead of a `duration` and `curve`, and a retarget mid-flight keeps the velocity instead of restarting.
 - **FEAT**: `MotionOpacity`, `MotionAlign`, `MotionPositioned`, `MotionScale`, `MotionRotation` and `MotionSlide`, the Motor versions of `AnimatedOpacity`, `AnimatedAlign`, `AnimatedPositioned`, `AnimatedScale`, `AnimatedRotation` and `AnimatedSlide`.
 - **FEAT**: `MotionPadding` and `PaddingExtended`, moved here from `motor`. `MotionPadding` gains `onEnd` and `debugLabel`, and its `child` is optional, as in `AnimatedPadding`.
 - **FEAT**: `MotionContainer`, the Motor version of `AnimatedContainer`. Each property is its own track on one `TrackBuilder`, so changing one property never disturbs another in flight.
 - **FEAT**: `MotionSize`, the Motor version of `AnimatedSize`: a render object that springs its size toward its child's and keeps its velocity when the child's size changes mid-flight.
 - **FEAT**: `MotionTransition`, an immutable value that maps a presence value to a widget, with `.fade`, `.scale`, `.slide`, `.translate`, `.blur` and `.blurFade` presets that compose with `+`.
 - **FEAT**: `MotionSwitcher`, the Motor version of `AnimatedSwitcher`. Every child has a presence spring (`motion` in, `exitMotion` out), and a child that comes back while leaving turns around from its current presence and velocity, keeping its state.
 - **FEAT**: `MotionSizeSwitcher`, a `MotionSwitcher` inside a `MotionSize`, the Motor version of rivership's `AnimatedSizeSwitcher`.
