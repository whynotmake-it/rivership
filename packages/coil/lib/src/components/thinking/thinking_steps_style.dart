import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilThinkingSteps` looks. Unset fields come from
/// [CoilThinkingStepsStyle.fallback], which derives them from the theme.
/// Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [triggerFill] is resolved with [WidgetState.hovered] and
/// [WidgetState.pressed]. [label] is resolved with [WidgetState.selected]
/// (expanded) and [WidgetState.hovered].
class CoilThinkingStepsStyle
    extends CoilComponentStyle<CoilThinkingStepsStyle> {
  /// Creates a style.
  const CoilThinkingStepsStyle({
    this.triggerFill,
    this.label,
    this.textStyle,
    this.titleStyle,
    this.detailStyle,
    this.glyphColor,
    this.sourceFill,
    this.sourceBorder,
    this.sourceTextStyle,
    this.radius,
  });

  /// The defaults from the theme's tokens. Pointer triggers rest at
  /// `mutedForeground`; touch triggers and [highContrast] ones rest at
  /// `foreground`.
  factory CoilThinkingStepsStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics, {
    bool highContrast = false,
  }) {
    final c = theme.colors;
    final type = theme.typography;
    final rest = metrics.tier == CoilTier.touch || highContrast
        ? c.foreground
        : c.mutedForeground;
    // Badges don't grow on touch (DESIGN.md §14.1 Badge).
    final badge = CoilMetrics.resolve(CoilTier.pointer, metrics.size);
    return CoilThinkingStepsStyle(
      triggerFill: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? c.active
            : s.contains(WidgetState.hovered)
            ? c.hover
            : c.hover.withValues(alpha: 0),
      ),
      label: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? c.foreground
            : rest,
      ),
      textStyle: type.style(metrics.body),
      titleStyle: type.style(metrics.body, color: c.foreground),
      detailStyle: type.style(metrics.caption, color: c.mutedForeground),
      glyphColor: c.mutedForeground,
      // High contrast pushes `accent` toward the text color, so badges
      // switch to a quiet fill with a visible outline there.
      sourceFill: highContrast ? c.muted : c.accent,
      sourceBorder: highContrast ? c.border : null,
      sourceTextStyle: type.style(badge.caption, color: c.foreground),
      radius: theme.shape.radii(metrics.tier).item,
    );
  }

  /// The trigger's fill: hover on pointer, press on touch.
  final WidgetStateProperty<Color?>? triggerFill;

  /// The trigger's label and chevron color.
  final WidgetStateProperty<Color?>? label;

  /// The trigger label's style. Its color comes from [label].
  final TextStyle? textStyle;

  /// A step's title.
  final TextStyle? titleStyle;

  /// A step's detail line.
  final TextStyle? detailStyle;

  /// A step's icon or dot.
  final Color? glyphColor;

  /// The fill of a source badge.
  final Color? sourceFill;

  /// The outline of a source badge, if any.
  final Color? sourceBorder;

  /// The text of a source badge.
  final TextStyle? sourceTextStyle;

  /// The corner radius of the trigger fill, source badges and images.
  final double? radius;

  @override
  CoilThinkingStepsStyle merge(CoilThinkingStepsStyle? other) => other == null
      ? this
      : CoilThinkingStepsStyle(
          triggerFill: other.triggerFill ?? triggerFill,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          detailStyle:
              detailStyle?.merge(other.detailStyle) ?? other.detailStyle,
          glyphColor: other.glyphColor ?? glyphColor,
          sourceFill: other.sourceFill ?? sourceFill,
          sourceBorder: other.sourceBorder ?? sourceBorder,
          sourceTextStyle:
              sourceTextStyle?.merge(other.sourceTextStyle) ??
              other.sourceTextStyle,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [
    triggerFill,
    label,
    textStyle,
    titleStyle,
    detailStyle,
    glyphColor,
    sourceFill,
    sourceBorder,
    sourceTextStyle,
    radius,
  ];
}
