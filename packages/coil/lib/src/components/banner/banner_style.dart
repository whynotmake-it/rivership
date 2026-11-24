/// @docImport 'package:coil/banner.dart';
library;

import 'package:coil/foundation.dart';
import 'package:coil/src/components/banner/banner.dart' show CoilBannerTrack;
import 'package:coil/src/components/banner/banner_kinds.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a [CoilBanner] looks.
///
/// Unset fields come from [CoilBannerStyle.fallback], which derives them from
/// the theme's tokens.
class CoilBannerStyle extends CoilComponentStyle<CoilBannerStyle> {
  /// Creates a banner style.
  const CoilBannerStyle({
    this.background,
    this.statusColor,
    this.titleStyle,
    this.descriptionStyle,
    this.radius,
    this.padding,
    this.gap,
    this.actionSpacing,
    this.iconSize,
    this.motions,
  });

  /// The defaults for a banner with [status], [variant] and [placement],
  /// from [theme]'s tokens at [metrics].
  factory CoilBannerStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics, {
    required CoilBannerStatus status,
    required CoilBannerVariant variant,
    required CoilBannerPlacement placement,
  }) {
    final c = theme.colors;
    final hue = switch (status) {
      CoilBannerStatus.neutral => c.foreground,
      CoilBannerStatus.info => c.info,
      CoilBannerStatus.success => c.success,
      CoilBannerStatus.warning => c.warning,
      CoilBannerStatus.destructive => c.destructive,
    };
    final fill = switch (variant) {
      CoilBannerVariant.plain => c.hover,
      CoilBannerVariant.tinted => hue.withValues(alpha: 0.08),
    };
    final compact = metrics.size == CoilSize.compact;
    final text = theme.typography.resolve(metrics.tier, metrics.size);
    return CoilBannerStyle(
      // A fixed bar covers scrolling content, so its fill sits on an
      // opaque background.
      background: placement == CoilBannerPlacement.fixed
          ? Color.alphaBlend(fill, c.background)
          : fill,
      statusColor: hue,
      titleStyle: text.body.copyWith(
        fontWeight: text.emphasis,
        color: c.foreground,
      ),
      descriptionStyle: text.body.copyWith(color: c.mutedForeground),
      radius: placement == CoilBannerPlacement.fixed
          ? 0
          : theme.shape.radii(metrics.tier).container,
      padding: compact ? 12 : 16,
      gap: 12,
      actionSpacing: 8,
      iconSize: compact ? 16 : 20,
    );
  }

  /// The banner's fill.
  final Color? background;

  /// The status hue: the icon slot's color.
  final Color? statusColor;

  /// The title's text style.
  final TextStyle? titleStyle;

  /// The description's text style.
  final TextStyle? descriptionStyle;

  /// The corner radius of an inline banner.
  final double? radius;

  /// The padding on every side.
  final double? padding;

  /// The gap between the icon, the text, the actions and the dismiss
  /// button.
  final double? gap;

  /// The gap between the actions, and between the text and actions under
  /// it.
  final double? actionSpacing;

  /// The icon slot's size, before text scaling.
  final double? iconSize;

  /// Springs for the banner's animated parts, keyed by [CoilBannerTrack]s:
  /// `{CoilBannerTrack.row: const Motion.bouncySpring()}`.
  ///
  /// A banner's own `motions:` win over these; these win over the motion
  /// tokens. [merge] combines the maps key by key.
  final Map<CoilBannerTrack<Object>, Motion>? motions;

  @override
  CoilBannerStyle merge(CoilBannerStyle? other) => other == null
      ? this
      : CoilBannerStyle(
          background: other.background ?? background,
          statusColor: other.statusColor ?? statusColor,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
          radius: other.radius ?? radius,
          padding: other.padding ?? padding,
          gap: other.gap ?? gap,
          actionSpacing: other.actionSpacing ?? actionSpacing,
          iconSize: other.iconSize ?? iconSize,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    background,
    statusColor,
    titleStyle,
    descriptionStyle,
    radius,
    padding,
    gap,
    actionSpacing,
    iconSize,
    motions,
  ];
}
