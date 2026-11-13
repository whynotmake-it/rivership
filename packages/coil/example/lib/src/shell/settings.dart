import 'package:coil/coil.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
/// [MediaQuery] and [Directionality], the theme through [CoilTheme], the tier
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
          data: brightness == Brightness.dark
              ? CoilThemeData.dark
              : CoilThemeData.light,
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
