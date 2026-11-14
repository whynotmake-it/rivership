// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
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

  /// Each child's blur-fade, from 0 (hidden) to 1 (shown). Default motion:
  /// `fade` in and `fadeExit` out; `gentle` and `gentleExit` for
  /// [CoilRevealPreset.landing]. An override applies both ways.
  static final presence = CoilRevealTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilReveal.presence',
  );
}

/// How a [CoilReveal]'s children arrive.
enum CoilRevealPreset {
  /// The app: each child blur-fades in on `fade`, one `stagger` apart
  /// (60 ms by default).
  product,

  /// [product], two thirds of a `stagger` apart (40 ms by default), for
  /// screens that should settle quietly.
  subtle,

  /// A page read once: each child also rises 12 px and grows from 0.94, on
  /// `gentle`, five thirds of a `stagger` apart (100 ms by default). Use it
  /// for the part of a landing page on screen at load.
  landing,
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

/// Blur-fades its children in one after another when they first build, so
/// a screen settles in instead of appearing at once.
///
/// Each child enters with coil's blur-fade (`CoilBlurFade`), a step apart
/// set by [preset], starting with the first. After [steps] the rest arrive
/// together, so a long list doesn't trickle in. A child added later arrives
/// on its own, at its place's delay. Rebuilds don't replay it, and nothing
/// moves on scroll.
///
/// Set [visible] to false to hide the children with the same stagger, in
/// the same order, on the exit motions; set it back to reveal them again.
/// A flip halfway through turns each child around from where it is. Hidden
/// children stay mounted, so their state survives, but they take no
/// pointer, focus or semantics.
///
/// Wrap a screen's main column for its panels, or a list for its rows
/// ([CoilRevealSteps.items]). Leave headers, sidebars and footers outside.
/// For data that loads later, put the content of a `CoilSkeletonSwitcher`
/// in a [CoilReveal] so its rows arrive in turn.
///
/// With reduced motion every child fades in at once, with no blur, rise or
/// scale.
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
    this.visible = true,
    this.builder,
    this.preset = CoilRevealPreset.product,
    this.steps = CoilRevealSteps.blocks,
    this.motion,
    this.motions,
  });

  /// The children, in the order they arrive.
  final List<Widget> children;

  /// Whether the children are shown. Built true, they reveal on first
  /// build; built false, they stay hidden until it turns true.
  final bool visible;

  /// Lays out the revealed children, such as in a `Wrap` or a `Row`. Null
  /// stacks them in a [Column] that stretches them across. The children
  /// arrive wrapped, so they can't be `Expanded` or `Flexible`.
  final Widget Function(BuildContext context, List<Widget> children)? builder;

  /// How the children arrive.
  final CoilRevealPreset preset;

  /// How many steps stagger before the rest arrive together.
  final CoilRevealSteps steps;

  /// Overrides the theme's motion tokens, including `stagger`.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilRevealTrack]s.
  final Map<CoilRevealTrack<Object>, Motion>? motions;

  /// The landing preset's rise.
  static const _landingRise = 12.0;

  /// The landing preset's starting scale.
  static const _landingScale = 0.94;

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context, override: motion);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final landing = preset == CoilRevealPreset.landing;
    // Landing rides `gentle`, which reduced motion makes instant; the fade
    // stays, so it falls back to `fade` there.
    final (enter, exit) = landing && !reduced
        ? (tokens.gentle, tokens.gentleExit)
        : (tokens.fade, tokens.fadeExit);
    Motion presence(Motion token) => CoilTheme.trackMotionOf(
      context,
      CoilRevealTrack.presence,
      instance: motions,
      token: token,
      spatial: false,
    );
    final step = switch (preset) {
      CoilRevealPreset.product => tokens.stagger,
      CoilRevealPreset.subtle => tokens.stagger * 2 ~/ 3,
      CoilRevealPreset.landing => tokens.stagger * 5 ~/ 3,
    };
    final revealed = [
      for (final (i, child) in children.indexed)
        _Arrival(
          key: child.key == null ? null : ValueKey(child.key),
          visible: visible,
          delay: step * math.min(i, steps.last),
          motion: presence(visible ? enter : exit),
          scale: landing ? _landingScale : 0.96,
          offset: landing ? const Offset(0, _landingRise) : Offset.zero,
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

/// One child blur-fading in or out after [delay].
class _Arrival extends StatelessWidget {
  const _Arrival({
    required this.visible,
    required this.delay,
    required this.motion,
    required this.scale,
    required this.offset,
    required this.child,
    super.key,
  });

  final bool visible;
  final Duration delay;
  final Motion motion;
  final double scale;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: TrackBuilder(
          debugLabel: 'CoilReveal.arrival',
          animations: [
            CoilRevealTrack.presence([
              .to(visible ? 1 : 0, motion: motion),
            ], delay: delay),
          ],
          builder: (context, value, child) => CoilBlurFade(
            presence: AlwaysStoppedAnimation(
              value(CoilRevealTrack.presence),
            ),
            scale: scale,
            offset: offset,
            child: child!,
          ),
          child: child,
        ),
      ),
    ),
  );
}
