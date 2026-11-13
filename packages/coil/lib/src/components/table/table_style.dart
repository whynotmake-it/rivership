import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilTable` looks. Unset fields come from
/// [CoilTableStyle.fallback], derived from the theme's tokens. Set a style
/// app-wide or for a subtree with `CoilThemeData.withComponentStyle`, or per
/// instance with `style:`.
///
/// [cellLabel] is resolved with [WidgetState.hovered] (the row is lit),
/// [WidgetState.selected], and [WidgetState.focused] for full emphasis
/// (touch rows and high contrast rest at foreground). [headerLabel] and
/// [headerFill] are resolved with [WidgetState.hovered] and
/// [WidgetState.pressed].
class CoilTableStyle extends CoilComponentStyle<CoilTableStyle> {
  /// Creates a style.
  const CoilTableStyle({
    this.headerStyle,
    this.headerLabel,
    this.headerFill,
    this.cellStyle,
    this.cellLabel,
    this.rule,
    this.highlight,
    this.selection,
    this.pressedFill,
    this.radius,
    this.fadeExtent,
  });

  /// The defaults from the theme's tokens. Pointer rows rest muted and turn
  /// foreground when lit or selected; touch rows rest at foreground.
  factory CoilTableStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final touch = metrics.tier == CoilTier.touch;
    const tabular = [FontFeature.tabularFigures()];
    return CoilTableStyle(
      headerStyle: theme.typography
          .style(metrics.caption, weight: CoilWeight.semibold)
          .copyWith(fontFeatures: tabular),
      headerLabel: WidgetStateProperty.fromMap({
        WidgetState.hovered | WidgetState.pressed: c.foreground,
        WidgetState.any: touch ? c.foreground : c.mutedForeground,
      }),
      headerFill: WidgetStateProperty.fromMap({
        WidgetState.pressed: c.active,
        WidgetState.hovered: c.hover,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      cellStyle: theme.typography
          .style(metrics.body)
          .copyWith(fontFeatures: tabular),
      cellLabel: WidgetStateProperty.fromMap({
        WidgetState.hovered | WidgetState.selected | WidgetState.focused:
            c.foreground,
        WidgetState.any: c.mutedForeground,
      }),
      rule: c.border,
      highlight: c.hover,
      selection: c.active,
      pressedFill: c.active,
      radius: theme.shape.radii(metrics.tier).item,
      fadeExtent: 24,
    );
  }

  /// The header text style (color from [headerLabel]).
  final TextStyle? headerStyle;

  /// The header label color.
  final WidgetStateProperty<Color?>? headerLabel;

  /// The fill behind a sortable header cell.
  final WidgetStateProperty<Color?>? headerFill;

  /// The body text style (color from [cellLabel]).
  final TextStyle? cellStyle;

  /// The body label color.
  final WidgetStateProperty<Color?>? cellLabel;

  /// The hairline under each row.
  final Color? rule;

  /// The row highlight that glides under a hovering pointer.
  final Color? highlight;

  /// The merged block behind selected rows.
  final Color? selection;

  /// The fill under a finger pressing a row.
  final Color? pressedFill;

  /// The corner radius of the highlight, selection and fills.
  final double? radius;

  /// How far the edge fades reach when the table scrolls sideways.
  final double? fadeExtent;

  @override
  CoilTableStyle merge(CoilTableStyle? other) => other == null
      ? this
      : CoilTableStyle(
          headerStyle:
              headerStyle?.merge(other.headerStyle) ?? other.headerStyle,
          headerLabel: other.headerLabel ?? headerLabel,
          headerFill: other.headerFill ?? headerFill,
          cellStyle: cellStyle?.merge(other.cellStyle) ?? other.cellStyle,
          cellLabel: other.cellLabel ?? cellLabel,
          rule: other.rule ?? rule,
          highlight: other.highlight ?? highlight,
          selection: other.selection ?? selection,
          pressedFill: other.pressedFill ?? pressedFill,
          radius: other.radius ?? radius,
          fadeExtent: other.fadeExtent ?? fadeExtent,
        );

  @override
  List<Object?> get props => [
    headerStyle,
    headerLabel,
    headerFill,
    cellStyle,
    cellLabel,
    rule,
    highlight,
    selection,
    pressedFill,
    radius,
    fadeExtent,
  ];
}
