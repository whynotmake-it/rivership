import 'package:flutter/foundation.dart';
import 'package:motor/motor.dart';

/// coil's motion tokens: Motor springs, plus two durations
/// ([minPressDuration], [acknowledgeDuration]) that time interactions
/// rather than animate them. All are runtime theme data.
///
/// Every token is a spring, exits included. An exit is a tighter spring
/// (shorter, never bouncy) rather than a curve, so a transition reversed
/// half-way keeps its velocity instead of restarting.
///
/// | Token | Default | Moves |
/// |---|---|---|
/// | [quick] | 100 ms, no bounce | the hover highlight, press collapse |
/// | [standard] | 180 ms, no bounce | tab pill, switch thumb, merge/split, popovers |
/// | [gentle] | 340 ms, bounce 0.1 | sheets, dialogs, panels |
/// | [fade] | 120 ms, no bounce | opacity and color |
///
/// Durations are [CupertinoMotion] durations: the perceptual length of the
/// spring, after which it has ended (about 99% of the way); it settles a
/// little later.
///
/// Set them on `CoilThemeData.motion` (app-wide or for a subtree) or pass a
/// copy to a component's `motion:` parameter. Components read them with
/// `CoilTheme.motionOf(context)` on every animation, which applies
/// [reduced] when the platform asks for reduced motion, so a change takes
/// effect on the next animation without recreating anything.
@immutable
class CoilMotion with Diagnosticable {
  /// Creates motion tokens; unset tokens keep coil's defaults.
  const CoilMotion({
    this.quick = const CupertinoMotion(duration: Duration(milliseconds: 100)),
    this.quickExit = const CupertinoMotion(
      duration: Duration(milliseconds: 80),
    ),
    this.standard = const CupertinoMotion(
      duration: Duration(milliseconds: 180),
    ),
    this.standardExit = const CupertinoMotion(
      duration: Duration(milliseconds: 140),
    ),
    this.gentle = const CupertinoMotion(
      duration: Duration(milliseconds: 340),
      bounce: 0.1,
    ),
    this.gentleExit = const CupertinoMotion(
      duration: Duration(milliseconds: 260),
    ),
    this.fade = const CupertinoMotion(duration: Duration(milliseconds: 120)),
    this.fadeExit = const CupertinoMotion(
      duration: Duration(milliseconds: 90),
    ),
    this.minPressDuration = const Duration(milliseconds: 90),
    this.acknowledgeDuration = const Duration(milliseconds: 300),
  });

  /// Small travel that should feel immediate: the hover highlight gliding
  /// between rows, a button's press collapse, a thumb squishing.
  final Motion quick;

  /// The exit of [quick]: a highlight leaving, a press releasing.
  final Motion quickExit;

  /// Indicators that must land exactly: the tab pill, the switch thumb,
  /// merge/split selection, popovers opening.
  final Motion standard;

  /// The exit of [standard]: a popover closing, an indicator leaving.
  final Motion standardExit;

  /// Large surfaces: sheets, dialogs, side panels. The only token with a
  /// little bounce, so big things feel physical.
  final Motion gentle;

  /// The exit of [gentle]: a sheet or dialog dismissing.
  final Motion gentleExit;

  /// Opacity and color: tints, focus rings, label colors, a check drawing
  /// in. Kept under reduced motion.
  final Motion fade;

  /// The exit of [fade]: a tint, ring or check going away.
  final Motion fadeExit;

  /// How long a press stays visible after a quick tap, so a tap that lifts
  /// within a frame still shows feedback (iOS cells do the same).
  final Duration minPressDuration;

  /// How long a pick in a closing list stays on screen, so the check can
  /// draw and the selection can land before the list closes.
  final Duration acknowledgeDuration;

  /// These tokens for reduced motion: every spatial token instant, [fade]
  /// and [fadeExit] kept. Reduced motion is fewer and gentler movements,
  /// not none.
  CoilMotion reduced() => copyWith(
    quick: const Motion.instant(),
    quickExit: const Motion.instant(),
    standard: const Motion.instant(),
    standardExit: const Motion.instant(),
    gentle: const Motion.instant(),
    gentleExit: const Motion.instant(),
  );

  /// Returns a copy with the given tokens replaced.
  CoilMotion copyWith({
    Motion? quick,
    Motion? quickExit,
    Motion? standard,
    Motion? standardExit,
    Motion? gentle,
    Motion? gentleExit,
    Motion? fade,
    Motion? fadeExit,
    Duration? minPressDuration,
    Duration? acknowledgeDuration,
  }) => CoilMotion(
    quick: quick ?? this.quick,
    quickExit: quickExit ?? this.quickExit,
    standard: standard ?? this.standard,
    standardExit: standardExit ?? this.standardExit,
    gentle: gentle ?? this.gentle,
    gentleExit: gentleExit ?? this.gentleExit,
    fade: fade ?? this.fade,
    fadeExit: fadeExit ?? this.fadeExit,
    minPressDuration: minPressDuration ?? this.minPressDuration,
    acknowledgeDuration: acknowledgeDuration ?? this.acknowledgeDuration,
  );

  /// Motions don't interpolate, so this switches at the midpoint, like other
  /// discrete theme values.
  static CoilMotion lerp(CoilMotion a, CoilMotion b, double t) =>
      t < 0.5 ? a : b;

  List<Object> get _all => [
    quick,
    quickExit,
    standard,
    standardExit,
    gentle,
    gentleExit,
    fade,
    fadeExit,
    minPressDuration,
    acknowledgeDuration,
  ];

  @override
  bool operator ==(Object other) =>
      other is CoilMotion && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('quick', quick))
      ..add(DiagnosticsProperty('standard', standard))
      ..add(DiagnosticsProperty('gentle', gentle))
      ..add(DiagnosticsProperty('fade', fade));
  }
}
