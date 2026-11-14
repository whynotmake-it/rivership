import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Light, dark, or whatever the platform says.
enum CatalogThemeMode { system, light, dark }

/// The size tier: latched from the platform, or pinned.
enum CatalogTier {
  auto('Auto', null),
  pointer('Pointer', CoilTier.pointer),
  touch('Touch', CoilTier.touch);

  const CatalogTier(this.label, this.tier);

  final String label;

  /// The pinned tier, or null to latch it from the platform.
  final CoilTier? tier;
}

/// The text scale: the platform's, or a fixed factor.
enum CatalogTextScale {
  system('System', null),
  x1('100%', 1),
  x1_5('150%', 1.5),
  x2('200%', 2);

  const CatalogTextScale(this.label, this.factor);

  final String label;

  /// The factor, or null to follow the platform.
  final double? factor;
}

/// The font family: the bundled Inter, the platform's UI font, or the
/// platform's monospace font. None of them loads anything from the network.
enum CatalogFont {
  inter('Inter'),
  system('System'),
  monospace('Monospace');

  const CatalogFont(this.label);

  final String label;

  /// The typography theme data for this font on [platform].
  CoilTypography typography(TargetPlatform platform) => switch (this) {
    inter => const CoilTypography(),
    system => CoilTypography.platform,
    monospace => CoilTypography(
      fontFamily: switch (platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
        TargetPlatform.windows => 'Consolas',
        TargetPlatform.linux => 'DejaVu Sans Mono',
        TargetPlatform.android || TargetPlatform.fuchsia => 'monospace',
      },
      fontPackage: null,
    ),
  };
}

/// The brand color, the one accent coil uses (switch track, focus ring,
/// slider fill, text selection).
enum CatalogBrand {
  blue('Blue', Color(0xFF6B97FF)),
  violet('Violet', Color(0xFF8B5CF6)),
  teal('Teal', Color(0xFF14B8A6)),
  orange('Orange', Color(0xFFF97316)),
  pink('Pink', Color(0xFFEC4899)),
  graphite('Graphite', Color(0xFF71717A));

  const CatalogBrand(this.label, this.color);

  final String label;
  final Color color;
}

/// The corner shape family: one of coil's three, or a custom item radius.
enum CatalogShape {
  rounded('Rounded'),
  pill('Pill'),
  sharp('Sharp'),
  custom('Custom');

  const CatalogShape(this.label);

  final String label;
}

/// The spacing of every control.
enum CatalogSpacing {
  standard('Standard'),
  roomy('Roomy');

  const CatalogSpacing(this.label);

  final String label;

  /// The metrics table for this spacing.
  CoilMetricsTable get metrics {
    const table = CoilMetricsTable();
    if (this == standard) return table;
    return table.copyWith(
      pointer: _roomy(table.pointer),
      pointerCompact: _roomy(table.pointerCompact),
      touch: _roomy(table.touch),
      touchCompact: _roomy(table.touchCompact),
    );
  }

  /// 4 px taller controls with 4 px more padding. The item padding grows
  /// with the control padding, so popup rows still line up with their
  /// trigger (DESIGN.md §4.2's alignment rule).
  static CoilMetrics _roomy(CoilMetrics m) => m.copyWith(
    controlHeight: m.controlHeight + 4,
    controlPaddingX: m.controlPaddingX + 4,
    itemPaddingX: m.itemPaddingX + 4,
    buttonPaddingX: m.buttonPaddingX + 4,
    buttonIconPaddingX: m.buttonIconPaddingX + 4,
    gap: m.gap + 2,
    buttonGap: m.buttonGap + 2,
  );
}

/// The feel of every spring.
enum CatalogMotion {
  standard('Standard'),
  snappy('Snappy'),
  bouncy('Bouncy');

  const CatalogMotion(this.label);

  final String label;

  /// The motion tokens for this feel.
  CoilMotion get motion => switch (this) {
    standard => const CoilMotion(),
    snappy => const CoilMotion(
      quick: CupertinoMotion(duration: Duration(milliseconds: 70)),
      quickExit: CupertinoMotion(duration: Duration(milliseconds: 60)),
      standard: CupertinoMotion(duration: Duration(milliseconds: 120)),
      standardExit: CupertinoMotion(duration: Duration(milliseconds: 100)),
      gentle: CupertinoMotion(duration: Duration(milliseconds: 220)),
      gentleExit: CupertinoMotion(duration: Duration(milliseconds: 180)),
    ),
    bouncy => const CoilMotion(
      quick: CupertinoMotion(
        duration: Duration(milliseconds: 160),
        bounce: 0.2,
      ),
      standard: CupertinoMotion(
        duration: Duration(milliseconds: 300),
        bounce: 0.3,
      ),
      gentle: CupertinoMotion(
        duration: Duration(milliseconds: 450),
        bounce: 0.3,
      ),
    ),
  };
}

/// The catalog's preview controls. Each one maps onto a real platform input
/// (MediaQuery, Directionality, the theme, the adaptive scope), so a
/// component sees exactly what it would see on a device set up that way.
class CatalogSettings extends ChangeNotifier {
  CatalogSettings({this.slowMoFactor = 5});

  /// How much slower everything runs while [slowMo] is on.
  final double slowMoFactor;

  CatalogThemeMode get themeMode => _themeMode;
  CatalogThemeMode _themeMode = CatalogThemeMode.system;
  set themeMode(CatalogThemeMode value) => _set(() => _themeMode = value);

  CatalogTier get tier => _tier;
  CatalogTier _tier = CatalogTier.auto;
  set tier(CatalogTier value) => _set(() => _tier = value);

  CatalogTextScale get textScale => _textScale;
  CatalogTextScale _textScale = CatalogTextScale.system;
  set textScale(CatalogTextScale value) => _set(() => _textScale = value);

  bool get rtl => _rtl;
  bool _rtl = false;
  set rtl(bool value) => _set(() => _rtl = value);

  /// Forces high contrast on. Off follows the platform.
  bool get highContrast => _highContrast;
  bool _highContrast = false;
  set highContrast(bool value) => _set(() => _highContrast = value);

  /// Forces reduced motion on. Off follows the platform.
  bool get reducedMotion => _reducedMotion;
  bool _reducedMotion = false;
  set reducedMotion(bool value) => _set(() => _reducedMotion = value);

  /// Slows every animation down by [slowMoFactor], through Flutter's own
  /// [timeDilation], so Motor springs keep their shape, just stretched.
  bool get slowMo => _slowMo;
  bool _slowMo = false;
  set slowMo(bool value) {
    _set(() => _slowMo = value);
    timeDilation = value ? slowMoFactor : 1;
  }

  /// The font family.
  CatalogFont get font => _font;
  CatalogFont _font = CatalogFont.inter;
  set font(CatalogFont value) => _set(() => _font = value);

  /// The brand color.
  CatalogBrand get brand => _brand;
  CatalogBrand _brand = CatalogBrand.blue;
  set brand(CatalogBrand value) => _set(() => _brand = value);

  /// The neutral tone's Oklch hue, in degrees.
  double get neutralHue => _neutralHue;
  double _neutralHue = 0;
  set neutralHue(double value) => _set(() => _neutralHue = value);

  /// The neutral tone's Oklch chroma: 0 is pure grey.
  double get neutralChroma => _neutralChroma;
  double _neutralChroma = 0;
  set neutralChroma(double value) => _set(() => _neutralChroma = value);

  /// The corner shape family.
  CatalogShape get shape => _shape;
  CatalogShape _shape = CatalogShape.rounded;
  set shape(CatalogShape value) => _set(() => _shape = value);

  /// The pointer-tier item radius while [shape] is [CatalogShape.custom].
  double get customRadius => _customRadius;
  double _customRadius = 8;
  set customRadius(double value) => _set(() => _customRadius = value);

  CatalogSpacing get spacing => _spacing;
  CatalogSpacing _spacing = CatalogSpacing.standard;
  set spacing(CatalogSpacing value) => _set(() => _spacing = value);

  CatalogMotion get motion => _motion;
  CatalogMotion _motion = CatalogMotion.standard;
  set motion(CatalogMotion value) => _set(() => _motion = value);

  /// A 2 px focus ring instead of 1 px. High contrast always uses 2.
  bool get boldFocusRing => _boldFocusRing;
  bool _boldFocusRing = false;
  set boldFocusRing(bool value) => _set(() => _boldFocusRing = value);

  /// Turns coil's haptics off. On follows the platform's conventions.
  bool get hapticsOff => _hapticsOff;
  bool _hapticsOff = false;
  set hapticsOff(bool value) => _set(() => _hapticsOff = value);

  /// The coil theme these settings describe for [brightness], built through
  /// the public theme API exactly as an app would build its own.
  CoilThemeData theme(Brightness brightness, {TargetPlatform? platform}) {
    final base = brightness == Brightness.dark
        ? CoilThemeData.dark
        : CoilThemeData.light;
    return base.copyWith(
      colors: CoilColors.fromSeed(
        brightness: brightness,
        brand: brand.color,
        neutralHue: neutralHue,
        neutralChroma: neutralChroma,
      ),
      typography: font.typography(platform ?? defaultTargetPlatform),
      shape: _coilShape,
      metrics: spacing.metrics,
      motion: motion.motion,
      focusRingWidth: boldFocusRing ? 2 : 1,
      haptics: hapticsOff ? CoilHaptics.none : null,
    );
  }

  CoilShape get _coilShape => switch (shape) {
    CatalogShape.rounded => CoilShape.rounded,
    CatalogShape.pill => CoilShape.pill,
    CatalogShape.sharp => CoilShape.sharp,
    CatalogShape.custom => customShape(customRadius),
  };

  /// A shape family from one pointer item radius, nested the way coil's
  /// own families are (DESIGN.md §5): touch items 2 px rounder, containers
  /// one popup inset larger than their items, focus rings 2 px outside.
  static CoilShape customShape(double item) => CoilShape(
    pointer: CoilRadii(
      item: item,
      container: item + CoilMetrics.pointer.popupInset,
      focusRing: item + 2,
    ),
    touch: CoilRadii(
      item: item + 2,
      container: item + 2 + CoilMetrics.touch.popupInset,
      focusRing: item + 4,
    ),
  );

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_slowMo) timeDilation = 1;
    super.dispose();
  }
}

/// Provides [CatalogSettings] to the catalog.
class CatalogSettingsScope extends InheritedNotifier<CatalogSettings> {
  const CatalogSettingsScope({
    required CatalogSettings settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);

  static CatalogSettings of(BuildContext context) => maybeOf(context)!;

  static CatalogSettings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CatalogSettingsScope>()
      ?.notifier;
}

/// Applies the [CatalogSettings] above [child]: the platform inputs through
/// [MediaQuery] and [Directionality], the theme through [CoilTheme] (see
/// [CatalogSettings.theme]), the tier
/// through [CoilAdaptiveScope], and the page background.
class CatalogEnvironment extends StatelessWidget {
  const CatalogEnvironment({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    final media = MediaQuery.of(context);
    final brightness = switch (settings.themeMode) {
      CatalogThemeMode.system => media.platformBrightness,
      CatalogThemeMode.light => Brightness.light,
      CatalogThemeMode.dark => Brightness.dark,
    };
    final textScale = settings.textScale.factor;
    return MediaQuery(
      data: media.copyWith(
        platformBrightness: brightness,
        textScaler: textScale == null
            ? media.textScaler
            : TextScaler.linear(textScale),
        highContrast: media.highContrast || settings.highContrast,
        disableAnimations: media.disableAnimations || settings.reducedMotion,
      ),
      child: Directionality(
        textDirection: settings.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: CoilTheme(
          data: settings.theme(brightness),
          child: CoilAdaptiveScope(
            tier: settings.tier.tier,
            child: Builder(
              builder: (context) => ColoredBox(
                color: CoilTheme.of(context).colors.background,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
