import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// coil's default enter and exit for overlays: [child] blurs, fades and
/// shrinks a little toward [alignment] as [presence] goes from 1 to 0.
///
/// [presence] is any 0→1 animation driven by a spring: a popover's
/// presence, a `MotionSwitcher` child's animation. A spring may overshoot
/// 0–1: opacity and blur are clamped, scale and offset use the raw value so a
/// bouncy spring visibly bounces.
///
/// As a `MotionSwitcher` transition:
///
/// ```dart
/// MotionSwitcher(
///   motion: motion.fade,
///   exitMotion: motion.fadeExit,
///   transitionBuilder: CoilBlurFade.transition(),
///   child: Text(value, key: ValueKey(value)),
/// )
/// ```
class CoilBlurFade extends StatelessWidget {
  /// Creates a blur-fade transition.
  const CoilBlurFade({
    required this.presence,
    required this.child,
    super.key,
    this.blur = 4,
    this.scale = 0.96,
    this.offset = Offset.zero,
    this.alignment = Alignment.center,
  });

  /// A transition builder with Flutter's `(child, animation)` signature,
  /// for `MotionSwitcher` and `AnimatedSwitcher`.
  static Widget Function(Widget child, Animation<double> animation) transition({
    double blur = 4,
    double scale = 0.96,
    Offset offset = Offset.zero,
    AlignmentGeometry alignment = Alignment.center,
  }) =>
      (child, animation) => CoilBlurFade(
        presence: animation,
        blur: blur,
        scale: scale,
        offset: offset,
        alignment: alignment,
        child: child,
      );

  /// 0 (gone) to 1 (fully present).
  final Animation<double> presence;

  /// The blur sigma at presence 0.
  final double blur;

  /// The scale at presence 0.
  final double scale;

  /// The translation at presence 0, in logical pixels.
  final Offset offset;

  /// The origin of the scale: the edge the overlay grows from.
  final AlignmentGeometry alignment;

  /// The overlay.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Reduced motion: overlays only fade.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final blur = reduce ? 0.0 : this.blur;
    final scale = reduce ? 1.0 : this.scale;
    final offset = reduce ? Offset.zero : this.offset;
    final alignment = this.alignment.resolve(Directionality.maybeOf(context));
    return ListenableBuilder(
      listenable: presence,
      child: child,
      builder: (context, child) {
        final p = presence.value;
        final away = 1 - p;
        final sigma = (blur * away).clamp(0.0, blur);
        // The scale and slide resample the child drawn at rest (a matrix
        // filter), so text moves as one image instead of re-rasterizing
        // each frame with every glyph snapped to the pixel grid. At rest
        // there's nothing to resample.
        final s = scale + (1 - scale) * p;
        final moving = s != 1 || (offset * away) != Offset.zero;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.translationValues(
              offset.dx * away,
              offset.dy * away,
              0,
            )..scaleByDouble(s, s, 1, 1),
            alignment: alignment,
            filterQuality: moving ? FilterQuality.medium : null,
            child: ImageFiltered(
              enabled: sigma > 0.01,
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
