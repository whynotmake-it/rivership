import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilTabs` looks. Unset fields come from
/// [CoilTabsStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected] and
/// [WidgetState.hovered].
class CoilTabsStyle extends CoilComponentStyle<CoilTabsStyle> {
  /// Creates a style.
  const CoilTabsStyle({
    this.pill,
    this.hoverPillOpacity,
    this.label,
    this.textStyle,
    this.radius,
    this.minHeight,
  });

  /// The defaults from the theme's tokens.
  factory CoilTabsStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    return CoilTabsStyle(
      pill: c.active,
      hoverPillOpacity: 0.4,
      label: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? c.foreground
            : c.mutedForeground,
      ),
      textStyle: theme.typography.style(metrics.body),
      radius: theme.shape.radii(metrics.tier).item,
      minHeight: metrics.controlHeight,
    );
  }

  /// The selected pill.
  final Color? pill;

  /// How strong the hover pill is, as a fraction of [pill].
  final double? hoverPillOpacity;

  /// The label and icon color.
  final WidgetStateProperty<Color?>? label;

  /// The label style (color from [label], weight animated).
  final TextStyle? textStyle;

  /// The pills' corner radius.
  final double? radius;

  /// The minimum tab height (tabs grow with text).
  final double? minHeight;

  @override
  CoilTabsStyle merge(CoilTabsStyle? other) => other == null
      ? this
      : CoilTabsStyle(
          pill: other.pill ?? pill,
          hoverPillOpacity: other.hoverPillOpacity ?? hoverPillOpacity,
          label: other.label ?? label,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          minHeight: other.minHeight ?? minHeight,
        );

  @override
  List<Object?> get props => [
    pill,
    hoverPillOpacity,
    label,
    textStyle,
    radius,
    minHeight,
  ];
}
