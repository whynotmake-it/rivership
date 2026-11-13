import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilCheckboxGroup` looks. Unset fields come from
/// [CoilCheckboxGroupStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected] and
/// [WidgetState.hovered] (a hovered or keyboard-focused row; touch rows
/// always resolve as selected, so they rest at full strength).
class CoilCheckboxGroupStyle
    extends CoilComponentStyle<CoilCheckboxGroupStyle> {
  /// Creates a style.
  const CoilCheckboxGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
  });

  /// The defaults from the theme's tokens.
  factory CoilCheckboxGroupStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilCheckboxGroupStyle(
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
    );
  }

  /// The merged block behind selected items.
  final Color? selection;

  /// The gliding hover highlight.
  final Color? highlight;

  /// The label color.
  final WidgetStateProperty<Color?>? label;

  /// The label style (color from [label]).
  final TextStyle? textStyle;

  /// The corner radius of blocks and the highlight.
  final double? radius;

  @override
  CoilCheckboxGroupStyle merge(CoilCheckboxGroupStyle? other) => other == null
      ? this
      : CoilCheckboxGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [selection, highlight, label, textStyle, radius];
}
