import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilField` (and `CoilFieldSet`, `CoilFieldGroup`,
/// `CoilFieldSeparator`) looks. Unset fields come from
/// [CoilFieldStyle.fallback], derived from the theme's tokens. Set a style
/// app-wide or for a subtree with `CoilThemeData.withComponentStyle`, or per
/// instance with `style:`.
///
/// [labelColor] is resolved with [WidgetState.error] (the field is invalid)
/// and [WidgetState.selected] (the label sits beside its control, in a
/// horizontal field, rather than above it).
class CoilFieldStyle extends CoilComponentStyle<CoilFieldStyle> {
  /// Creates a style.
  const CoilFieldStyle({
    this.labelStyle,
    this.labelColor,
    this.requiredColor,
    this.descriptionStyle,
    this.errorStyle,
    this.errorIconSize,
    this.legendStyle,
    this.separatorColor,
    this.separatorLabelStyle,
    this.labelGap,
    this.messageGap,
    this.fieldGap,
  });

  /// The defaults from the theme's tokens.
  factory CoilFieldStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final t = theme.typography;
    final touch = metrics.tier == CoilTier.touch;
    return CoilFieldStyle(
      labelStyle: t.style(metrics.body),
      labelColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.error)
            ? c.destructive
            : s.contains(WidgetState.selected)
            ? c.foreground
            : c.mutedForeground,
      ),
      requiredColor: c.mutedForeground,
      descriptionStyle: t.style(metrics.caption, color: c.mutedForeground),
      errorStyle: t.style(metrics.caption, color: c.destructive),
      errorIconSize: metrics.size == CoilSize.compact ? 12 : 14,
      legendStyle: t.style(
        _subtitle(metrics),
        weight: CoilWeight.semibold,
        color: c.foreground,
      ),
      separatorColor: c.border,
      separatorLabelStyle: t.style(metrics.caption, color: c.mutedForeground),
      labelGap: 6,
      messageGap: touch ? 6 : 4,
      fieldGap: touch ? 16 : 12,
    );
  }

  // The subtitle role (DESIGN.md §3.1), which CoilMetrics doesn't carry.
  static CoilTypeStep _subtitle(CoilMetrics m) => switch ((m.tier, m.size)) {
    (CoilTier.pointer, CoilSize.regular) => const CoilTypeStep(14, 20),
    (CoilTier.pointer, CoilSize.compact) => const CoilTypeStep(13, 18),
    (CoilTier.touch, CoilSize.regular) => const CoilTypeStep(16, 22),
    (CoilTier.touch, CoilSize.compact) => const CoilTypeStep(15, 20),
  };

  /// The label's text style (its color comes from [labelColor]).
  final TextStyle? labelStyle;

  /// The label's color by state: muted above a control, foreground beside
  /// one, `destructive` when invalid.
  final WidgetStateProperty<Color?>? labelColor;

  /// The required marker's color.
  final Color? requiredColor;

  /// The description's text style.
  final TextStyle? descriptionStyle;

  /// The error's text style; its icon takes the text color.
  final TextStyle? errorStyle;

  /// The error icon's size (before text scaling).
  final double? errorIconSize;

  /// A field set's legend.
  final TextStyle? legendStyle;

  /// The separator's hairline.
  final Color? separatorColor;

  /// The separator's optional label.
  final TextStyle? separatorLabelStyle;

  /// Label → control.
  final double? labelGap;

  /// Control → description → error.
  final double? messageGap;

  /// Field → field, in a field set or group.
  final double? fieldGap;

  @override
  CoilFieldStyle merge(CoilFieldStyle? other) => other == null
      ? this
      : CoilFieldStyle(
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          labelColor: other.labelColor ?? labelColor,
          requiredColor: other.requiredColor ?? requiredColor,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
          errorStyle: errorStyle?.merge(other.errorStyle) ?? other.errorStyle,
          errorIconSize: other.errorIconSize ?? errorIconSize,
          legendStyle:
              legendStyle?.merge(other.legendStyle) ?? other.legendStyle,
          separatorColor: other.separatorColor ?? separatorColor,
          separatorLabelStyle:
              separatorLabelStyle?.merge(other.separatorLabelStyle) ??
              other.separatorLabelStyle,
          labelGap: other.labelGap ?? labelGap,
          messageGap: other.messageGap ?? messageGap,
          fieldGap: other.fieldGap ?? fieldGap,
        );

  @override
  List<Object?> get props => [
    labelStyle,
    labelColor,
    requiredColor,
    descriptionStyle,
    errorStyle,
    errorIconSize,
    legendStyle,
    separatorColor,
    separatorLabelStyle,
    labelGap,
    messageGap,
    fieldGap,
  ];
}
