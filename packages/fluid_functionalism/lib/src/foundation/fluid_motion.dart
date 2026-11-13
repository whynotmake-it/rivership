import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The motion tokens of Fluid Functionalism as Motor [Motion]s.
///
/// From `lib/springs.ts`: each tier is an ENTER spring (critically damped,
/// except [slow] which keeps a little bounce) with a matching EXIT tween one
/// tier quicker and without bounce, so a dismissal reads as crisp and final.
///
/// The bigger the thing that moves, the slower the tier. Never hand-write a
/// duration: reach for a tier.
abstract final class FluidMotion {
  /// Small, fast movements: the hover highlight, focus rings, label reveals.
  ///
  /// `spring.fast`: 0.08 s, bounce 0.
  static const fast = CupertinoMotion(duration: Duration(milliseconds: 80));

  /// Exit of [fast]: a 0.06 s tween.
  static const fastExit = CurvedMotion(
    Duration(milliseconds: 60),
    Curves.easeOut,
  );

  /// Short travel that must land exactly: the tabs' selected pill, the
  /// switch thumb, dropdowns, drawers.
  ///
  /// `spring.moderate`: 0.16 s, bounce 0.
  static const moderate = CupertinoMotion(
    duration: Duration(milliseconds: 160),
  );

  /// Exit of [moderate]: a 0.12 s tween.
  static const moderateExit = CurvedMotion(
    Duration(milliseconds: 120),
    Curves.easeOut,
  );

  /// The largest things that move (panels, sheets).
  ///
  /// `spring.slow`: 0.24 s, bounce 0.12.
  static const slow = CupertinoMotion(
    duration: Duration(milliseconds: 240),
    bounce: 0.12,
  );

  /// Exit of [slow]: a 0.16 s tween.
  static const slowExit = CurvedMotion(
    Duration(milliseconds: 160),
    Curves.easeOut,
  );

  /// Opacity fades that accompany the springs (`opacity: { duration: 0.08 }`).
  static const fade = CurvedMotion(Duration(milliseconds: 80), Curves.easeOut);

  /// Color and stroke-width state changes (`transition-colors duration-80`,
  /// Tailwind's default `cubic-bezier(0.4, 0, 0.2, 1)`).
  static const color = CurvedMotion(
    Duration(milliseconds: 80),
    Cubic(0.4, 0, 0.2, 1),
  );

  /// The button's press-collapse while pressing (80 ms).
  static const press = CurvedMotion(
    Duration(milliseconds: 80),
    Cubic(0.23, 1, 0.32, 1),
  );

  /// The button's press-collapse on release (180 ms).
  static const release = CurvedMotion(
    Duration(milliseconds: 180),
    Cubic(0.23, 1, 0.32, 1),
  );

  /// The checkbox glyph drawing itself in (0.08 s ease-out).
  static const drawIn = CurvedMotion(
    Duration(milliseconds: 80),
    Curves.easeOut,
  );

  /// The checkbox glyph retracting (0.04 s ease-in).
  static const drawOut = CurvedMotion(
    Duration(milliseconds: 40),
    Curves.easeIn,
  );

  /// Returns [motion], or [Motion.instant] when the platform asks for
  /// reduced motion.
  ///
  /// Per the motion guidelines, reduced motion keeps fades and drops travel:
  /// use this for positional motion only.
  static Motion travel(BuildContext context, Motion motion) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? const Motion.instant()
      : motion;
}
