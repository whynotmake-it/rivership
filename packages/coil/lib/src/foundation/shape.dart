/// The corner shape family.
enum CoilShape {
  /// Fully rounded controls (20 px).
  pill(item: 20, container: 24, focusRing: 22),

  /// The default: 8 px controls inside 12 px containers.
  rounded(item: 8, container: 12, focusRing: 10),

  /// Near-square corners (1 px).
  sharp(item: 1, container: 1, focusRing: 3);

  const CoilShape({
    required this.item,
    required this.container,
    required this.focusRing,
  });

  /// Radius of controls and list items (buttons, inputs, highlights).
  final double item;

  /// Radius of containers holding items, concentric with [item] at a 4 px
  /// inset.
  final double container;

  /// Radius of a focus ring drawn 2 px outside an item.
  final double focusRing;

  /// The radius of a surface inset by [inset] inside one of [outer] radius.
  static double nested(double outer, double inset, [double borderWidth = 0]) =>
      (outer - inset - borderWidth).clamp(0, double.infinity);
}
