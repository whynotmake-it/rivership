import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A short label that appears next to [child]: an inverted bubble that
/// names an icon-only control.
///
/// A mouse opens it after a short hover, keyboard focus at once, and an
/// Android long-press while the finger stays down; iOS shows none. See
/// [CoilTooltipAnchor] for the timing. [message] is also what screen readers
/// announce. Don't put required information in a tooltip, and don't tooltip
/// a labelled button.
class CoilTooltip extends StatelessWidget {
  /// Creates a tooltip for [child].
  const CoilTooltip({
    required this.message,
    required this.child,
    super.key,
    this.motion,
  });

  /// The label.
  final String message;

  /// What the tooltip is for.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) => CoilTooltipAnchor(
    message: message,
    motion: motion,
    bubble: (context, presence) =>
        _Bubble(presence: presence, message: message, motion: motion),
    child: child,
  );
}

/// Gives the [CoilTooltip]s in [child] one shared bubble, for a toolbar
/// of icon buttons: moving along it, the bubble glides to the next button
/// on the theme's `quick` spring, its width follows, and its label
/// crossfades.
class CoilTooltipGroup extends StatelessWidget {
  /// Creates a tooltip group around [child].
  const CoilTooltipGroup({required this.child, super.key, this.motion});

  /// The area holding the tooltips.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) => CoilTooltipAnchorGroup(
    motion: motion,
    bubble: (context, presence, message) =>
        _Bubble(presence: presence, message: message, motion: motion),
    child: child,
  );
}

/// The inverted bubble: foreground fill, caption text in the background
/// color.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.presence,
    required this.message,
    required this.motion,
  });

  final Animation<double> presence;
  final String message;
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, tier: CoilTier.pointer);
    final motion = CoilTheme.motionOf(context, override: this.motion);
    return CoilBlurFade(
      presence: presence,
      scale: 1,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: theme.colors.foreground,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              CoilTheme.radiiOf(context).item,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // In a group the message changes in place: the width follows the
          // new label on `quick` at once while the labels crossfade on
          // `fade`. The old label keeps its lines as it fades.
          child: MotionSizeSwitcher(
            motion: motion.fade,
            exitMotion: motion.fadeExit,
            sizeMotion: motion.quick,
            immediateResize: true,
            child: Text(
              message,
              key: ValueKey(message),
              style: theme.typography.style(
                metrics.caption,
                color: theme.colors.background,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
