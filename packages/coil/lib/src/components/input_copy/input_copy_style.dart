import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilInputCopy` looks. Unset fields come from
/// [CoilInputCopyStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with `CoilThemeData.withComponentStyle`,
/// or per instance with `style:`.
///
/// [fill] is resolved with [WidgetState.pressed]. [actionColor] is resolved
/// with [WidgetState.hovered] (a hovering pointer, or the copy result
/// showing) and [WidgetState.error] (the copy failed). [mark] is resolved
/// with [WidgetState.hovered].
class CoilInputCopyStyle extends CoilComponentStyle<CoilInputCopyStyle> {
  /// Creates a style.
  const CoilInputCopyStyle({
    this.valueStyle,
    this.labelStyle,
    this.actionStyle,
    this.actionColor,
    this.mark,
    this.fill,
    this.radius,
    this.minHeight,
  });

  /// The defaults from the theme's tokens.
  ///
  /// coil bundles no monospace font, so the value is Inter with tabular
  /// figures and a slashed zero; set [valueStyle] to use the app's mono
  /// font.
  factory CoilInputCopyStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    final t = theme.typography;
    final transparent = c.foreground.withValues(alpha: 0);
    final mark = c.brand.withValues(alpha: 0.2);
    return CoilInputCopyStyle(
      valueStyle: t
          .style(metrics.body, color: c.foreground)
          .copyWith(
            fontFeatures: const [
              FontFeature.tabularFigures(),
              FontFeature.slashedZero(),
            ],
          ),
      labelStyle: t.style(metrics.body, color: c.mutedForeground),
      actionStyle: t.style(metrics.body),
      actionColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.error)
            ? c.destructive
            : s.contains(WidgetState.hovered)
            ? c.foreground
            : c.mutedForeground,
      ),
      mark: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.hovered) ? mark : mark.withValues(alpha: 0),
      ),
      fill: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed) ? c.active : transparent,
      ),
      radius: theme.shape.radii(metrics.tier).item,
      minHeight: metrics.controlHeight,
    );
  }

  /// The copied value's text style.
  final TextStyle? valueStyle;

  /// The optional label above the row.
  final TextStyle? labelStyle;

  /// The action's "Copy" / "Copied" text style (its color comes from
  /// [actionColor]).
  final TextStyle? actionStyle;

  /// The action's icon and text color.
  final WidgetStateProperty<Color?>? actionColor;

  /// The highlight behind the value while a pointer hovers the row.
  final WidgetStateProperty<Color?>? mark;

  /// The row's fill.
  final WidgetStateProperty<Color?>? fill;

  /// The row's corner radius.
  final double? radius;

  /// The row's minimum height.
  final double? minHeight;

  @override
  CoilInputCopyStyle merge(CoilInputCopyStyle? other) => other == null
      ? this
      : CoilInputCopyStyle(
          valueStyle: valueStyle?.merge(other.valueStyle) ?? other.valueStyle,
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          actionStyle:
              actionStyle?.merge(other.actionStyle) ?? other.actionStyle,
          actionColor: other.actionColor ?? actionColor,
          mark: other.mark ?? mark,
          fill: other.fill ?? fill,
          radius: other.radius ?? radius,
          minHeight: other.minHeight ?? minHeight,
        );

  @override
  List<Object?> get props => [
    valueStyle,
    labelStyle,
    actionStyle,
    actionColor,
    mark,
    fill,
    radius,
    minHeight,
  ];
}
