import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';

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
        _Bubble(presence: presence, message: message),
    child: child,
  );
}

/// The inverted bubble: foreground fill, caption text in the background
/// color.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.presence, required this.message});

  final Animation<double> presence;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, tier: CoilTier.pointer);
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
          child: Text(
            message,
            style: theme.typography.style(
              metrics.caption,
              color: theme.colors.background,
            ),
          ),
        ),
      ),
    );
  }
}
