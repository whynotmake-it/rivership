/// The visual variant of a `CoilButton`.
enum CoilButtonVariant {
  /// Solid foreground fill: the one main action.
  primary,

  /// A see-through tint that takes on the surface beneath it.
  secondary,

  /// Transparent with a hairline border.
  tertiary,

  /// No fill until hovered; a muted label.
  ghost,

  /// A red wash under a red label.
  destructive,
}
