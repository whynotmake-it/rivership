import 'package:fluid_functionalism/src/foundation/fluid_colors.dart';
import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart';
import 'package:fluid_functionalism/src/foundation/fluid_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The corner shape family (`lib/shape-context.tsx`).
enum FluidShape {
  /// Fully rounded controls (20 px).
  pill(item: 20, container: 24, focusRing: 22),

  /// The default: 8 px controls inside 12 px containers.
  rounded(item: 8, container: 12, focusRing: 10),

  /// Near-square corners (1 px).
  sharp(item: 1, container: 1, focusRing: 3);

  const FluidShape({
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

/// The visual configuration of Fluid Functionalism components.
@immutable
class FluidThemeData with Diagnosticable {
  /// Creates theme data.
  const FluidThemeData({
    this.colors = FluidColors.light,
    this.shape = FluidShape.rounded,
    this.tier,
    this.motion = const FluidMotionThemeData(),
    this.typography = const FluidTypographyThemeData(),
  });

  /// The light theme.
  static const light = FluidThemeData();

  /// The dark theme.
  static const dark = FluidThemeData(colors: FluidColors.dark);

  /// The color tokens.
  final FluidColors colors;

  /// The corner shape family.
  final FluidShape shape;

  /// The default size tier, or null to pick one from the platform
  /// ([FluidTier.forPlatform]). A [FluidSizeScope] overrides it.
  final FluidTier? tier;

  /// The motion tokens. Change them at runtime: components read them on
  /// every animation.
  final FluidMotionThemeData motion;

  /// The font family and its metrics (cap height for label centering).
  final FluidTypographyThemeData typography;

  /// Light or dark.
  Brightness get brightness => colors.brightness;

  /// Returns a copy with the given fields replaced.
  FluidThemeData copyWith({
    FluidColors? colors,
    FluidShape? shape,
    FluidTier? tier,
    FluidMotionThemeData? motion,
    FluidTypographyThemeData? typography,
  }) => FluidThemeData(
    colors: colors ?? this.colors,
    shape: shape ?? this.shape,
    tier: tier ?? this.tier,
    motion: motion ?? this.motion,
    typography: typography ?? this.typography,
  );

  @override
  bool operator ==(Object other) =>
      other is FluidThemeData &&
      other.colors == colors &&
      other.shape == shape &&
      other.tier == tier &&
      other.motion == motion &&
      other.typography == typography;

  @override
  int get hashCode => Object.hash(colors, shape, tier, motion, typography);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('colors', colors))
      ..add(EnumProperty('shape', shape))
      ..add(EnumProperty('tier', tier, defaultValue: null))
      ..add(DiagnosticsProperty('motion', motion));
  }
}

/// Provides [FluidThemeData] to a subtree.
///
/// Also sets a [DefaultTextStyle] (Inter, body size, foreground color) so
/// plain [Text] in slots matches the system.
class FluidTheme extends StatelessWidget {
  /// Creates a theme.
  const FluidTheme({required this.data, required this.child, super.key});

  /// The theme for the subtree.
  final FluidThemeData data;

  /// The subtree.
  final Widget child;

  /// The nearest theme, or [FluidThemeData.light] if there is none.
  static FluidThemeData of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_InheritedFluidTheme>()
          ?.data ??
      FluidThemeData.light;

  /// The motion tokens in effect at [context]: [override] if given (a
  /// component's `motion:` parameter), else the theme's, made
  /// [FluidMotionThemeData.reduced] when the platform asks for reduced
  /// motion. Read it where an animation starts, not once, so runtime
  /// changes apply to the next animation.
  static FluidMotionThemeData motionOf(
    BuildContext context, {
    FluidMotionThemeData? override,
  }) {
    final motion = override ?? of(context).motion;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? motion.reduced()
        : motion;
  }

  /// The sizes in effect at [context]: [density] if given, else the nearest
  /// [FluidSizeScope]'s, else regular; the nearest scope's tier, else the
  /// theme's, else the platform's.
  static FluidSizes sizesOf(BuildContext context, {FluidDensity? density}) {
    final tier =
        FluidSizeScope.maybeTierOf(context) ??
        of(context).tier ??
        FluidTier.forPlatform(defaultTargetPlatform);
    return FluidSizes.resolve(
      tier,
      density ?? FluidSizeScope.maybeDensityOf(context) ?? FluidDensity.regular,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = FluidSizes.resolve(
      FluidSizeScope.maybeTierOf(context) ??
          data.tier ??
          FluidTier.forPlatform(defaultTargetPlatform),
      FluidSizeScope.maybeDensityOf(context) ?? FluidDensity.regular,
    );
    return _InheritedFluidTheme(
      data: data,
      child: DefaultTextStyle(
        style: data.typography.style(
          sizes.body,
          color: data.colors.foreground,
        ),
        child: DefaultSelectionStyle(
          cursorColor: data.colors.foreground,
          selectionColor: data.colors.fluidAccent.withValues(alpha: 0.3),
          child: child,
        ),
      ),
    );
  }
}

class _InheritedFluidTheme extends InheritedTheme {
  const _InheritedFluidTheme({required this.data, required super.child});

  final FluidThemeData data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      FluidTheme(data: data, child: child);

  @override
  bool updateShouldNotify(_InheritedFluidTheme oldWidget) =>
      oldWidget.data != data;
}
