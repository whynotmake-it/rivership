import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilCheckboxGroup` looks. Unset fields come from
/// [CoilCheckboxGroupStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected], [WidgetState.hovered]
/// and [WidgetState.focused].
class CoilCheckboxGroupStyle
    extends CoilComponentStyle<CoilCheckboxGroupStyle> {
  /// Creates a style.
  const CoilCheckboxGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
    this.checkbox,
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
      // Touch rows rest at full strength: "the pointer is here" means nothing
      // to a finger.
      label: metrics.tier == CoilTier.touch
          ? WidgetStatePropertyAll<Color?>(c.foreground)
          : WidgetStateProperty<Color?>.fromMap({
              WidgetState.selected | WidgetState.hovered | WidgetState.focused:
                  c.foreground,
              WidgetState.any: c.mutedForeground,
            }),
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

  /// The look of each row's box.
  final CoilCheckboxStyle? checkbox;

  @override
  CoilCheckboxGroupStyle merge(CoilCheckboxGroupStyle? other) => other == null
      ? this
      : CoilCheckboxGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          checkbox: checkbox?.merge(other.checkbox) ?? other.checkbox,
        );

  @override
  List<Object?> get props => [
    selection,
    highlight,
    label,
    textStyle,
    radius,
    checkbox,
  ];
}
