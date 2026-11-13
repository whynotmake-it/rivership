import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilCheckbox` looks; unset fields come from
/// [CoilCheckboxStyle.fallback].
///
/// [border] is resolved with [WidgetState.hovered], [WidgetState.selected]
/// (checked or indeterminate) and [WidgetState.error] (`invalid`).
class CoilCheckboxStyle extends CoilComponentStyle<CoilCheckboxStyle> {
  /// Creates a checkbox style.
  const CoilCheckboxStyle({
    this.border,
    this.borderWidth,
    this.glyphColor,
    this.size,
    this.radius,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilCheckboxStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilCheckboxStyle(
      border: WidgetStateProperty.resolveWith((s) {
        final hovered = s.contains(WidgetState.hovered);
        if (hovered) return c.foreground.withValues(alpha: 0.4);
        if (s.contains(WidgetState.selected)) {
          return c.border.withValues(alpha: 0);
        }
        if (s.contains(WidgetState.error)) {
          return c.destructive.withValues(alpha: 0.5);
        }
        return c.border;
      }),
      borderWidth: 1.5,
      glyphColor: c.foreground,
      size: metrics.checkboxSize,
      radius: theme.shape == CoilShape.sharp ? 0 : metrics.checkboxRadius,
    );
  }

  /// The box outline color.
  final WidgetStateProperty<Color?>? border;

  /// The box outline width.
  final double? borderWidth;

  /// The tick and dash color.
  final Color? glyphColor;

  /// The box size before text scaling.
  final double? size;

  /// The box's corner radius before text scaling.
  final double? radius;

  @override
  CoilCheckboxStyle merge(CoilCheckboxStyle? other) => other == null
      ? this
      : CoilCheckboxStyle(
          border: other.border ?? border,
          borderWidth: other.borderWidth ?? borderWidth,
          glyphColor: other.glyphColor ?? glyphColor,
          size: other.size ?? size,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [border, borderWidth, glyphColor, size, radius];
}
