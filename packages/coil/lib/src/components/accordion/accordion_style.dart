import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilAccordion` looks. Unset fields come from
/// [CoilAccordionStyle.fallback], which derives them from the theme. Set a
/// style app-wide or for a subtree with `CoilThemeData.withComponentStyle`,
/// or per instance with `style:`.
///
/// [triggerFill] is resolved with [WidgetState.hovered] and
/// [WidgetState.pressed]. [label] is resolved with [WidgetState.selected]
/// (the item is open) and [WidgetState.hovered] (the trigger is lit).
class CoilAccordionStyle extends CoilComponentStyle<CoilAccordionStyle> {
  /// Creates a style.
  const CoilAccordionStyle({
    this.triggerFill,
    this.highlight,
    this.openTint,
    this.label,
    this.textStyle,
    this.panelTextStyle,
    this.radius,
  });

  /// The defaults from the theme's tokens. Pointer triggers rest at
  /// `mutedForeground`; touch triggers and [highContrast] ones rest at
  /// `foreground`.
  factory CoilAccordionStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics, {
    bool highContrast = false,
  }) {
    final c = theme.colors;
    final rest = metrics.tier == CoilTier.touch || highContrast
        ? c.foreground
        : c.mutedForeground;
    return CoilAccordionStyle(
      triggerFill: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? c.active
            : s.contains(WidgetState.hovered)
            ? c.hover
            : c.hover.withValues(alpha: 0),
      ),
      highlight: c.hover,
      openTint: c.hover,
      label: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? c.foreground
            : rest,
      ),
      textStyle: theme.typography.style(metrics.body),
      panelTextStyle: theme.typography.style(
        metrics.body,
        color: c.mutedForeground,
      ),
      radius: theme.shape.radii(metrics.tier).item,
    );
  }

  /// The trigger's own fill: the hover fill of the plain variant, and the
  /// press fill on touch.
  final WidgetStateProperty<Color?>? triggerFill;

  /// The gliding hover highlight of the group variant.
  final Color? highlight;

  /// The tint behind open items in the group variant.
  final Color? openTint;

  /// The trigger's label, icon and chevron color.
  final WidgetStateProperty<Color?>? label;

  /// The trigger label's style. Its color comes from [label].
  final TextStyle? textStyle;

  /// The default text style of a panel.
  final TextStyle? panelTextStyle;

  /// The corner radius of fills, tints and the highlight.
  final double? radius;

  @override
  CoilAccordionStyle merge(CoilAccordionStyle? other) => other == null
      ? this
      : CoilAccordionStyle(
          triggerFill: other.triggerFill ?? triggerFill,
          highlight: other.highlight ?? highlight,
          openTint: other.openTint ?? openTint,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          panelTextStyle:
              panelTextStyle?.merge(other.panelTextStyle) ??
              other.panelTextStyle,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [
    triggerFill,
    highlight,
    openTint,
    label,
    textStyle,
    panelTextStyle,
    radius,
  ];
}
