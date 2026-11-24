/// @docImport 'package:coil/src/components/reveal/reveal.dart';
/// @docImport 'package:coil/src/foundation/theme.dart';
/// @docImport 'package:fixed_ticker/fixed_ticker.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:motor/motor.dart';

/// Coil's motion tokens: Motor springs, plus durations ([minPressDuration],
/// [acknowledgeDuration], [stagger]) that time motion rather than animate it.
///
/// All tokens are runtime theme data. Every token is a spring, exits included.
/// An exit is a tighter spring (shorter, never bouncy) rather than a curve, so
/// a transition reversed half-way keeps its velocity instead of restarting.
///
/// | Token | Default | Moves |
/// |---|---|---|
/// | [quick] | 70 ms, no bounce | hover highlight, press, pointer popovers |
/// | [standard] | 120 ms, no bounce | tab pill, switch thumb, merge/split, touch popovers |
/// | [gentle] | 220 ms, no bounce | sheets, dialogs, panels |
/// | [fade] | 120 ms, no bounce | opacity and color |
/// | [stagger] | 60 ms, a delay | siblings arriving in turn ([CoilReveal]) |
///
/// Durations are [CupertinoMotion] durations: the perceptual length of the
/// spring, after which it has ended (about 99% of the way); it settles a
/// little later.
///
/// Set them on [CoilThemeData.motion] (app-wide or for a subtree) or pass a
/// copy to a component's `motion:` parameter. Components read them with
/// [CoilTheme.motionOf] on every animation, which applies [reduced] when the
/// platform asks for reduced motion, so a change takes effect on the next
/// animation without recreating anything.
///
/// Coil's springs tick every frame by default. Wrap Coil components in a
/// [TickerRateScope] to run all of Coil's motion at a fixed rate such as
/// [TickerRate.fps], which saves frame work on 120 Hz screens and for
/// low-priority motion. [reduced] motion still applies.
@immutable
class CoilMotion with Diagnosticable {
  /// Creates motion tokens; unset tokens keep Coil's defaults.
  const CoilMotion({
    this.quick = const CupertinoMotion(duration: Duration(milliseconds: 70)),
    this.quickExit = const CupertinoMotion(
      duration: Duration(milliseconds: 60),
    ),
    this.standard = const CupertinoMotion(
      duration: Duration(milliseconds: 120),
    ),
    this.standardExit = const CupertinoMotion(
      duration: Duration(milliseconds: 100),
    ),
    this.gentle = const CupertinoMotion(duration: Duration(milliseconds: 220)),
    this.gentleExit = const CupertinoMotion(
      duration: Duration(milliseconds: 180),
    ),
    this.fade = const CupertinoMotion(duration: Duration(milliseconds: 120)),
    this.fadeExit = const CupertinoMotion(
      duration: Duration(milliseconds: 90),
    ),
    this.minPressDuration = const Duration(milliseconds: 90),
    this.acknowledgeDuration = const Duration(milliseconds: 300),
    this.stagger = const Duration(milliseconds: 60),
  });

  /// Small travel that should feel immediate: the hover highlight gliding
  /// between rows, a button's press collapse, a thumb squishing, and a
  /// popover opening on the pointer tier.
  final Motion quick;

  /// The exit of [quick]: a highlight leaving, a press releasing, and a
  /// pointer popover closing.
  final Motion quickExit;

  /// Indicators that must land exactly: the tab pill, the switch thumb,
  /// merge/split selection, and popovers opening on the touch tier.
  final Motion standard;

  /// The exit of [standard]: a touch popover closing or an indicator leaving.
  final Motion standardExit;

  /// Large surfaces: sheets, dialogs, and side panels.
  final Motion gentle;

  /// The exit of [gentle]: a dialog or panel dismissing.
  ///
  /// Sheets use [gentle] both ways.
  final Motion gentleExit;

  /// Opacity and color: tints, focus rings, label colors, and a check drawing
  /// in.
  ///
  /// Kept under reduced motion.
  final Motion fade;

  /// The exit of [fade]: a tint, ring, or check going away.
  final Motion fadeExit;

  /// How long a press stays visible after a quick tap, so a tap that lifts
  /// within a frame still shows feedback (iOS cells do the same).
  final Duration minPressDuration;

  /// How long a pick in a closing list stays on screen, so the check can
  /// draw and the selection can land before the list closes.
  final Duration acknowledgeDuration;

  /// The delay between siblings that arrive one after another, such as the
  /// panels of a screen fading in on first build ([CoilReveal]).
  ///
  /// Zero under reduced motion, so they arrive together.
  final Duration stagger;

  /// Returns these tokens for reduced motion: every spatial token becomes
  /// instant, [stagger] becomes [Duration.zero], and [fade] and [fadeExit]
  /// are kept.
  ///
  /// Reduced motion means fewer and gentler movements, not none.
  CoilMotion reduced() => copyWith(
    quick: const Motion.instant(),
    quickExit: const Motion.instant(),
    standard: const Motion.instant(),
    standardExit: const Motion.instant(),
    gentle: const Motion.instant(),
    gentleExit: const Motion.instant(),
    stagger: Duration.zero,
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
    Duration? stagger,
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
    stagger: stagger ?? this.stagger,
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
    stagger,
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
