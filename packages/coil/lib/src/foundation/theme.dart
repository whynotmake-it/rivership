import 'package:coil/src/foundation/adaptive.dart';
import 'package:coil/src/foundation/colors.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/shape.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Changes a parent theme for a subtree. See [CoilTheme.override].
typedef CoilThemeTransform = CoilThemeData Function(CoilThemeData parent);

/// Every token coil components read, as one runtime-changeable object.
@immutable
class CoilThemeData with Diagnosticable {
  /// Creates theme data. Unset fields keep coil's defaults.
  const CoilThemeData({
    this.colors = CoilColors.light,
    this.shape = CoilShape.rounded,
    this.tier,
    this.motion = const CoilMotion(),
    this.typography = const CoilTypography(),
    this.focusRingWidth = 1,
  });

  /// The light theme.
  static const light = CoilThemeData();

  /// The dark theme.
  static const dark = CoilThemeData(colors: CoilColors.dark);

  /// The color tokens.
  final CoilColors colors;

  /// The corner shape family.
  final CoilShape shape;

  /// The size tier, or null to latch it from the platform
  /// ([CoilTier.forPlatform]). A [CoilAdaptiveScope] overrides it.
  final CoilTier? tier;

  /// The motion tokens. Components read them on every animation, so a
  /// change applies to the next one.
  final CoilMotion motion;

  /// The font family and its weights.
  final CoilTypography typography;

  /// The focus ring's thickness: 1, or 2 in high contrast.
  final double focusRingWidth;

  /// This theme for high contrast ([CoilColors.highContrast] plus a 2 px
  /// focus ring). [CoilTheme.of] applies it when
  /// `MediaQuery.highContrastOf` is true.
  CoilThemeData highContrast() =>
      copyWith(colors: colors.highContrast(), focusRingWidth: 2);

  /// Light or dark.
  Brightness get brightness => colors.brightness;

  /// Returns a copy with the given fields replaced.
  CoilThemeData copyWith({
    CoilColors? colors,
    CoilShape? shape,
    CoilTier? tier,
    CoilMotion? motion,
    CoilTypography? typography,
    double? focusRingWidth,
  }) => CoilThemeData(
    colors: colors ?? this.colors,
    shape: shape ?? this.shape,
    tier: tier ?? this.tier,
    motion: motion ?? this.motion,
    typography: typography ?? this.typography,
    focusRingWidth: focusRingWidth ?? this.focusRingWidth,
  );

  /// Interpolates two themes, for animated theme changes. Colors and the
  /// ring width blend; everything else switches at the midpoint.
  // A static lerp, like Color.lerp and TextStyle.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilThemeData lerp(CoilThemeData a, CoilThemeData b, double t) =>
      CoilThemeData(
        colors: CoilColors.lerp(a.colors, b.colors, t),
        shape: t < 0.5 ? a.shape : b.shape,
        tier: t < 0.5 ? a.tier : b.tier,
        motion: CoilMotion.lerp(a.motion, b.motion, t),
        typography: t < 0.5 ? a.typography : b.typography,
        focusRingWidth:
            a.focusRingWidth + (b.focusRingWidth - a.focusRingWidth) * t,
      );

  @override
  bool operator ==(Object other) =>
      other is CoilThemeData &&
      other.colors == colors &&
      other.shape == shape &&
      other.tier == tier &&
      other.motion == motion &&
      other.typography == typography &&
      other.focusRingWidth == focusRingWidth;

  @override
  int get hashCode =>
      Object.hash(colors, shape, tier, motion, typography, focusRingWidth);

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

/// Provides [CoilThemeData] to a subtree.
///
/// Optional: without one, components use [CoilThemeData.light] or
/// [CoilThemeData.dark] by platform brightness. Works under any
/// `WidgetsApp`; it also sets a [DefaultTextStyle] and
/// [DefaultSelectionStyle] so plain [Text] in slots matches the system.
///
/// Resolution, lowest to highest (doc/api_guide.md §6): package defaults,
/// the platform tier, the root theme, subtree [CoilTheme.override]s, a
/// component's own `motion:`, high contrast ([of]), reduced motion
/// ([motionOf]).
class CoilTheme extends StatelessWidget {
  /// Provides [data] to [child].
  const CoilTheme({required CoilThemeData this.data, required this.child, super.key})
    : transform = null;

  /// Changes the inherited theme for [child]: [transform] receives the
  /// parent's data on every build, so changes at the root still flow
  /// through.
  ///
  /// ```dart
  /// CoilTheme.override(
  ///   transform: (t) => t.copyWith(shape: .pill),
  ///   child: MarketingSection(),
  /// )
  /// ```
  const CoilTheme.override({
    required CoilThemeTransform this.transform,
    required this.child,
    super.key,
  }) : data = null;

  /// The theme for the subtree, when not [transform]ing the parent's.
  final CoilThemeData? data;

  /// Derives the subtree's theme from the parent's.
  final CoilThemeTransform? transform;

  /// The subtree.
  final Widget child;

  /// The theme at [context] before high contrast: the nearest theme's data,
  /// else the default for the platform brightness.
  static CoilThemeData _raw(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_InheritedCoilTheme>();
    if (inherited != null) return inherited.data;
    return MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
        ? CoilThemeData.dark
        : CoilThemeData.light;
  }

  /// The theme at [context], resolved for high contrast when the platform
  /// asks for it (`MediaQuery.highContrastOf`).
  static CoilThemeData of(BuildContext context) {
    final data = _raw(context);
    return MediaQuery.maybeHighContrastOf(context) ?? false
        ? data.highContrast()
        : data;
  }

  /// The motion tokens at [context]: [override] (a component's `motion:`)
  /// or the theme's, made [CoilMotion.reduced] when the platform asks for
  /// reduced motion. Reduced motion is always applied last.
  ///
  /// Read it where an animation starts and pass it to that animation, so
  /// runtime changes apply to the next one.
  static CoilMotion motionOf(BuildContext context, {CoilMotion? override}) {
    final motion = override ?? of(context).motion;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? motion.reduced()
        : motion;
  }

  /// The tier at [context]: the nearest [CoilAdaptiveScope]'s, else the
  /// theme's, else the platform's.
  static CoilTier tierOf(BuildContext context) =>
      CoilAdaptiveScope.maybeTierOf(context) ??
      of(context).tier ??
      CoilTier.forPlatform(defaultTargetPlatform);

  /// The metrics at [context]: for [tierOf] and [size] if given, else the
  /// nearest [CoilAdaptiveScope]'s size, else [CoilSize.regular].
  static CoilMetrics metricsOf(BuildContext context, {CoilSize? size}) =>
      CoilMetrics.resolve(
        tierOf(context),
        size ?? CoilAdaptiveScope.maybeSizeOf(context) ?? CoilSize.regular,
      );

  @override
  Widget build(BuildContext context) {
    final resolved = data ?? transform!(_raw(context));
    return _InheritedCoilTheme(
      data: resolved,
      child: Builder(
        builder: (context) {
          final theme = of(context);
          final metrics = metricsOf(context);
          return DefaultTextStyle(
            style: theme.typography.style(
              metrics.body,
              color: theme.colors.foreground,
            ),
            child: DefaultSelectionStyle(
              cursorColor: theme.colors.foreground,
              selectionColor: theme.colors.brand.withValues(alpha: 0.3),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _InheritedCoilTheme extends InheritedTheme {
  const _InheritedCoilTheme({required this.data, required super.child});

  final CoilThemeData data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      CoilTheme(data: data, child: child);

  @override
  bool updateShouldNotify(_InheritedCoilTheme oldWidget) =>
      oldWidget.data != data;
}
