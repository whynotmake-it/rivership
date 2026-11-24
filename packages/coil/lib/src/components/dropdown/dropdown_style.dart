/// @docImport 'package:coil/dropdown.dart';
library;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Style overrides for a [CoilDropdown].
///
/// Unset fields fall back to [CoilDropdownStyle.fallback].
@immutable
class CoilDropdownStyle extends CoilComponentStyle<CoilDropdownStyle> {
  /// Creates a dropdown style.
  ///
  /// Null fields fall back to the theme.
  const CoilDropdownStyle({
    this.surface,
    this.highlight,
    this.pressFill,
    this.radius,
    this.width,
    this.maxHeight,
  });

  /// Coil's defaults at [metrics].
  factory CoilDropdownStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final pointer = metrics.tier == CoilTier.pointer;
    return CoilDropdownStyle(
      highlight: theme.colors.hover,
      pressFill: theme.colors.active,
      radius: theme.shape.radii(metrics.tier).item,
      width: pointer ? 288 : 220,
      maxHeight: pointer ? 480 : double.infinity,
    );
  }

  /// The popup's fill.
  ///
  /// Null is the color of its level: two above the surface it opens from (3 on
  /// the page).
  final Color? surface;

  /// The hover highlight behind a row.
  final Color? highlight;

  /// The fill under a row while a finger presses it.
  final Color? pressFill;

  /// The row corner radius; the popup adds its inset.
  final double? radius;

  /// The popup's width (at least the trigger's on touch).
  final double? width;

  /// The tallest the popup gets before its rows scroll.
  final double? maxHeight;

  @override
  CoilDropdownStyle merge(CoilDropdownStyle? other) => other == null
      ? this
      : CoilDropdownStyle(
          surface: other.surface ?? surface,
          highlight: other.highlight ?? highlight,
          pressFill: other.pressFill ?? pressFill,
          radius: other.radius ?? radius,
          width: other.width ?? width,
          maxHeight: other.maxHeight ?? maxHeight,
        );

  @override
  List<Object?> get props => [
    surface,
    highlight,
    pressFill,
    radius,
    width,
    maxHeight,
  ];
}
