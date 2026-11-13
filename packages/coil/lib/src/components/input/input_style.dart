import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilInput` looks. Unset fields come from
/// [CoilInputStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [fill] and [border] are resolved with [WidgetState.hovered],
/// [WidgetState.focused] and [WidgetState.error] (`invalid`).
class CoilInputStyle extends CoilComponentStyle<CoilInputStyle> {
  /// Creates a style.
  const CoilInputStyle({
    this.fill,
    this.border,
    this.textStyle,
    this.placeholder,
    this.radius,
    this.minHeight,
  });

  /// The defaults from the theme's tokens.
  factory CoilInputStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    return CoilInputStyle(
      fill: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.hovered) && !s.contains(WidgetState.focused)
            ? c.hover
            : c.hover.withValues(alpha: 0),
      ),
      border: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? c.foreground.withValues(alpha: 0.4)
            : s.contains(WidgetState.error)
            ? c.destructive.withValues(alpha: 0.5)
            : c.border,
      ),
      textStyle: theme.typography.style(metrics.field, color: c.foreground),
      placeholder: c.mutedForeground,
      radius: theme.shape.radii(metrics.tier).item,
      minHeight: metrics.controlHeight,
    );
  }

  /// The field's background.
  final WidgetStateProperty<Color?>? fill;

  /// The field's hairline.
  final WidgetStateProperty<Color?>? border;

  /// The text style.
  final TextStyle? textStyle;

  /// The placeholder and slot color.
  final Color? placeholder;

  /// The corner radius.
  final double? radius;

  /// The minimum height (the field grows with text).
  final double? minHeight;

  @override
  CoilInputStyle merge(CoilInputStyle? other) => other == null
      ? this
      : CoilInputStyle(
          fill: other.fill ?? fill,
          border: other.border ?? border,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          placeholder: other.placeholder ?? placeholder,
          radius: other.radius ?? radius,
          minHeight: other.minHeight ?? minHeight,
        );

  @override
  List<Object?> get props => [
    fill,
    border,
    textStyle,
    placeholder,
    radius,
    minHeight,
  ];
}
