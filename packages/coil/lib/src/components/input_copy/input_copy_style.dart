import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilInputCopy` looks. Unset fields come from
/// [CoilInputCopyStyle.fallback]. Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [fill] resolves [WidgetState.pressed]. [actionColor] and [mark] resolve
/// [WidgetState.hovered].
class CoilInputCopyStyle extends CoilComponentStyle<CoilInputCopyStyle> {
  /// Creates a style.
  const CoilInputCopyStyle({
    this.valueStyle,
    this.actionStyle,
    this.actionColor,
    this.copiedColor,
    this.failedColor,
    this.mark,
    this.markRadius,
    this.fill,
    this.radius,
    this.minHeight,
    this.iconSize,
    this.actionGap,
  });

  /// The defaults from the theme's tokens.
  ///
  /// coil bundles no monospace font, so the value uses Inter with tabular
  /// figures and a slashed zero. Set [valueStyle] to use your own mono font.
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
      actionStyle: t.style(metrics.body),
      actionColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.hovered) ? c.foreground : c.mutedForeground,
      ),
      copiedColor: c.foreground,
      failedColor: c.destructive,
      mark: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.hovered) ? mark : mark.withValues(alpha: 0),
      ),
      markRadius: 2,
      fill: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed) ? c.active : transparent,
      ),
      radius: theme.shape.radii(metrics.tier).item,
      minHeight: metrics.controlHeight,
      iconSize: metrics.iconSize,
      actionGap: 6,
    );
  }

  /// The copied value's text style.
  final TextStyle? valueStyle;

  /// The action's "Copy" text style. Its color comes from [actionColor].
  final TextStyle? actionStyle;

  /// The action's icon and text color.
  final WidgetStateProperty<Color?>? actionColor;

  /// The action's color while it shows "Copied".
  final Color? copiedColor;

  /// The action's color while it shows "Failed".
  final Color? failedColor;

  /// The highlight behind the value.
  final WidgetStateProperty<Color?>? mark;

  /// The highlight's corner radius.
  final double? markRadius;

  /// The row's fill.
  final WidgetStateProperty<Color?>? fill;

  /// The row's corner radius.
  final double? radius;

  /// The row's minimum height.
  final double? minHeight;

  /// The action icon's size, before text scaling.
  final double? iconSize;

  /// The space between the action's icon and its text.
  final double? actionGap;

  @override
  CoilInputCopyStyle merge(CoilInputCopyStyle? other) => other == null
      ? this
      : CoilInputCopyStyle(
          valueStyle: valueStyle?.merge(other.valueStyle) ?? other.valueStyle,
          actionStyle:
              actionStyle?.merge(other.actionStyle) ?? other.actionStyle,
          actionColor: other.actionColor ?? actionColor,
          copiedColor: other.copiedColor ?? copiedColor,
          failedColor: other.failedColor ?? failedColor,
          mark: other.mark ?? mark,
          markRadius: other.markRadius ?? markRadius,
          fill: other.fill ?? fill,
          radius: other.radius ?? radius,
          minHeight: other.minHeight ?? minHeight,
          iconSize: other.iconSize ?? iconSize,
          actionGap: other.actionGap ?? actionGap,
        );

  @override
  List<Object?> get props => [
    valueStyle,
    actionStyle,
    actionColor,
    copiedColor,
    failedColor,
    mark,
    markRadius,
    fill,
    radius,
    minHeight,
    iconSize,
    actionGap,
  ];
}
