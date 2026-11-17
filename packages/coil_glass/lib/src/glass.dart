import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil_glass/src/glass_scope.dart';
import 'package:coil_glass/src/glass_style.dart';
import 'package:coil_glass/src/on_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// The corner family of a [CoilGlass].
enum CoilGlassShape {
  /// The theme's container radius: panels, menus, sheets, sidebars.
  container,

  /// Radius = height / 2: bars, toolbars, segmented controls, composers.
  pill,

  /// A circle (an oval in a non-square box): icon buttons.
  circle,
}

/// Whether a glass shape answers touch with Apple's squash and stretch.
enum CoilGlassResponse {
  /// Stays put. For panels and bars that hold their own controls.
  none,

  /// Swells under the finger and stretches while dragged.
  stretch,
}

/// One backdrop pass for the glass below it: the unit glass is grouped and
/// paid for in.
///
/// Every [CoilGlass] inside shares this layer's sample of the content
/// behind it, its settings (light/dark from the coil theme, the
/// [CoilGlassStyle]) and its render pass. Put one layer around each
/// floating group of chrome (the bottom bar and its buttons, a toolbar),
/// never one per control: each independent layer copies the screen again.
///
/// Under [CoilGlassMode.solid] the layer is a no-op and its shapes paint
/// coil's raised surface.
class CoilGlassLayer extends StatelessWidget {
  /// Creates a glass layer.
  const CoilGlassLayer({required this.child, super.key, this.style});

  /// The chrome.
  final Widget child;

  /// Overrides the theme's glass style for this layer.
  final CoilGlassStyle? style;

  @override
  Widget build(BuildContext context) {
    final mode = CoilGlassScope.modeOf(context);
    if (mode == CoilGlassMode.solid) return child;
    final theme = CoilTheme.of(context);
    final look = CoilGlassStyle.fallback(
      theme,
    ).merge(CoilTheme.styleOf<CoilGlassStyle>(context)).merge(style);
    return LiquidGlassLayer(
      settings: look.settingsFor(theme.brightness),
      defaultAppearance: look.appearanceFor(theme.brightness),
      fake: mode == CoilGlassMode.frosted,
      useBackdropGroup: BackdropGroup.of(context) != null,
      // A layer starts its own grouping: shapes in it don't join a blend
      // group of an outer layer.
      child: _Grouped(grouped: false, child: child),
    );
  }
}

/// The content that every [CoilGlassLayer] below floats over, captured
/// once per frame for all of them.
///
/// Put it around a screen whose chrome sits in several layers (a toolbar
/// at the top, a tab bar at the bottom). Without it, each layer copies
/// the whole screen again. Layers that share the capture see the content,
/// not each other's glass, which is what separate pieces of chrome want.
class CoilGlassBackdrop extends StatelessWidget {
  /// Shares one backdrop capture among the glass layers in [child].
  const CoilGlassBackdrop({required this.child, super.key});

  /// The screen: its content and its chrome.
  final Widget child;

  @override
  Widget build(BuildContext context) => BackdropGroup(child: child);
}

/// Melts the [CoilGlass] shapes inside into one surface where they come
/// within the style's `blend` distance, like drops of water: a button
/// next to a bar, queued messages above a composer.
///
/// Must sit inside a [CoilGlassLayer].
class CoilGlassGroup extends StatelessWidget {
  /// Creates a blend group.
  const CoilGlassGroup({required this.child, super.key, this.blend});

  /// The shapes, anywhere below.
  final Widget child;

  /// Overrides the style's blend distance.
  final double? blend;

  @override
  Widget build(BuildContext context) {
    if (CoilGlassScope.modeOf(context) == CoilGlassMode.solid) return child;
    final look = CoilGlassStyle.fallback(
      CoilTheme.of(context),
    ).merge(CoilTheme.styleOf<CoilGlassStyle>(context));
    return _Grouped(
      grouped: true,
      child: LiquidGlassBlendGroup(blend: blend ?? look.blend!, child: child),
    );
  }
}

class _Grouped extends InheritedWidget {
  const _Grouped({required this.grouped, required super.child});

  final bool grouped;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Grouped>()?.grouped ?? false;

  @override
  bool updateShouldNotify(_Grouped oldWidget) => oldWidget.grouped != grouped;
}

/// A piece of glass chrome: a bar, a panel, a floating button.
///
/// Its [child] paints on top of the glass, clipped to it, inside
/// [CoilOnGlass], so coil components placed on it adapt (lighter selection
/// platters, no opaque fills of their own).
///
/// Inside a [CoilGlassGroup] it blends with its neighbors; otherwise it
/// joins the nearest [CoilGlassLayer], or makes its own when there is
/// none. Under [CoilGlassMode.solid] it is a [CoilSurface] at popover
/// height: coil's raised material, so the hierarchy survives without
/// transparency.
class CoilGlass extends StatelessWidget {
  /// Creates a glass shape.
  const CoilGlass({
    required this.child,
    super.key,
    this.shape = CoilGlassShape.container,
    this.radius,
    this.variant,
    this.response = CoilGlassResponse.none,
    this.style,
  });

  /// The content on the glass.
  final Widget child;

  /// The corner family.
  final CoilGlassShape shape;

  /// A corner radius for [CoilGlassShape.container]; the theme's container
  /// radius when null. Use the parent's radius minus the inset for glass
  /// nested in glass, so corners stay concentric.
  final double? radius;

  /// Overrides the material of this shape only (e.g. one tinted action).
  final CoilGlassVariant? variant;

  /// Squash and stretch under the finger.
  final CoilGlassResponse response;

  /// Overrides the theme's glass style for this shape.
  final CoilGlassStyle? style;

  double _radius(BuildContext context) => switch (shape) {
    CoilGlassShape.container => radius ?? CoilTheme.radiiOf(context).container,
    // The renderer and RoundedSuperellipseBorder both clamp to half the
    // short side, which is a capsule.
    CoilGlassShape.pill || CoilGlassShape.circle => 1000,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final look = CoilGlassStyle.fallback(theme)
        .merge(CoilTheme.styleOf<CoilGlassStyle>(context))
        .merge(style)
        .merge(variant == null ? null : CoilGlassStyle(variant: variant));
    final radius = _radius(context);
    final content = CoilOnGlass(
      variant: look.variant!,
      child: IconTheme.merge(
        data: IconThemeData(color: _labelColor(look, theme)),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: _labelColor(look, theme)),
          child: child,
        ),
      ),
    );

    if (CoilGlassScope.modeOf(context) == CoilGlassMode.solid) {
      final solid = look.variant == CoilGlassVariant.tinted
          ? look.tint
          : look.solidFill;
      final border = BorderRadius.circular(radius);
      return CoilSurface(
        offset: CoilSurface.popoverOffset,
        shadowLevel: 3,
        color: solid,
        borderRadius: border,
        child: ClipRSuperellipse(borderRadius: border, child: content),
      );
    }

    final liquidShape = shape == CoilGlassShape.circle
        ? const LiquidOval()
        : LiquidRoundedSuperellipse(borderRadius: radius);
    final appearance = look.appearanceFor(theme.brightness);
    final Widget glass = _Grouped.of(context)
        ? LiquidGlass.grouped(
            shape: liquidShape,
            shadows: look.shadows!,
            appearance: appearance,
            child: content,
          )
        : LiquidGlass.auto(
            shape: liquidShape,
            settings: look.settingsFor(theme.brightness),
            shadows: look.shadows!,
            appearance: appearance,
            child: content,
          );
    return switch (response) {
      CoilGlassResponse.none => glass,
      CoilGlassResponse.stretch => LiquidStretch(child: glass),
    };
  }

  static Color _labelColor(CoilGlassStyle look, CoilThemeData theme) =>
      switch (look.variant!) {
        // Tinted glass carries the brand; its label is the brand's
        // foreground, like a primary button's.
        CoilGlassVariant.tinted => const Color(0xFFFFFFFF),
        _ => look.label ?? theme.colors.foreground,
      };
}
