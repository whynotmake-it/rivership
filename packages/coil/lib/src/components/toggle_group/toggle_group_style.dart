import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilToggleGroup` looks. Unset fields come from
/// [CoilToggleGroupStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected], [WidgetState.hovered]
/// and [WidgetState.focused].
class CoilToggleGroupStyle extends CoilComponentStyle<CoilToggleGroupStyle> {
  /// Creates a style.
  const CoilToggleGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
  });

  /// The defaults from the theme's tokens.
  factory CoilToggleGroupStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilToggleGroupStyle(
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

  @override
  CoilToggleGroupStyle merge(CoilToggleGroupStyle? other) => other == null
      ? this
      : CoilToggleGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [selection, highlight, label, textStyle, radius];
}
