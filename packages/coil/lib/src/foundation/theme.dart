import 'package:coil/src/foundation/adaptive.dart';
import 'package:coil/src/foundation/color_mix.dart';
import 'package:coil/src/foundation/colors.dart';
import 'package:coil/src/foundation/focus_ring_theme.dart';
import 'package:coil/src/foundation/haptics.dart';
import 'package:coil/src/foundation/icons.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/plasticity.dart';
import 'package:coil/src/foundation/shape.dart';
import 'package:coil/src/foundation/style.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Marks a copyWith argument that wasn't passed.
const Object _keep = Object();

/// Changes a parent theme for a subtree. See [CoilTheme.override].
typedef CoilThemeTransform = CoilThemeData Function(CoilThemeData parent);

/// Every token coil components read, as one runtime-changeable object.
@immutable
class CoilThemeData with Diagnosticable {
  /// Creates theme data. Unset fields keep coil's defaults.
  const CoilThemeData({
    this.colors = CoilColors.light,
    this.shape = CoilShape.rounded,
    this.metrics = const CoilMetricsTable(),
    this.tier,
    this.motion = const CoilMotion(),
    this.typography = CoilTypography.platform,
    this.focusRing = const CoilFocusRingTheme(),
    this.haptics,
    this.controlCursor = SystemMouseCursors.basic,
    this.plasticity = CoilPlasticity.flat,
    this.icons = const CoilIcons(),
    this.components = const {},
  });

  /// The light theme.
  static const light = CoilThemeData();

  /// The dark theme.
  static const dark = CoilThemeData(colors: CoilColors.dark);

  /// The color tokens.
  final CoilColors colors;

  /// The corner shape family.
  final CoilShape shape;

  /// The size tokens for every tier and size step. Components read the
  /// entry for theirs with [CoilTheme.metricsOf].
  final CoilMetricsTable metrics;

  /// The size tier, or null to latch it from the platform
  /// ([CoilTier.forPlatform]). A [CoilAdaptiveScope] overrides it.
  final CoilTier? tier;

  /// The motion tokens. Components read them on every animation, so a
  /// change applies to the next one.
  final CoilMotion motion;

  /// The text roles for every tier and size step. Read them with
  /// [CoilTheme.textOf]. Defaults to the platform font; coil bundles none.
  final CoilTypography typography;

  /// How focus rings look.
  final CoilFocusRingTheme focusRing;

  /// Which haptic each event plays, or null for the platform's conventions
  /// ([CoilHaptics.platform]). [CoilHaptics.none] turns them off.
  final CoilHaptics? haptics;

  /// The mouse cursor over an enabled control that acts on a click:
  /// buttons, rows, toggles, cards. Defaults to the arrow, the desktop
  /// convention. [SystemMouseCursors.click] gives every control the web's
  /// pointing hand. Links always use the pointing hand, text the I-beam,
  /// and disabled controls the cursor beneath them.
  final MouseCursor controlCursor;

  /// How lit interactive controls look: [CoilPlasticity.flat] (the default)
  /// paints no lighting; a higher `amount` ([CoilPlasticity.subtle] is 0.5,
  /// 1 the most) adds a gradient edge, a top highlight, a sheen and a drop
  /// shadow that respond to hover and press. Components read it through
  /// their style's `plasticity`, so one component type can differ with
  /// [withComponentStyle], and resolve it with [CoilTheme.reliefOf].
  final CoilPlasticity plasticity;

  /// The icons components show, by role: an app's own icon set in place of
  /// coil's drawn glyphs. Roles left null keep coil's; a component's own
  /// slot wins over this. Add a partial set with
  /// `theme.copyWith(icons: theme.icons.merge(mine))`. See [CoilIcons].
  final CoilIcons icons;

  /// Per-component-type style overrides, keyed by style type:
  /// `{CoilButtonStyle: CoilButtonStyle(radius: 12)}`. Prefer
  /// [withComponentStyle], which merges with an existing entry. Components
  /// read them with [CoilTheme.styleOf].
  ///
  /// A style's `motions` sets springs for that component's animated parts
  /// app-wide: `CoilSwitchStyle(motions: {CoilSwitchTrack.thumb:
  /// const Motion.bouncySpring()})`. A component's own `motions:` win over
  /// them; they win over the tokens.
  final Map<Type, CoilComponentStyle<dynamic>> components;

  /// The style override for type [S], if any.
  S? componentStyle<S extends CoilComponentStyle<S>>() => components[S] as S?;

  /// A copy with [style] merged onto the existing entry for its type.
  CoilThemeData withComponentStyle<S extends CoilComponentStyle<S>>(
    S style,
  ) => copyWith(
    components: {
      ...components,
      S: componentStyle<S>()?.merge(style) ?? style,
    },
  );

  /// This theme for high contrast: [CoilColors.highContrast], and a 2 px
  /// focus ring in a color with at least 3:1 contrast against the
  /// background. [CoilTheme.of] applies it when `MediaQuery.highContrastOf`
  /// is true.
  CoilThemeData highContrast() {
    final contrasted = colors.highContrast();
    return copyWith(
      colors: contrasted,
      focusRing: focusRing.copyWith(
        width: 2,
        color: CoilColorMix.ensureContrast(
          focusRing.colorOf(contrasted),
          contrasted.background,
          3,
        ),
      ),
    );
  }

  /// This theme for the platform's bold text setting: every text role
  /// lighter than semibold becomes semibold (a variable font's `wght` axis
  /// too), as DESIGN.md asks. [CoilTheme.of] applies it when
  /// `MediaQuery.boldTextOf` is true.
  CoilThemeData boldText() => copyWith(
    typography: typography.map((role) {
      final weight = role.fontWeight ?? FontWeight.normal;
      if (weight.value >= FontWeight.w600.value) return role;
      return role.copyWith(
        fontWeight: FontWeight.w600,
        fontVariations: role.fontVariations == null
            ? null
            : [
                for (final axis in role.fontVariations!)
                  if (axis.axis == 'wght' && axis.value < 600)
                    const FontVariation.weight(600)
                  else
                    axis,
              ],
      );
    }),
  );

  /// Light or dark.
  Brightness get brightness => colors.brightness;

  /// Returns a copy with the given fields replaced. Pass `tier: null` or
  /// `haptics: null` to go back to the platform's.
  CoilThemeData copyWith({
    CoilColors? colors,
    CoilShape? shape,
    CoilMetricsTable? metrics,
    Object? tier = _keep,
    CoilMotion? motion,
    CoilTypography? typography,
    CoilFocusRingTheme? focusRing,
    Object? haptics = _keep,
    MouseCursor? controlCursor,
    CoilPlasticity? plasticity,
    CoilIcons? icons,
    Map<Type, CoilComponentStyle<dynamic>>? components,
  }) => CoilThemeData(
    colors: colors ?? this.colors,
    shape: shape ?? this.shape,
    metrics: metrics ?? this.metrics,
    tier: identical(tier, _keep) ? this.tier : tier as CoilTier?,
    motion: motion ?? this.motion,
    typography: typography ?? this.typography,
    focusRing: focusRing ?? this.focusRing,
    haptics: identical(haptics, _keep) ? this.haptics : haptics as CoilHaptics?,
    controlCursor: controlCursor ?? this.controlCursor,
    plasticity: plasticity ?? this.plasticity,
    icons: icons ?? this.icons,
    components: components ?? this.components,
  );

  /// Interpolates two themes, for animated theme changes. Colors, text
  /// styles, motion and the focus ring blend; everything else (icons too)
  /// switches at the midpoint.
  // A static lerp, like Color.lerp and TextStyle.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilThemeData lerp(CoilThemeData a, CoilThemeData b, double t) =>
      CoilThemeData(
        colors: CoilColors.lerp(a.colors, b.colors, t),
        shape: t < 0.5 ? a.shape : b.shape,
        metrics: t < 0.5 ? a.metrics : b.metrics,
        tier: t < 0.5 ? a.tier : b.tier,
        motion: CoilMotion.lerp(a.motion, b.motion, t),
        typography: CoilTypography.lerp(a.typography, b.typography, t),
        focusRing: CoilFocusRingTheme.lerp(a.focusRing, b.focusRing, t),
        haptics: t < 0.5 ? a.haptics : b.haptics,
        controlCursor: t < 0.5 ? a.controlCursor : b.controlCursor,
        plasticity: CoilPlasticity.lerp(a.plasticity, b.plasticity, t),
        icons: t < 0.5 ? a.icons : b.icons,
        components: t < 0.5 ? a.components : b.components,
      );

  @override
  bool operator ==(Object other) =>
      other is CoilThemeData &&
      other.colors == colors &&
      other.shape == shape &&
      other.metrics == metrics &&
      other.tier == tier &&
      other.motion == motion &&
      other.typography == typography &&
      other.focusRing == focusRing &&
      other.haptics == haptics &&
      other.controlCursor == controlCursor &&
      other.plasticity == plasticity &&
      other.icons == icons &&
      mapEquals(other.components, components);

  @override
  int get hashCode => Object.hash(
    colors,
    shape,
    metrics,
    tier,
    motion,
    typography,
    focusRing,
    haptics,
    controlCursor,
    plasticity,
    icons,
    Object.hashAllUnordered(
      components.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('colors', colors))
      ..add(DiagnosticsProperty('shape', shape))
      ..add(EnumProperty('tier', tier, defaultValue: null))
      ..add(DiagnosticsProperty('motion', motion))
      ..add(DiagnosticsProperty('haptics', haptics, defaultValue: null))
      ..add(
        DiagnosticsProperty(
          'controlCursor',
          controlCursor,
          defaultValue: SystemMouseCursors.basic,
        ),
      )
      ..add(
        DiagnosticsProperty(
          'plasticity',
          plasticity,
          defaultValue: CoilPlasticity.flat,
        ),
      )
      ..add(
        DiagnosticsProperty('icons', icons, defaultValue: const CoilIcons()),
      );
  }
}

/// Provides [CoilThemeData] to a subtree.
///
/// Optional: without one, components use [CoilThemeData.light] or
/// [CoilThemeData.dark] by platform brightness. Works under any
/// `WidgetsApp`; it also sets a [DefaultTextStyle] and
/// [DefaultSelectionStyle] so plain [Text] in slots matches the system.
///
/// Resolution, lowest to highest: package defaults,
/// the platform tier, the root theme, subtree [CoilTheme.override]s, a
/// component's own `motion:`, high contrast ([of]), reduced motion
/// ([motionOf]).
class CoilTheme extends StatelessWidget {
  /// Provides [data] to [child].
  const CoilTheme({
    required CoilThemeData this.data,
    required this.child,
    super.key,
  }) : transform = null;

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

  /// High-contrast versions, made once per theme data.
  static final _highContrast = Expando<CoilThemeData>('CoilTheme.highContrast');

  /// Versions without plasticity, for elevated surfaces, made once per
  /// theme data.
  static final _onSurface = Expando<CoilThemeData>('CoilTheme.onSurface');

  /// [CoilThemeData.boldText] of each theme data.
  static final _boldText = Expando<CoilThemeData>('CoilTheme.boldText');

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

  /// The theme at [context], resolved for bold text and high contrast when
  /// the platform asks for them (`MediaQuery.boldTextOf`,
  /// `MediaQuery.highContrastOf`). Inside an elevated
  /// [CoilPlasticityScope] (a card, popover, dialog or sheet), its
  /// plasticity is [CoilPlasticity.flat]: controls there aren't lit.
  static CoilThemeData of(BuildContext context) {
    var data = _raw(context);
    if (!data.plasticity.isFlat && CoilPlasticityScope.elevatedOf(context)) {
      data = _onSurface[data] ??= data.copyWith(
        plasticity: CoilPlasticity.flat,
      );
    }
    if (MediaQuery.maybeBoldTextOf(context) ?? false) {
      data = _boldText[data] ??= data.boldText();
    }
    return MediaQuery.maybeHighContrastOf(context) ?? false
        ? _highContrast[data] ??= data.highContrast()
        : data;
  }

  /// The lighting of a [role] shape at [context], or null for none: the
  /// theme's plasticity (or [override], a component style's `plasticity`)
  /// resolved for the theme's brightness. See [CoilPlasticity.resolve] for
  /// [hover], [press] and [enabled].
  ///
  /// Controls read the plasticity [of] returns, which is flat on an
  /// elevated surface.
  static CoilRelief? reliefOf(
    BuildContext context,
    CoilReliefRole role, {
    CoilPlasticity? override,
    double hover = 0,
    double press = 0,
    bool enabled = true,
  }) {
    final theme = of(context);
    return (override ?? theme.plasticity).resolve(
      role,
      theme.brightness,
      hover: hover,
      press: press,
      enabled: enabled,
    );
  }

  /// The theme's plasticity at [context] as set, before an elevated
  /// [CoilPlasticityScope] flattens it. Controls read [of]'s instead; a
  /// surface reads this one for [CoilPlasticity.flattenAbove].
  static CoilPlasticity plasticityOf(BuildContext context) =>
      _raw(context).plasticity;

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

  /// The theme's style override for type [S] at [context], if any. A
  /// component computes its style as
  /// `S.fallback(...).merge(CoilTheme.styleOf<S>(context))` and then merges
  /// its own `style:` on top.
  static S? styleOf<S extends CoilComponentStyle<S>>(BuildContext context) =>
      of(context).componentStyle<S>();

  /// The motion for one [track] of a component at [context]: the
  /// component's own `motions:` entry ([instance]), else its resolved
  /// style's `motions` entry ([styled]: the component's `style:` merged
  /// over the theme's [CoilThemeData.components] entry), else [token]
  /// (already resolved through [motionOf]). Maps compare by value, so a
  /// rebuilt literal never redirects an animation. Under reduced motion a
  /// [spatial] track is instant whatever was configured.
  static Motion trackMotionOf(
    BuildContext context,
    Track<Object> track, {
    required Map<Track<Object>, Motion>? instance,
    required Map<Track<Object>, Motion>? styled,
    required Motion token,
    bool spatial = true,
  }) {
    final custom = instance?[track] ?? styled?[track];
    if (custom == null) return token;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduced && spatial ? const Motion.instant() : custom;
  }

  /// The text roles at [context]: the theme's typography for [tierOf] and
  /// the size step of the nearest [CoilAdaptiveScope], in the foreground
  /// color, with `muted`, `brand` and `destructive` variants.
  ///
  /// ```dart
  /// final text = CoilTheme.textOf(context);
  /// Text('Synced 2 min ago', style: text.muted.caption);
  /// ```
  static CoilTextTheme textOf(BuildContext context) {
    final theme = of(context);
    return theme.typography.colored(
      tierOf(context),
      CoilAdaptiveScope.maybeSizeOf(context) ?? CoilSize.regular,
      theme.colors,
    );
  }

  /// The corner radii at [context]: the theme's shape at [tierOf].
  static CoilRadii radiiOf(BuildContext context) =>
      of(context).shape.radii(tierOf(context));

  /// The tier at [context]: the nearest [CoilAdaptiveScope]'s, else the
  /// theme's, else the platform's ([platformOf]).
  static CoilTier tierOf(BuildContext context) =>
      CoilAdaptiveScope.maybeTierOf(context) ??
      of(context).tier ??
      CoilTier.forPlatform(platformOf(context));

  /// The platform whose conventions apply at [context]: the nearest
  /// [CoilAdaptiveScope]'s pin, else [defaultTargetPlatform].
  static TargetPlatform platformOf(BuildContext context) =>
      CoilAdaptiveScope.maybePlatformOf(context) ?? defaultTargetPlatform;

  /// The theme's metrics at [context]: for [tier] if given, else [tierOf];
  /// for [size] if given, else the nearest [CoilAdaptiveScope]'s size, else
  /// [CoilSize.regular]. Read every size through this, so an app's metrics
  /// reach every component.
  static CoilMetrics metricsOf(
    BuildContext context, {
    CoilSize? size,
    CoilTier? tier,
  }) => of(context).metrics.resolve(
    tier ?? tierOf(context),
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
          return DefaultTextStyle(
            style: textOf(context).body,
            child: DefaultSelectionStyle(
              cursorColor: theme.colors.brand,
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
