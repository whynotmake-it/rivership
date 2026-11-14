// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilReveal]. Use them as keys of
/// [CoilReveal.motions] or [CoilThemeData.trackMotions].
final class CoilRevealTrack<T extends Object> extends Track<T> {
  CoilRevealTrack._(
    super.converter, {
    required String super.debugLabel,
    super.initial,
  });

  /// Each child fading in. Default motion: `fade`.
  static final opacity = CoilRevealTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilReveal.opacity',
  );
}

/// How far apart a [CoilReveal]'s children arrive.
enum CoilRevealPace {
  /// One `stagger` apart (60 ms by default).
  regular,

  /// Two thirds of a `stagger` apart (40 ms by default), for screens that
  /// should settle quietly.
  subtle,
}

/// How many steps a [CoilReveal] staggers before the rest arrive together.
enum CoilRevealSteps {
  /// The panels of a screen: the first three arrive one by one, and the
  /// rest with the fourth.
  blocks(3),

  /// The rows of a list: the first seven arrive one by one, and the rest
  /// with the eighth.
  items(7);

  const CoilRevealSteps(this.last);

  /// The step the remaining children share.
  final int last;
}

/// Fades its children in one after another when they first build, so a
/// screen settles in instead of appearing at once.
///
/// Each child fades in on `fade`, [pace] apart, starting with the first.
/// After [steps] the rest arrive together, so a long list doesn't trickle
/// in. A child added later fades in on its own, at its place's delay.
/// Nothing moves on scroll, and nothing plays again on rebuilds.
///
/// Wrap a screen's main column for its panels, or a list for its rows
/// ([CoilRevealSteps.items]). Leave headers, sidebars and footers outside.
///
/// With reduced motion every child fades in at once.
///
/// ```dart
/// CoilReveal(
///   children: [header, chart, table],
/// )
/// ```
class CoilReveal extends StatelessWidget {
  /// Reveals [children], laid out by [builder] (a stretched [Column] when
  /// null).
  const CoilReveal({
    required this.children,
    super.key,
    this.builder,
    this.pace = CoilRevealPace.regular,
    this.steps = CoilRevealSteps.blocks,
    this.motion,
    this.motions,
  });

  /// The children, in the order they arrive.
  final List<Widget> children;

  /// Lays out the revealed children, such as in a `Wrap` or a `Row`. Null
  /// stacks them in a [Column] that stretches them across.
  final Widget Function(BuildContext context, List<Widget> children)? builder;

  /// How far apart the children arrive.
  final CoilRevealPace pace;

  /// How many steps stagger before the rest arrive together.
  final CoilRevealSteps steps;

  /// Overrides the theme's motion tokens, including `stagger`.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilRevealTrack]s.
  final Map<CoilRevealTrack<Object>, Motion>? motions;

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context, override: motion);
    final fade = CoilTheme.trackMotionOf(
      context,
      CoilRevealTrack.opacity,
      instance: motions,
      token: tokens.fade,
      spatial: false,
    );
    final step = switch (pace) {
      CoilRevealPace.regular => tokens.stagger,
      CoilRevealPace.subtle => tokens.stagger * 2 ~/ 3,
    };
    final revealed = [
      for (final (i, child) in children.indexed)
        _Arrival(
          key: child.key == null ? null : ValueKey(child.key),
          delay: step * math.min(i, steps.last),
          motion: fade,
          child: child,
        ),
    ];
    return MotorInspectionScope(
      group: 'CoilReveal',
      child:
          builder?.call(context, revealed) ??
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: revealed,
          ),
    );
  }
}

/// One child fading in after [delay].
class _Arrival extends StatelessWidget {
  const _Arrival({
    required this.delay,
    required this.motion,
    required this.child,
    super.key,
  });

  final Duration delay;
  final Motion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) => TrackBuilder(
    debugLabel: 'CoilReveal.arrival',
    animations: [
      CoilRevealTrack.opacity([.to(1, motion: motion)], delay: delay),
    ],
    builder: (context, value, child) => Opacity(
      opacity: value(CoilRevealTrack.opacity).clamp(0, 1),
      child: child,
    ),
    child: child,
  );
}
