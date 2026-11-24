/// @docImport 'package:coil/dialog.dart';
library;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Maximum width preset for a [CoilDialog].
enum CoilDialogSize {
  /// 400 at most: confirmations and short forms.
  sm(400),

  /// 540 at most.
  lg(540),

  /// 880 at most.
  xl(880);

  const CoilDialogSize(this.maxWidth);

  /// The widest the dialog gets.
  final double maxWidth;
}

/// Style overrides for a [CoilDialog].
///
/// Unset fields fall back to [CoilDialogStyle.fallback].
@immutable
class CoilDialogStyle extends CoilComponentStyle<CoilDialogStyle> {
  /// Creates a dialog style.
  ///
  /// Null fields fall back to the theme.
  const CoilDialogStyle({
    this.titleStyle,
    this.descriptionStyle,
    this.padding,
    this.radius,
    this.headerGap,
    this.headerSpacing,
    this.actionGap,
    this.windowMargin,
  });

  /// Coil's defaults at [metrics].
  factory CoilDialogStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final typography = theme.typography;
    return CoilDialogStyle(
      // A dialog's title keeps the regular step's title role: it doesn't
      // shrink in a compact scope.
      titleStyle: typography
          .resolve(metrics.tier, CoilSize.regular)
          .title
          .copyWith(color: c.foreground),
      descriptionStyle: typography
          .resolve(metrics.tier, metrics.size)
          .body
          .copyWith(color: c.mutedForeground),
      padding: 24,
      radius: theme.shape.radii(metrics.tier).container,
      headerGap: 6,
      headerSpacing: 16,
      actionGap: 8,
      windowMargin: 16,
    );
  }

  /// The title.
  final TextStyle? titleStyle;

  /// The description under the title.
  final TextStyle? descriptionStyle;

  /// The panel's inner padding.
  final double? padding;

  /// The panel's corner radius.
  final double? radius;

  /// The space between title and description.
  final double? headerGap;

  /// The space between the header and the body, and the body and actions.
  final double? headerSpacing;

  /// The space between actions.
  final double? actionGap;

  /// The smallest distance between the panel and the window's edges.
  final double? windowMargin;

  @override
  CoilDialogStyle merge(CoilDialogStyle? other) => other == null
      ? this
      : CoilDialogStyle(
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
          padding: other.padding ?? padding,
          radius: other.radius ?? radius,
          headerGap: other.headerGap ?? headerGap,
          headerSpacing: other.headerSpacing ?? headerSpacing,
          actionGap: other.actionGap ?? actionGap,
          windowMargin: other.windowMargin ?? windowMargin,
        );

  @override
  List<Object?> get props => [
    titleStyle,
    descriptionStyle,
    padding,
    radius,
    headerGap,
    headerSpacing,
    actionGap,
    windowMargin,
  ];
}
