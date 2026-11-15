import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilThinkingIndicator` looks. Unset fields come
/// from [CoilThinkingIndicatorStyle.fallback], which derives them from the
/// theme. Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
class CoilThinkingIndicatorStyle
    extends CoilComponentStyle<CoilThinkingIndicatorStyle> {
  /// Creates a style.
  const CoilThinkingIndicatorStyle({
    this.textStyle,
    this.glyphColor,
    this.glyphSize,
  });

  /// The defaults from the theme's tokens.
  factory CoilThinkingIndicatorStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilThinkingIndicatorStyle(
      textStyle: theme.typography.style(
        metrics.body,
        color: c.mutedForeground,
      ),
      glyphColor: c.mutedForeground,
      glyphSize: metrics.size == CoilSize.compact ? 18 : 20,
    );
  }

  /// The words' style.
  final TextStyle? textStyle;

  /// The glyph's color.
  final Color? glyphColor;

  /// The glyph's size before text scaling.
  final double? glyphSize;

  @override
  CoilThinkingIndicatorStyle merge(CoilThinkingIndicatorStyle? other) =>
      other == null
      ? this
      : CoilThinkingIndicatorStyle(
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          glyphColor: other.glyphColor ?? glyphColor,
          glyphSize: other.glyphSize ?? glyphSize,
        );

  @override
  List<Object?> get props => [textStyle, glyphColor, glyphSize];
}
