import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilRadioGroup` looks. Unset fields come from
/// [CoilRadioGroupStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected] and
/// [WidgetState.hovered] (a hovered or keyboard-focused row; touch rows
/// always resolve as selected, so they rest at full strength).
class CoilRadioGroupStyle extends CoilComponentStyle<CoilRadioGroupStyle> {
  /// Creates a style.
  const CoilRadioGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
    this.radioBorder,
    this.radioBorderHover,
    this.dot,
  });

  /// The defaults from the theme's tokens.
  factory CoilRadioGroupStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilRadioGroupStyle(
      selection: c.active,
      highlight: c.hover,
      label: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? c.foreground
            : c.mutedForeground,
      ),
      textStyle: theme.typography.style(metrics.body),
      radius: theme.shape.radii(metrics.tier).item,
      radioBorder: c.border,
      radioBorderHover: c.foreground.withValues(alpha: 0.4),
      dot: c.foreground,
    );
  }

  /// The fill behind the selected row.
  final Color? selection;

  /// The gliding hover highlight.
  final Color? highlight;

  /// The label color.
  final WidgetStateProperty<Color?>? label;

  /// The label style (color from [label]).
  final TextStyle? textStyle;

  /// The corner radius of the selected fill and the highlight.
  final double? radius;

  /// The circle's outline at rest (it clears when selected).
  final Color? radioBorder;

  /// The circle's outline while its row is hovered.
  final Color? radioBorderHover;

  /// The selected dot.
  final Color? dot;

  @override
  CoilRadioGroupStyle merge(CoilRadioGroupStyle? other) => other == null
      ? this
      : CoilRadioGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          radioBorder: other.radioBorder ?? radioBorder,
          radioBorderHover: other.radioBorderHover ?? radioBorderHover,
          dot: other.dot ?? dot,
        );

  @override
  List<Object?> get props => [
    selection,
    highlight,
    label,
    textStyle,
    radius,
    radioBorder,
    radioBorderHover,
    dot,
  ];
}
