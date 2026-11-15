import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilInput` looks, single-line or multi-line. Unset
/// fields come from [CoilInputStyle.fallback]. Set a style app-wide or for a
/// subtree with `CoilThemeData.withComponentStyle`, or per instance with
/// `style:`.
///
/// [fill] and [border] resolve [WidgetState.hovered], [WidgetState.focused]
/// and [WidgetState.error].
class CoilInputStyle extends CoilComponentStyle<CoilInputStyle> {
  /// Creates a style.
  const CoilInputStyle({
    this.fill,
    this.border,
    this.textStyle,
    this.placeholder,
    this.cursorColor,
    this.cursorWidth,
    this.selectionColor,
    this.radius,
    this.multilineRadius,
    this.minHeight,
  });

  /// The defaults from the theme's tokens.
  factory CoilInputStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final radii = theme.shape.radii(metrics.tier);
    return CoilInputStyle(
      fill: WidgetStateProperty<Color?>.fromMap({
        WidgetState.focused: c.hover.withValues(alpha: 0),
        WidgetState.hovered: c.hover,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      border: WidgetStateProperty<Color?>.fromMap({
        WidgetState.focused: c.foreground.withValues(alpha: 0.4),
        WidgetState.error: c.destructive.withValues(alpha: 0.5),
        WidgetState.any: c.border,
      }),
      textStyle: theme.typography.style(metrics.field, color: c.foreground),
      placeholder: c.mutedForeground,
      cursorColor: c.foreground,
      cursorWidth: 1,
      selectionColor: c.brand.withValues(alpha: 0.3),
      radius: radii.item,
      // A tall box at a pill radius would be a capsule.
      multilineRadius: math.min(
        radii.item,
        CoilShape.rounded.radii(metrics.tier).container,
      ),
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

  /// The caret color.
  final Color? cursorColor;

  /// The caret width.
  final double? cursorWidth;

  /// The text selection highlight.
  final Color? selectionColor;

  /// The corner radius of a single-line field.
  final double? radius;

  /// The corner radius of a multi-line field.
  final double? multilineRadius;

  /// The minimum height. The field grows with its text.
  final double? minHeight;

  @override
  CoilInputStyle merge(CoilInputStyle? other) => other == null
      ? this
      : CoilInputStyle(
          fill: other.fill ?? fill,
          border: other.border ?? border,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          placeholder: other.placeholder ?? placeholder,
          cursorColor: other.cursorColor ?? cursorColor,
          cursorWidth: other.cursorWidth ?? cursorWidth,
          selectionColor: other.selectionColor ?? selectionColor,
          radius: other.radius ?? radius,
          multilineRadius: other.multilineRadius ?? multilineRadius,
          minHeight: other.minHeight ?? minHeight,
        );

  @override
  List<Object?> get props => [
    fill,
    border,
    textStyle,
    placeholder,
    cursorColor,
    cursorWidth,
    selectionColor,
    radius,
    multilineRadius,
    minHeight,
  ];
}
