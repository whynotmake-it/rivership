import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil_glass/src/glass_scope.dart';
import 'package:coil_glass/src/glass_style.dart';
import 'package:coil_glass/src/on_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// The corner family of a [CoilGlass].
enum CoilGlassShape {
  /// A superellipse with the given radius (the theme's container radius
  /// when none is given): panels, menus.
  rounded,

  /// Radius = height / 2: labelled buttons and bars; a circle when square.
  capsule,
}

/// Whether a glass shape answers touch with Apple's squash and stretch.
enum CoilGlassResponse {
  /// Stays put. For panels and menus.
  none,

  /// Swells under the finger and stretches while dragged: controls.
  stretch,
}

/// The glass style in effect at [context]: the theme's, merged with the
/// nearest [CoilGlassLayer]'s.
CoilGlassStyle _styleOf(BuildContext context) {
  final layer = context.dependOnInheritedWidgetOfExactType<_LayerScope>();
  return CoilGlassStyle.fallback(CoilTheme.of(context))
      .merge(CoilTheme.styleOf<CoilGlassStyle>(context))
      .merge(layer?.style);
}

/// One backdrop pass for the glass below it: the unit glass is grouped and
/// paid for in.
///
/// Every [CoilGlass] inside shares this layer's sample of the content
/// behind it, its settings (light/dark from the coil theme, the
/// [CoilGlassStyle]) and its render pass. `CoilGlassMaterial` puts one
/// around each `CoilMaterialGroup` and each popover; use it directly only
/// for glass you compose yourself.
///
/// Under [CoilGlassMode.solid] the layer is a no-op.
class CoilGlassLayer extends StatelessWidget {
  /// Creates a glass layer.
  const CoilGlassLayer({required this.child, super.key, this.style});

  /// The glass shapes, anywhere below.
  final Widget child;

  /// Overrides the theme's glass style for this layer and its shapes.
  final CoilGlassStyle? style;

  @override
  Widget build(BuildContext context) {
    final mode = CoilGlassScope.modeOf(context);
    if (mode == CoilGlassMode.solid) return child;
    final scoped = _LayerScope(
      style: style,
      // A layer starts its own grouping: its shapes don't join a blend
      // group of an outer layer.
      child: _Grouped(grouped: false, child: child),
    );
    return Builder(
      builder: (context) {
        final brightness = CoilTheme.of(context).brightness;
        final look = CoilGlassStyle.fallback(
          CoilTheme.of(context),
        ).merge(CoilTheme.styleOf<CoilGlassStyle>(context)).merge(style);
        return LiquidGlassLayer(
          settings: look.settingsFor(brightness),
          defaultAppearance: look.appearanceFor(brightness),
          fake: mode == CoilGlassMode.frosted,
          useBackdropGroup: BackdropGroup.of(context) != null,
          child: scoped,
        );
      },
    );
  }
}

class _LayerScope extends InheritedWidget {
  const _LayerScope({required this.style, required super.child});

  final CoilGlassStyle? style;

  @override
  bool updateShouldNotify(_LayerScope oldWidget) => oldWidget.style != style;
}

/// Melts the [CoilGlass] shapes inside into one surface where they come
/// within the style's `blend` distance, like drops of water.
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
    return _Grouped(
      grouped: true,
      child: LiquidGlassBlendGroup(
        blend: blend ?? _styleOf(context).blend!,
        child: child,
      ),
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

/// One piece of glass: a button's body, a menu's panel.
///
/// Its [child] paints on top of the glass, clipped to it, inside
/// [CoilOnGlass], so coil components placed on it adapt.
///
/// Inside a [CoilGlassGroup] it blends with its neighbors; otherwise it
/// joins the nearest [CoilGlassLayer], or makes its own when there is
/// none. Under [CoilGlassMode.solid] it is a [CoilSurface] at popover
/// height.
class CoilGlass extends StatelessWidget {
  /// Creates a glass shape.
  const CoilGlass({
    required this.child,
    super.key,
    this.shape = CoilGlassShape.rounded,
    this.radius,
    this.variant,
    this.response = CoilGlassResponse.none,
  });

  /// The content on the glass.
  final Widget child;

  /// The corner family.
  final CoilGlassShape shape;

  /// The radius of a [CoilGlassShape.rounded] shape; the theme's container
  /// radius when null.
  final double? radius;

  /// Overrides the material of this shape only (the tinted action).
  final CoilGlassVariant? variant;

  /// Squash and stretch under the finger.
  final CoilGlassResponse response;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final look = _styleOf(
      context,
    ).merge(variant == null ? null : CoilGlassStyle(variant: variant));
    final radius = switch (shape) {
      CoilGlassShape.rounded =>
        this.radius ?? CoilTheme.radiiOf(context).container,
      // The renderer and RoundedSuperellipseBorder both clamp to half the
      // short side, which is a capsule.
      CoilGlassShape.capsule => 1000.0,
    };
    final label = look.variant == CoilGlassVariant.tinted
        ? CoilColorMix.ensureContrast(
            const Color(0xFFFFFFFF),
            look.tint ?? theme.colors.brand,
            4.5,
          )
        : look.label ?? theme.colors.foreground;
    final content = CoilOnGlass(
      variant: look.variant!,
      child: IconTheme.merge(
        data: IconThemeData(color: label),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: label),
          child: child,
        ),
      ),
    );

    if (CoilGlassScope.modeOf(context) == CoilGlassMode.solid) {
      final border = BorderRadius.circular(radius);
      return CoilSurface(
        offset: CoilSurface.popoverOffset,
        shadowLevel: 3,
        color: look.variant == CoilGlassVariant.tinted
            ? look.tint
            : look.solidFill,
        borderRadius: border,
        child: ClipRSuperellipse(borderRadius: border, child: content),
      );
    }

    final liquidShape = LiquidRoundedSuperellipse(borderRadius: radius);
    final appearance = look.appearanceFor(theme.brightness);
    Widget glass = _Grouped.of(context)
        ? LiquidGlass.grouped(
            shape: liquidShape,
            shadows: look.shadows!,
            appearance: appearance,
            child: content,
          )
        : LiquidGlass(
            shape: liquidShape,
            shadows: look.shadows!,
            appearance: appearance,
            child: content,
          );
    // A shape on its own gets a layer of its own, so it still follows the
    // mode and shares the screen's backdrop capture.
    if (context.dependOnInheritedWidgetOfExactType<_LayerScope>() == null) {
      glass = CoilGlassLayer(child: glass);
    }
    return switch (response) {
      CoilGlassResponse.none => glass,
      CoilGlassResponse.stretch => LiquidStretch(
        interactionScale: 1.04,
        stretch: 0.3,
        child: glass,
      ),
    };
  }
}
