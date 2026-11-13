import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The motion tokens of Fluid Functionalism, as runtime theme data.
///
/// Defaults come from `lib/springs.ts`: each tier is an ENTER spring
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
    this.fast = const CupertinoMotion(duration: Duration(milliseconds: 80)),
    this.fastExit = const CurvedMotion(
      Duration(milliseconds: 60),
      Curves.easeOut,
    ),
    this.moderate = const CupertinoMotion(
      duration: Duration(milliseconds: 160),
    ),
    this.moderateExit = const CurvedMotion(
      Duration(milliseconds: 120),
      Curves.easeOut,
    ),
    this.slow = const CupertinoMotion(
      duration: Duration(milliseconds: 240),
      bounce: 0.12,
    ),
    this.slowExit = const CurvedMotion(
      Duration(milliseconds: 160),
      Curves.easeOut,
    ),
    this.fade = const CurvedMotion(
      Duration(milliseconds: 80),
      Curves.easeOut,
    ),
    this.color = const CurvedMotion(
      Duration(milliseconds: 80),
      Cubic(0.4, 0, 0.2, 1),
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
  /// reveals, hover tints. `spring.fast`: 0.08 s, bounce 0.
  final Motion fast;

  /// Exit of [fast]: a 0.06 s tween.
  final Motion fastExit;

  /// Short travel that must land exactly: the tabs' selected pill, the
  /// switch thumb. `spring.moderate`: 0.16 s, bounce 0.
  final Motion moderate;

  /// Exit of [moderate]: a 0.12 s tween.
  final Motion moderateExit;

  /// The largest things that move (panels, sheets). `spring.slow`: 0.24 s,
  /// bounce 0.12.
  final Motion slow;

  /// Exit of [slow]: a 0.16 s tween.
  final Motion slowExit;

  /// Opacity fades that accompany the springs (`opacity: { duration: 0.08 }`).
  final Motion fade;

  /// Color state changes (`transition-colors duration-80`).
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
