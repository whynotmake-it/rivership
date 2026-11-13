import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilBreadcrumb` and its "…" menu look. Unset fields
/// come from [CoilBreadcrumbStyle.fallback], which derives them from the
/// theme's tokens.
///
/// [label] resolves with [WidgetState.hovered] (lit by a hovering pointer,
/// keyboard focus or a press), [WidgetState.selected] (the current page)
/// and [WidgetState.disabled].
class CoilBreadcrumbStyle extends CoilComponentStyle<CoilBreadcrumbStyle> {
  /// Creates a breadcrumb style.
  const CoilBreadcrumbStyle({
    this.label,
    this.separatorColor,
    this.separatorSize,
    this.highlight,
    this.pressFill,
    this.surface,
    this.radius,
    this.textStyle,
    this.minHeight,
    this.paddingX,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilBreadcrumbStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilBreadcrumbStyle(
      label: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? c.foreground
            : c.mutedForeground,
      ),
      separatorColor: c.mutedForeground,
      separatorSize: 14,
      highlight: c.hover,
      pressFill: c.active,
      surface: c.surface(3),
      radius: theme.shape.radii(metrics.tier).item,
      textStyle: theme.typography.style(metrics.body),
      minHeight: metrics.controlHeight,
      paddingX: 6,
    );
  }

  /// The crumb label and icon color, by state.
  final WidgetStateProperty<Color?>? label;

  /// The separator's color.
  final Color? separatorColor;

  /// The separator's size, before text scaling.
  final double? separatorSize;

  /// The hover highlight that glides across crumbs and menu rows.
  final Color? highlight;

  /// The fill under a crumb or menu row while a finger presses it.
  final Color? pressFill;

  /// The "…" popover's surface.
  final Color? surface;

  /// The corner radius of crumbs, rows and their fills.
  final double? radius;

  /// The crumb text style (its color comes from [label]).
  final TextStyle? textStyle;

  /// The minimum crumb height. Crumbs grow with the text.
  final double? minHeight;

  /// The horizontal padding inside a crumb.
  final double? paddingX;

  @override
  CoilBreadcrumbStyle merge(CoilBreadcrumbStyle? other) => other == null
      ? this
      : CoilBreadcrumbStyle(
          label: other.label ?? label,
          separatorColor: other.separatorColor ?? separatorColor,
          separatorSize: other.separatorSize ?? separatorSize,
          highlight: other.highlight ?? highlight,
          pressFill: other.pressFill ?? pressFill,
          surface: other.surface ?? surface,
          radius: other.radius ?? radius,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          minHeight: other.minHeight ?? minHeight,
          paddingX: other.paddingX ?? paddingX,
        );

  @override
  List<Object?> get props => [
    label,
    separatorColor,
    separatorSize,
    highlight,
    pressFill,
    surface,
    radius,
    textStyle,
    minHeight,
    paddingX,
  ];
}
