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

  /// No backdrop at all: coil's raised surface. For Reduce Transparency,
  /// high contrast and low-power devices.
  solid,
}

/// Settings for the glass below: whether transparency is reduced, or a
/// pinned [CoilGlassMode].
///
/// Flutter has no Reduce Transparency flag in `MediaQuery` yet, so the app
/// passes the platform setting in through [reduceTransparency]. High
/// contrast (`MediaQuery.highContrastOf`) also makes glass `solid`:
/// translucent material can't promise contrast.
class CoilGlassScope extends InheritedWidget {
  /// Configures the glass in [child].
  const CoilGlassScope({
    required super.child,
    super.key,
    this.reduceTransparency = false,
    this.mode,
  });

  /// The platform's Reduce Transparency setting.
  final bool reduceTransparency;

  /// Pins the mode, for previews and tests. Null lets coil decide.
  final CoilGlassMode? mode;

  /// The mode glass at [context] renders in.
  static CoilGlassMode modeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CoilGlassScope>();
    if ((scope?.reduceTransparency ?? false) ||
        (MediaQuery.maybeHighContrastOf(context) ?? false)) {
      return CoilGlassMode.solid;
    }
    return scope?.mode ?? CoilGlassMode.glass;
  }

  @override
  bool updateShouldNotify(CoilGlassScope oldWidget) =>
      oldWidget.reduceTransparency != reduceTransparency ||
      oldWidget.mode != mode;
}
