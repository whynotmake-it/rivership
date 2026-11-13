import 'package:coil/foundation.dart';
import 'package:coil/src/components/badge/badge_style.dart';
import 'package:flutter/widgets.dart';

/// A short, non-interactive label for a status or category.
///
/// [child] is the label (ellipsized when it doesn't fit). The `dot` variant
/// adds a colored dot before it, which assistive technology skips. A badge
/// has no touch bump, no motion and no states: use a button for anything
/// tappable.
class CoilBadge extends StatelessWidget {
  /// Creates a badge.
  const CoilBadge({
    required this.child,
    super.key,
    this.variant = CoilBadgeVariant.solid,
    this.color = CoilBadgeColor.gray,
    this.size,
    this.style,
  });

  /// The label.
  final Widget child;

  /// How the badge is drawn.
  final CoilBadgeVariant variant;

  /// The hue.
  final CoilBadgeColor color;

  /// Pins the badge to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides for this badge's look, on top of the theme's
  /// [CoilBadgeStyle] and the defaults.
  final CoilBadgeStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final look = CoilBadgeStyle.fallback(
      theme,
      sizes,
      variant,
      color,
    ).merge(CoilTheme.styleOf<CoilBadgeStyle>(context)).merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final dotSize = scaler.scale(look.dotSize!);

    // Ghost leaves the color unset: the label takes the surrounding one
    // (the type styles don't inherit, so it is carried over explicitly).
    final label = DefaultTextStyle.merge(
      style: look.textStyle!.copyWith(
        color:
            look.textStyle!.color ?? DefaultTextStyle.of(context).style.color,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      child: child,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: look.gap!,
      children: [
        if (variant != CoilBadgeVariant.solid)
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: look.dotColor,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
              child: SizedBox.square(dimension: dotSize),
            ),
          ),
        Flexible(child: label),
      ],
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: look.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(look.radius!),
          side: look.border == null
              ? BorderSide.none
              : BorderSide(color: look.border!),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: look.minHeight!),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: look.paddingX!),
          child: Center(widthFactor: 1, heightFactor: 1, child: content),
        ),
      ),
    );
  }
}
