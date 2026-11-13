import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The motion tokens of Fluid Functionalism, as runtime theme data.
///
/// Defaults come from `lib/springs.ts`, converted exactly. motion.dev's
/// spring `duration` is the time to settle to 0.1%; Motor's
/// [CupertinoMotion] duration is the spring's period (2π/ω₀). The springs
/// below carry the exact stiffness and damping motion.dev's `findSpring`
/// computes for `{duration: 0.08 / 0.16 / 0.24, bounce: 0 / 0 / 0.12}`
/// (periods 54.439 / 108.877 / 176.360 ms; research/02-foundations.md
/// §7.2–7.3). They are written as [SpringDescription]s rather than
/// `CupertinoMotion(duration:)` because Flutter's
/// `SpringDescription.withDurationAndBounce` truncates the duration to
/// whole milliseconds, which would make `fast` 1.6% stiff. Exit tweens
/// without an explicit ease default to motion.dev's `easeInOut`.
///
/// Each tier is an ENTER spring
/// (critically damped, except [slow] which keeps a little bounce) with a
/// matching EXIT tween one tier quicker and without bounce, so a dismissal
/// reads as crisp and final. The bigger the thing that moves, the slower
/// the tier.
///
/// Set it on `FluidThemeData.motion` (app-wide or for a subtree) or pass
/// one to a component's `motion:` parameter. Components read it on every
/// animation, so a change applies to the next animation without recreating
/// anything. Read it with `FluidTheme.motionOf(context)`, which applies
/// reduced motion on top.
@immutable
class FluidMotionThemeData with Diagnosticable {
  /// Creates motion tokens. Every token defaults to the web's value.
  const FluidMotionThemeData({
    this.fast = const Motion.customSpring(
      SpringDescription(
        mass: 1,
        stiffness: 13321.238191737151,
        damping: 230.83533691128966,
      ),
    ),
    this.fastExit = const CurvedMotion(
      Duration(milliseconds: 60),
      Curves.easeInOut,
    ),
    this.moderate = const Motion.customSpring(
      SpringDescription(
        mass: 1,
        stiffness: 3330.309547934288,
        damping: 115.41766845564483,
      ),
    ),
    this.moderateExit = const CurvedMotion(
      Duration(milliseconds: 120),
      Curves.easeInOut,
    ),
    this.slow = const Motion.customSpring(
      SpringDescription(
        mass: 1,
        stiffness: 1269.281572731934,
        damping: 62.70348155959475,
      ),
    ),
    this.slowExit = const CurvedMotion(
      Duration(milliseconds: 160),
      Curves.easeInOut,
    ),
    this.fade = const CurvedMotion(
      Duration(milliseconds: 80),
      Curves.easeInOut,
    ),
    this.color = const CurvedMotion(
      Duration(milliseconds: 80),
      Curves.fastOutSlowIn,
    ),
    this.press = const CurvedMotion(
      Duration(milliseconds: 80),
      Cubic(0.23, 1, 0.32, 1),
    ),
    this.release = const CurvedMotion(
      Duration(milliseconds: 180),
      Cubic(0.23, 1, 0.32, 1),
    ),
    this.drawIn = const CurvedMotion(
      Duration(milliseconds: 80),
      Curves.easeOut,
    ),
    this.drawOut = const CurvedMotion(
      Duration(milliseconds: 40),
      Curves.easeIn,
    ),
  });

  /// Small, fast movements: the hover highlight, focus rings, label
  /// reveals, hover tints. `spring.fast` {0.08 s settle, bounce 0}: period
  /// 54.439 ms (k 13321.24, c 230.835).
  final Motion fast;

  /// Exit of [fast]: a 0.06 s `easeInOut` tween.
  final Motion fastExit;

  /// Short travel that must land exactly: the tabs' selected pill, the
  /// switch thumb, merge/split. `spring.moderate` {0.16 s, bounce 0}:
  /// period 108.877 ms (k 3330.31, c 115.418).
  final Motion moderate;

  /// Exit of [moderate]: a 0.12 s `easeInOut` tween.
  final Motion moderateExit;

  /// The largest things that move (panels, sheets). `spring.slow`
  /// {0.24 s, bounce 0.12}: period 176.360 ms (k 1269.28, c 62.703).
  final Motion slow;

  /// Exit of [slow]: a 0.16 s `easeInOut` tween.
  final Motion slowExit;

  /// Opacity fades that accompany the springs (`{duration: 0.08}`, which
  /// motion.dev eases `easeInOut`).
  final Motion fade;

  /// Color state changes (`transition-colors duration-80`, Tailwind's
  /// `cubic-bezier(.4,0,.2,1)` = [Curves.fastOutSlowIn]).
  final Motion color;

  /// The button's press-collapse while pressing.
  final Motion press;

  /// The button's press-collapse on release.
  final Motion release;

  /// The checkbox glyph drawing itself in.
  final Motion drawIn;

  /// The checkbox glyph retracting.
  final Motion drawOut;

  /// These tokens with every movement made instant and every fade, color
  /// and draw kept: per the motion guidelines, reduced motion is fewer and
  /// gentler, not none.
  FluidMotionThemeData reduced() => copyWith(
    fast: const Motion.instant(),
    moderate: const Motion.instant(),
    slow: const Motion.instant(),
    press: const Motion.instant(),
    release: const Motion.instant(),
  );

  /// Returns a copy with the given tokens replaced.
  FluidMotionThemeData copyWith({
    Motion? fast,
    Motion? fastExit,
    Motion? moderate,
    Motion? moderateExit,
    Motion? slow,
    Motion? slowExit,
    Motion? fade,
    Motion? color,
    Motion? press,
    Motion? release,
    Motion? drawIn,
    Motion? drawOut,
  }) => FluidMotionThemeData(
    fast: fast ?? this.fast,
    fastExit: fastExit ?? this.fastExit,
    moderate: moderate ?? this.moderate,
    moderateExit: moderateExit ?? this.moderateExit,
    slow: slow ?? this.slow,
    slowExit: slowExit ?? this.slowExit,
    fade: fade ?? this.fade,
    color: color ?? this.color,
    press: press ?? this.press,
    release: release ?? this.release,
    drawIn: drawIn ?? this.drawIn,
    drawOut: drawOut ?? this.drawOut,
  );

  /// Motions are not interpolable, so this switches at the midpoint, like
  /// other discrete theme values.
  static FluidMotionThemeData lerp(
    FluidMotionThemeData a,
    FluidMotionThemeData b,
    double t,
  ) => t < 0.5 ? a : b;

  List<Motion> get _all => [
    fast,
    fastExit,
    moderate,
    moderateExit,
    slow,
    slowExit,
    fade,
    color,
    press,
    release,
    drawIn,
    drawOut,
  ];

  @override
  bool operator ==(Object other) =>
      other is FluidMotionThemeData && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('fast', fast))
      ..add(DiagnosticsProperty('moderate', moderate))
      ..add(DiagnosticsProperty('slow', slow));
  }
}
