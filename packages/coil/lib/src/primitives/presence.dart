import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Drives a route's transition with Motor springs: its `animation` is a
/// presence value going 0 → 1 on [enterMotion] when pushed, and back to 0
/// on [exitMotion] when popped, starting from wherever it is with its
/// current velocity. So a popover closed mid-opening reverses smoothly, and
/// the route is removed when the exit spring settles.
///
/// Read the motions from `CoilTheme.motionOf` when creating the route.
mixin CoilSpringRoute<T> on TransitionRoute<T> {
  /// The spring that brings the route in.
  Motion get enterMotion;

  /// The tighter spring that takes it out.
  Motion get exitMotion;

  // Only checked to be non-negative: the simulations below drive the
  // transition.
  @override
  Duration get transitionDuration =>
      enterMotion.duration ?? const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration =>
      exitMotion.duration ?? const Duration(milliseconds: 300);

  @override
  Simulation createSimulation({required bool forward}) {
    final controller = this.controller!;
    return (forward ? enterMotion : exitMotion).createSimulation(
      start: controller.value,
      end: forward ? 1 : 0,
      velocity: controller.velocity,
    );
  }
}

/// coil's default enter and exit for overlays: [child] blurs, fades and
/// shrinks a little toward [alignment] as [presence] goes from 1 to 0.
///
/// [presence] is any 0→1 animation driven by a spring (a [CoilSpringRoute]'s
/// animation, a `MotionSwitcher` child's). Values past 1 from a bouncy
/// spring overshoot the scale and offset, and clamp the opacity and blur.
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
    final alignment = this.alignment.resolve(Directionality.maybeOf(context));
    return ListenableBuilder(
      listenable: presence,
      child: child,
      builder: (context, child) {
        final p = presence.value;
        final away = 1 - p;
        final sigma = (blur * away).clamp(0.0, blur);
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: offset * away,
            child: Transform.scale(
              scale: scale + (1 - scale) * p,
              alignment: alignment,
              child: ImageFiltered(
                enabled: sigma > 0.01,
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
