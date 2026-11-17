import 'package:coil/foundation.dart';
import 'package:coil_glass/src/glass.dart';
import 'package:coil_glass/src/glass_scope.dart';
import 'package:coil_glass/src/glass_style.dart';
import 'package:flutter/widgets.dart';

/// coil's surfaces in liquid glass: fills coil's [CoilMaterial] seam.
///
/// - `CoilButton(variant: .glass)` gets a regular glass capsule that
///   swells under the finger; `.glassProminent` a brand-tinted one.
/// - Every `CoilPopoverSurface` (dropdown, context menu, select, combobox,
///   date picker) gets a panel of [CoilGlassStyle.dense] glass in a layer
///   of its own, since it floats apart from what opened it.
/// - A `CoilMaterialGroup` becomes one [CoilGlassLayer] with a
///   [CoilGlassGroup]: one render pass, and buttons close together melt.
///
/// Installed by [CoilGlassScope]. Under [CoilGlassMode.solid] it declines,
/// and coil paints its own raised surfaces.
@immutable
class CoilGlassMaterial extends CoilMaterial {
  /// Creates the glass material.
  const CoilGlassMaterial({this.popoverStyle = CoilGlassStyle.dense});

  /// The style of popover glass, over the theme's.
  final CoilGlassStyle popoverStyle;

  @override
  Widget? surface(BuildContext context, CoilSurfaceSpec spec, Widget child) {
    if (CoilGlassScope.modeOf(context) == CoilGlassMode.solid) return null;
    return switch (spec.role) {
      CoilSurfaceRole.control => CoilGlass(
        radius: spec.borderRadius.topLeft.x,
        variant: spec.emphasis == CoilSurfaceEmphasis.prominent
            ? CoilGlassVariant.tinted
            : null,
        response: CoilGlassResponse.stretch,
        child: child,
      ),
      CoilSurfaceRole.popover => CoilGlassLayer(
        style: popoverStyle,
        child: CoilGlass(radius: spec.borderRadius.topLeft.x, child: child),
      ),
    };
  }

  @override
  Widget group(BuildContext context, Widget child) =>
      CoilGlassScope.modeOf(context) == CoilGlassMode.solid
      ? child
      : CoilGlassLayer(child: CoilGlassGroup(child: child));

  @override
  bool operator ==(Object other) =>
      other is CoilGlassMaterial && other.popoverStyle == popoverStyle;

  @override
  int get hashCode => popoverStyle.hashCode;
}
