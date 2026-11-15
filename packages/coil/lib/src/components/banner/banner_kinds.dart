/// What a banner reports. It sets the icon's hue, and `tinted` banners
/// take it as their fill.
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

/// How strongly a banner shows its status.
enum CoilBannerVariant {
  /// A quiet neutral fill; only the icon carries the status hue.
  plain,

  /// The status hue at 8 % as the fill.
  tinted,
}

/// Where a banner sits.
enum CoilBannerPlacement {
  /// In the page flow, with rounded corners.
  inline,

  /// A full-width bar at the top of the screen. It pads itself below the
  /// top safe area and has square corners. Place it at the top of the page
  /// yourself, for example as the first child of a `Column`.
  fixed,
}
