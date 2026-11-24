/// @docImport 'package:coil/banner.dart';
/// @docImport 'package:flutter/widgets.dart';
library;

/// Semantic severity reported by a [CoilBanner].
///
/// Sets the icon's hue, and [CoilBannerVariant.tinted] banners use it for
/// their fill.
enum CoilBannerStatus {
  /// A plain notice, in the foreground color.
  neutral,

  /// Information.
  info,

  /// Something worked.
  success,

  /// Something needs attention soon.
  warning,

  /// Something failed or will be lost.
  destructive,
}

/// Visual emphasis for a [CoilBanner]'s status hue.
enum CoilBannerVariant {
  /// A quiet neutral fill where only the icon carries the status hue.
  plain,

  /// The status hue blended at 8% as the banner's fill.
  tinted,
}

/// Layout placement and corner treatment for a [CoilBanner].
enum CoilBannerPlacement {
  /// Placed in the page flow, with rounded corners.
  inline,

  /// A full-width bar anchored at the top of the screen.
  ///
  /// Pads itself below the top safe area and uses square corners. Place it at
  /// the top of the page yourself, for example as the first child of a
  /// [Column].
  fixed,
}
