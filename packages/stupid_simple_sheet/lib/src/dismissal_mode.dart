/// The mode used to animate the sheet's dismissal.
enum DismissalMode {
  /// The sheet translates downward as the animation value decreases.
  slide,

  /// The sheet shrinks vertically as the animation value decreases.
  /// If the child cannot shrink to the target height (based on its
  /// minimum intrinsic height), the child is laid out at its minimum
  /// size and the overflow is clipped at the bottom.
  shrink,
}
