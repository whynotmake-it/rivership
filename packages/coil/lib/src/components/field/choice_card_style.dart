import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilChoiceCard` looks. Unset fields come from
/// [CoilChoiceCardStyle.fallback]. Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [fill] is resolved with [WidgetState.hovered] and [WidgetState.pressed];
/// [border] with [WidgetState.selected].
class CoilChoiceCardStyle extends CoilComponentStyle<CoilChoiceCardStyle> {
  /// Creates a style.
  const CoilChoiceCardStyle({
    this.fill,
    this.border,
    this.radius,
    this.padding,
    this.gap,
    this.textGap,
    this.titleStyle,
    this.descriptionStyle,
  });

  /// The defaults from the theme's tokens: a hairline at the container
  /// radius, `foreground` 40 % when selected, the `hover` fill on hover and
  /// the `active` fill while a touch presses.
  factory CoilChoiceCardStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilChoiceCardStyle(
      fill: WidgetStateProperty.fromMap({
        WidgetState.pressed: c.active,
        WidgetState.hovered: c.hover,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      border: WidgetStateProperty.fromMap({
        WidgetState.selected: c.foreground.withValues(alpha: 0.4),
        WidgetState.any: c.border,
      }),
      radius: theme.shape.radii(metrics.tier).container,
      padding: metrics.controlPaddingX,
      gap: metrics.gap,
      textGap: 4,
      titleStyle: theme.typography.style(metrics.body, color: c.foreground),
      descriptionStyle: theme.typography.style(
        metrics.caption,
        color: c.mutedForeground,
      ),
    );
  }

  /// The card's fill.
  final WidgetStateProperty<Color?>? fill;

  /// The card's 1 px border color.
  final WidgetStateProperty<Color?>? border;

  /// The corner radius.
  final double? radius;

  /// The padding on every side.
  final double? padding;

  /// Control to text.
  final double? gap;

  /// Title to description.
  final double? textGap;

  /// The title's text style.
  final TextStyle? titleStyle;

  /// The description's text style.
  final TextStyle? descriptionStyle;

  @override
  CoilChoiceCardStyle merge(CoilChoiceCardStyle? other) => other == null
      ? this
      : CoilChoiceCardStyle(
          fill: other.fill ?? fill,
          border: other.border ?? border,
          radius: other.radius ?? radius,
          padding: other.padding ?? padding,
          gap: other.gap ?? gap,
          textGap: other.textGap ?? textGap,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
        );

  @override
  List<Object?> get props => [
    fill,
    border,
    radius,
    padding,
    gap,
    textGap,
    titleStyle,
    descriptionStyle,
  ];
}
