import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/badge/badge_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilBadge], as Motor tracks.
///
/// Use them as keys of [CoilBadge.motions] or [CoilBadgeStyle.motions].
final class CoilBadgeTrack<T extends Object> extends Track<T> {
  CoilBadgeTrack._(super.converter, {required String super.debugLabel});

  /// The badge's width as its label changes (a count going 9 to 10).
  ///
  /// Default motion: [CoilMotion.standard]; the label cross-fades on
  /// [CoilMotion.fade] / [CoilMotion.fadeExit].
  static final size = CoilBadgeTrack<double>._(
    .single,
    debugLabel: 'CoilBadge.size',
  );
}

/// A short, non-interactive label for a status or category.
///
/// [child] is the label (ellipsized when it doesn't fit). The `dot` variant
/// adds a colored dot before it, which assistive technology skips. A badge
/// has no touch bump and no states: use a button for anything tappable.
///
/// When the label changes (a [Text] with another string, or a child with
/// another key) the label cross-fades and the badge springs to its new
/// width. A change of the room around it relayouts at once. The animated
/// part is [CoilBadgeTrack.size].
class CoilBadge extends StatelessWidget {
  /// Creates a badge.
  const CoilBadge({
    required this.child,
    super.key,
    this.variant = CoilBadgeVariant.solid,
    this.color = CoilBadgeColor.gray,
    this.shape = CoilBadgeShape.item,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The label.
  final Widget child;

  /// How the badge is drawn.
  final CoilBadgeVariant variant;

  /// The hue.
  final CoilBadgeColor color;

  /// The corners: the theme's item radius, or a [CoilBadgeShape.pill].
  final CoilBadgeShape shape;

  /// Pins the badge to one size step.
  ///
  /// Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this badge.
  final CoilMotion? motion;

  /// Per-track motions for this badge, keyed by [CoilBadgeTrack]s.
  ///
  /// They win over the style's [CoilBadgeStyle.motions] and [motion]'s tokens.
  final Map<CoilBadgeTrack<Object>, Motion>? motions;

  /// Overrides for this badge's look, on top of the theme's
  /// [CoilBadgeStyle] and the defaults.
  final CoilBadgeStyle? style;

  /// A radius past half of any badge's height, which a superellipse
  /// draws as a full pill.
  static const _pillRadius = 1000.0;

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
    final tokens = CoilTheme.motionOf(context, override: motion);
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
      child: CoilSizeSwitcher(
        alignment: AlignmentDirectional.centerStart,
        sizeMotion: CoilTheme.trackMotionOf(
          context,
          CoilBadgeTrack.size,
          instance: motions,
          styled: look.motions,
          token: tokens.standard,
        ),
        motion: motion,
        debugLabel: 'CoilBadge.label',
        child: child,
      ),
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
          borderRadius: BorderRadius.circular(switch (shape) {
            CoilBadgeShape.item => look.radius!,
            CoilBadgeShape.pill => _pillRadius,
          }),
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
