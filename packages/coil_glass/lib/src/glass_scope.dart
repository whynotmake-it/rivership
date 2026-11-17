import 'package:coil/foundation.dart';
import 'package:coil_glass/src/glass_material.dart';
import 'package:flutter/widgets.dart';

/// How glass renders in a subtree.
///
/// This is the top of coil's material scale (flat → raised → glass). The
/// renderer drops from [glass] to [frosted] on its own where Impeller and
/// Flutter GPU are missing (the web, Skia); [solid] is coil's own choice
/// for accessibility.
enum CoilGlassMode {
  /// Refracting liquid glass.
  glass,

  /// Blur, tint and glint without refraction (`FakeGlass`). It costs the
  /// same backdrop copy as [glass].
  frosted,

  /// No glass: coil's own raised surfaces. For Reduce Transparency, high
  /// contrast and low-power devices.
  solid,
}

/// Turns coil's glass variants and popovers into liquid glass for [child].
///
/// Put it once around the app (or a screen), under the `CoilTheme`:
///
/// - it installs [CoilGlassMaterial] through coil's `CoilMaterialScope`,
///   so `CoilButton(variant: .glass)`, `.glassProminent` and every
///   popover render as glass;
/// - it shares one capture of the content per frame among all glass
///   layers below (a `BackdropGroup`); without it each layer copies the
///   screen again.
///
/// Flutter has no Reduce Transparency flag in `MediaQuery` yet, so pass the
/// platform setting as [reduceTransparency]. That and high contrast
/// (`MediaQuery.highContrastOf`) give [CoilGlassMode.solid].
class CoilGlassScope extends StatelessWidget {
  /// Renders the glass in [child].
  const CoilGlassScope({
    required this.child,
    super.key,
    this.reduceTransparency = false,
    this.mode,
    this.material = const CoilGlassMaterial(),
  });

  /// The app.
  final Widget child;

  /// The platform's Reduce Transparency setting.
  final bool reduceTransparency;

  /// Pins the mode, for previews and tests. Null lets coil decide.
  final CoilGlassMode? mode;

  /// The material to install.
  final CoilGlassMaterial material;

  /// The mode glass at [context] renders in.
  static CoilGlassMode modeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_GlassScope>();
    if ((scope?.reduceTransparency ?? false) ||
        (MediaQuery.maybeHighContrastOf(context) ?? false)) {
      return CoilGlassMode.solid;
    }
    return scope?.mode ?? CoilGlassMode.glass;
  }

  @override
  Widget build(BuildContext context) => _GlassScope(
    reduceTransparency: reduceTransparency,
    mode: mode,
    child: CoilMaterialScope(
      material: material,
      child: BackdropGroup(child: child),
    ),
  );
}

/// Carries the mode. An [InheritedTheme] so popovers and routes opened
/// from inside keep it.
class _GlassScope extends InheritedTheme {
  const _GlassScope({
    required this.reduceTransparency,
    required this.mode,
    required super.child,
  });

  final bool reduceTransparency;
  final CoilGlassMode? mode;

  @override
  Widget wrap(BuildContext context, Widget child) => _GlassScope(
    reduceTransparency: reduceTransparency,
    mode: mode,
    child: child,
  );

  @override
  bool updateShouldNotify(_GlassScope oldWidget) =>
      oldWidget.reduceTransparency != reduceTransparency ||
      oldWidget.mode != mode;
}
