import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilSelect` looks. Unset fields come from
/// [CoilSelectStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// Trigger colors are resolved with [WidgetState.hovered],
/// [WidgetState.pressed] and [WidgetState.selected] (open).
class CoilSelectStyle extends CoilComponentStyle<CoilSelectStyle> {
  /// Creates a style.
  const CoilSelectStyle({
    this.triggerFill,
    this.triggerBorder,
    this.indicator,
    this.textStyle,
    this.placeholder,
    this.radius,
    this.surface,
    this.selectedFill,
    this.highlight,
    this.rowLabel,
  });

  /// The defaults from the theme's tokens.
  factory CoilSelectStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    return CoilSelectStyle(
      triggerFill: WidgetStateProperty<Color?>.fromMap({
        WidgetState.pressed: c.active,
        WidgetState.selected: c.hover.withValues(alpha: 0),
        WidgetState.hovered: c.hover,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      triggerBorder: c.border,
      indicator: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected: c.mutedForeground,
        WidgetState.hovered: c.foreground,
        WidgetState.any: c.mutedForeground,
      }),
      textStyle: theme.typography.style(metrics.body, color: c.foreground),
      placeholder: c.mutedForeground,
      radius: theme.shape.radii(metrics.tier).item,
      selectedFill: c.active,
      highlight: c.hover,
      rowLabel: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected | WidgetState.hovered | WidgetState.focused:
            c.foreground,
        WidgetState.any: c.mutedForeground,
      }),
    );
  }

  /// The trigger's background.
  final WidgetStateProperty<Color?>? triggerFill;

  /// The trigger's hairline.
  final Color? triggerBorder;

  /// The chevron and leading icon color.
  final WidgetStateProperty<Color?>? indicator;

  /// The trigger and row text style.
  final TextStyle? textStyle;

  /// The placeholder color.
  final Color? placeholder;

  /// The trigger and row corner radius; popups add their inset.
  final double? radius;

  /// The popover's fill. Null follows the surface level the popover opens
  /// on.
  final Color? surface;

  /// The fill behind the picked row (and merged blocks).
  final Color? selectedFill;

  /// The gliding highlight behind the active row.
  final Color? highlight;

  /// Row label color, resolved with [WidgetState.selected] (picked),
  /// [WidgetState.hovered] (the active row) and [WidgetState.focused]
  /// (rows at full emphasis on touch).
  final WidgetStateProperty<Color?>? rowLabel;

  @override
  CoilSelectStyle merge(CoilSelectStyle? other) => other == null
      ? this
      : CoilSelectStyle(
          triggerFill: other.triggerFill ?? triggerFill,
          triggerBorder: other.triggerBorder ?? triggerBorder,
          indicator: other.indicator ?? indicator,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          placeholder: other.placeholder ?? placeholder,
          radius: other.radius ?? radius,
          surface: other.surface ?? surface,
          selectedFill: other.selectedFill ?? selectedFill,
          highlight: other.highlight ?? highlight,
          rowLabel: other.rowLabel ?? rowLabel,
        );

  @override
  List<Object?> get props => [
    triggerFill,
    triggerBorder,
    indicator,
    textStyle,
    placeholder,
    radius,
    surface,
    selectedFill,
    highlight,
    rowLabel,
  ];
}
