import 'package:flutter/widgets.dart';

/// What a raised surface is for, so a [CoilMaterial] can treat a button
/// differently from a menu.
enum CoilSurfaceRole {
  /// The body of a control that asked for a material: a `CoilButton` with
  /// a material variant.
  control,

  /// A panel that floats over the page: the popover of a dropdown,
  /// context menu, select, combobox or date picker.
  popover,
}

/// How much a surface stands out among its neighbors.
enum CoilSurfaceEmphasis {
  /// A neutral surface.
  regular,

  /// The one primary action, washed with the brand.
  prominent,
}

/// What a [CoilMaterial] is asked to build: the role, emphasis and shape of
/// one surface.
@immutable
class CoilSurfaceSpec {
  /// Describes a surface.
  const CoilSurfaceSpec({
    required this.role,
    required this.borderRadius,
    this.emphasis = CoilSurfaceEmphasis.regular,
  });

  /// What the surface is for.
  final CoilSurfaceRole role;

  /// The superellipse's corner radius.
  final BorderRadius borderRadius;

  /// How much it stands out.
  final CoilSurfaceEmphasis emphasis;

  @override
  bool operator ==(Object other) =>
      other is CoilSurfaceSpec &&
      other.role == role &&
      other.borderRadius == borderRadius &&
      other.emphasis == emphasis;

  @override
  int get hashCode => Object.hash(role, borderRadius, emphasis);
}

/// Builds the raised surfaces under a [CoilMaterialScope]: how buttons with
/// a material variant and popovers are made.
///
/// coil paints its own surfaces when there is no material, or when
/// [surface] returns null. A package that renders a heavier material (glass,
/// for one) implements this, so apps keep using coil's components and pick
/// the material once, at the scope.
abstract class CoilMaterial {
  /// Const constructor for subclasses.
  const CoilMaterial();

  /// [child] on a surface for [spec], or null to let coil paint its own.
  ///
  /// [child] is already clipped to the shape and paints the control's own
  /// state washes (hover, press) on top of whatever this returns.
  Widget? surface(BuildContext context, CoilSurfaceSpec spec, Widget child);

  /// Groups the surfaces in [child] that float together (a toolbar's
  /// buttons), so the material can render them as one. Defaults to
  /// [child].
  Widget group(BuildContext context, Widget child) => child;
}

/// Provides a [CoilMaterial] to a subtree. Routes and popovers opened from
/// inside keep it.
class CoilMaterialScope extends InheritedTheme {
  /// Makes [material] build the surfaces in [child].
  const CoilMaterialScope({
    required this.material,
    required super.child,
    super.key,
  });

  /// The material, or null for coil's own surfaces.
  final CoilMaterial? material;

  /// The material at [context], if any.
  static CoilMaterial? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilMaterialScope>()?.material;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      CoilMaterialScope(material: material, child: child);

  @override
  bool updateShouldNotify(CoilMaterialScope oldWidget) =>
      oldWidget.material != material;
}

/// Marks surfaces that float together, such as a cluster of toolbar
/// buttons, so the [CoilMaterial] can render them as one group. Without a
/// material it does nothing.
class CoilMaterialGroup extends StatelessWidget {
  /// Groups the surfaces in [child].
  const CoilMaterialGroup({required this.child, super.key});

  /// The surfaces, anywhere below.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CoilMaterialScope.maybeOf(context)?.group(context, child) ?? child;
}
