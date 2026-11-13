import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how fields look: `CoilField`, `CoilFieldSet`,
/// `CoilFieldGroup` and `CoilFieldSeparator`. Unset fields come from
/// [CoilFieldStyle.fallback]. Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
class CoilFieldStyle extends CoilComponentStyle<CoilFieldStyle> {
  /// Creates a style.
  const CoilFieldStyle({
    this.labelStyle,
    this.labelColor,
    this.besideLabelColor,
    this.requiredColor,
    this.requiredGap,
    this.descriptionStyle,
    this.errorStyle,
    this.errorIconSize,
    this.errorIconGap,
    this.legendStyle,
    this.legendGap,
    this.separatorColor,
    this.separatorLabelStyle,
    this.separatorHeight,
    this.separatorLabelGap,
    this.labelGap,
    this.messageGap,
    this.besideGap,
    this.fieldGap,
    this.responsiveBreakpoint,
  });

  /// The defaults from the theme's tokens.
  factory CoilFieldStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final t = theme.typography;
    final touch = metrics.tier == CoilTier.touch;
    return CoilFieldStyle(
      labelStyle: t.style(metrics.body),
      labelColor: c.mutedForeground,
      besideLabelColor: c.foreground,
      requiredColor: c.mutedForeground,
      requiredGap: 4,
      descriptionStyle: t.style(metrics.caption, color: c.mutedForeground),
      errorStyle: t.style(metrics.caption, color: c.destructive),
      errorIconSize: metrics.size == CoilSize.compact ? 12 : 14,
      errorIconGap: 6,
      legendStyle: t.style(
        _subtitle(metrics),
        weight: CoilWeight.semibold,
        color: c.foreground,
      ),
      legendGap: 4,
      separatorColor: c.border,
      separatorLabelStyle: t.style(metrics.caption, color: c.mutedForeground),
      separatorHeight: 20,
      separatorLabelGap: 8,
      labelGap: 6,
      messageGap: touch ? 6 : 4,
      besideGap: 12,
      fieldGap: touch ? 16 : 12,
      responsiveBreakpoint: 448,
    );
  }

  /// The style at [context]: the defaults, then the theme's
  /// [CoilFieldStyle], then [style].
  factory CoilFieldStyle.resolve(
    BuildContext context, {
    CoilSize? size,
    CoilFieldStyle? style,
  }) => CoilFieldStyle.fallback(
    CoilTheme.of(context),
    CoilTheme.metricsOf(context, size: size),
  ).merge(CoilTheme.styleOf<CoilFieldStyle>(context)).merge(style);

  // The subtitle role (DESIGN.md §3.1), which CoilMetrics doesn't carry.
  static CoilTypeStep _subtitle(CoilMetrics m) => switch ((m.tier, m.size)) {
    (CoilTier.pointer, CoilSize.regular) => const CoilTypeStep(14, 20),
    (CoilTier.pointer, CoilSize.compact) => const CoilTypeStep(13, 18),
    (CoilTier.touch, CoilSize.regular) => const CoilTypeStep(16, 22),
    (CoilTier.touch, CoilSize.compact) => const CoilTypeStep(15, 20),
  };

  /// The label's text style. Its color comes from [labelColor] or
  /// [besideLabelColor]; an invalid field uses the [errorStyle] color.
  final TextStyle? labelStyle;

  /// The label color above a control.
  final Color? labelColor;

  /// The label color beside a control, in a horizontal field.
  final Color? besideLabelColor;

  /// The required marker's color.
  final Color? requiredColor;

  /// The space between the label and the required marker.
  final double? requiredGap;

  /// The description's text style.
  final TextStyle? descriptionStyle;

  /// The error's text style. Its icon takes the same color.
  final TextStyle? errorStyle;

  /// The error icon's size, before text scaling.
  final double? errorIconSize;

  /// The space between the error icon and the message.
  final double? errorIconGap;

  /// A field set's legend.
  final TextStyle? legendStyle;

  /// The space under a legend.
  final double? legendGap;

  /// The separator's hairline.
  final Color? separatorColor;

  /// The separator's caption.
  final TextStyle? separatorLabelStyle;

  /// The separator's minimum height.
  final double? separatorHeight;

  /// The space on each side of the separator's caption.
  final double? separatorLabelGap;

  /// Label to control.
  final double? labelGap;

  /// Control to description to error.
  final double? messageGap;

  /// Label to control in a horizontal field.
  final double? besideGap;

  /// Field to field, in a set, group or input group.
  final double? fieldGap;

  /// The width from which a responsive field lays out horizontally.
  final double? responsiveBreakpoint;

  @override
  CoilFieldStyle merge(CoilFieldStyle? other) => other == null
      ? this
      : CoilFieldStyle(
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          labelColor: other.labelColor ?? labelColor,
          besideLabelColor: other.besideLabelColor ?? besideLabelColor,
          requiredColor: other.requiredColor ?? requiredColor,
          requiredGap: other.requiredGap ?? requiredGap,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
          errorStyle: errorStyle?.merge(other.errorStyle) ?? other.errorStyle,
          errorIconSize: other.errorIconSize ?? errorIconSize,
          errorIconGap: other.errorIconGap ?? errorIconGap,
          legendStyle:
              legendStyle?.merge(other.legendStyle) ?? other.legendStyle,
          legendGap: other.legendGap ?? legendGap,
          separatorColor: other.separatorColor ?? separatorColor,
          separatorLabelStyle:
              separatorLabelStyle?.merge(other.separatorLabelStyle) ??
              other.separatorLabelStyle,
          separatorHeight: other.separatorHeight ?? separatorHeight,
          separatorLabelGap: other.separatorLabelGap ?? separatorLabelGap,
          labelGap: other.labelGap ?? labelGap,
          messageGap: other.messageGap ?? messageGap,
          besideGap: other.besideGap ?? besideGap,
          fieldGap: other.fieldGap ?? fieldGap,
          responsiveBreakpoint:
              other.responsiveBreakpoint ?? responsiveBreakpoint,
        );

  @override
  List<Object?> get props => [
    labelStyle,
    labelColor,
    besideLabelColor,
    requiredColor,
    requiredGap,
    descriptionStyle,
    errorStyle,
    errorIconSize,
    errorIconGap,
    legendStyle,
    legendGap,
    separatorColor,
    separatorLabelStyle,
    separatorHeight,
    separatorLabelGap,
    labelGap,
    messageGap,
    besideGap,
    fieldGap,
    responsiveBreakpoint,
  ];
}
