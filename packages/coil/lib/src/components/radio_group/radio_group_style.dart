import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilRadioGroup` looks. Unset fields come from
/// [CoilRadioGroupStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected], [WidgetState.hovered]
/// and [WidgetState.focused]. [border] is resolved with
/// [WidgetState.hovered] and [WidgetState.selected].
class CoilRadioGroupStyle extends CoilComponentStyle<CoilRadioGroupStyle> {
  /// Creates a style.
  const CoilRadioGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
    this.border,
    this.borderWidth,
    this.size,
    this.dot,
    this.dotRatio,
    this.dotScale,
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
      border: WidgetStateProperty<Color?>.fromMap({
        WidgetState.hovered: c.foreground.withValues(alpha: 0.4),
        WidgetState.selected: c.border.withValues(alpha: 0),
        WidgetState.any: c.border,
      }),
      borderWidth: 1.5,
      size: metrics.checkboxSize,
      dot: c.foreground,
      dotRatio: 0.5,
      dotScale: 0.3,
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

  /// The circle's outline color.
  final WidgetStateProperty<Color?>? border;

  /// The circle's outline width.
  final double? borderWidth;

  /// The circle's diameter before text scaling.
  final double? size;

  /// The selected dot's color.
  final Color? dot;

  /// The dot's diameter as a fraction of the circle's.
  final double? dotRatio;

  /// The scale the dot grows from when it appears.
  final double? dotScale;

  @override
  CoilRadioGroupStyle merge(CoilRadioGroupStyle? other) => other == null
      ? this
      : CoilRadioGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          border: other.border ?? border,
          borderWidth: other.borderWidth ?? borderWidth,
          size: other.size ?? size,
          dot: other.dot ?? dot,
          dotRatio: other.dotRatio ?? dotRatio,
          dotScale: other.dotScale ?? dotScale,
        );

  @override
  List<Object?> get props => [
    selection,
    highlight,
    label,
    textStyle,
    radius,
    border,
    borderWidth,
    size,
    dot,
    dotRatio,
    dotScale,
  ];
}
