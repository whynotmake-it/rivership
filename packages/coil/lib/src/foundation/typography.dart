import 'dart:convert';

import 'package:coil/src/foundation/colors.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart'
    show BuildContext, IconTheme, IconThemeData, MediaQuery;

/// The text roles of one size set, as plain [TextStyle]s.
///
/// [CoilTypography] holds one for each tier and size step. Read the one for
/// a widget's place with `CoilTheme.textOf`, which also puts the theme's
/// foreground color on every role:
///
/// ```dart
/// final text = CoilTheme.textOf(context);
/// Text('Settings', style: text.title);
/// Text('Synced 2 min ago', style: text.muted.caption);
/// ```
///
/// Each role is a [TextStyle] like any other, so `copyWith`, `merge` and
/// [TextStyle.lerp] work on it as usual.
@immutable
class CoilTextTheme with Diagnosticable {
  /// Creates a text theme from its roles.
  const CoilTextTheme({
    required this.display,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.field,
    required this.caption,
    required this.micro,
  }) : _colors = null;

  const CoilTextTheme._(
    this._colors, {
    required this.display,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.field,
    required this.caption,
    required this.micro,
  });

  /// Page titles. Bold.
  final TextStyle display;

  /// Dialog, sheet and card titles. Semibold.
  final TextStyle title;

  /// Chat bubbles, legends and the command input.
  final TextStyle subtitle;

  /// Controls, rows and paragraphs.
  final TextStyle body;

  /// Editable text. On touch, never smaller than 16, below which iOS zooms
  /// into a focused field.
  final TextStyle field;

  /// Descriptions, group labels, tooltips and badges.
  final TextStyle caption;

  /// Counters, compact badges and key caps.
  final TextStyle micro;

  /// The theme's colors, when this text theme came from
  /// [CoilTypography.colored].
  final CoilColors? _colors;

  /// The weight that marks emphasis: the [title]'s. Selected tabs and
  /// rows, and buttons, set their label in it, so it follows the
  /// typography.
  FontWeight get emphasis => title.fontWeight ?? FontWeight.w600;

  /// The roles in `--muted-foreground`, for secondary text.
  CoilTextTheme get muted => _withColor(_requireColors.mutedForeground);

  /// The roles in the brand color.
  CoilTextTheme get brand => _withColor(_requireColors.brand);

  /// The roles in `--destructive`.
  CoilTextTheme get destructive => _withColor(_requireColors.destructive);

  CoilColors get _requireColors {
    assert(
      _colors != null,
      'Only a CoilTextTheme from CoilTheme.textOf(context) knows the '
      "theme's colors. Use copyWith(color: …) on a role instead.",
    );
    return _colors!;
  }

  CoilTextTheme _withColor(Color color, [CoilColors? colors]) => _map(
    (style) => style.copyWith(color: color),
    colors: colors ?? _colors,
  );

  CoilTextTheme _map(
    TextStyle Function(TextStyle style) transform, {
    CoilColors? colors,
  }) => CoilTextTheme._(
    colors ?? _colors,
    display: transform(display),
    title: transform(title),
    subtitle: transform(subtitle),
    body: transform(body),
    field: transform(field),
    caption: transform(caption),
    micro: transform(micro),
  );

  /// Every role with [transform] applied, such as a color or a feature for
  /// all of them.
  CoilTextTheme map(TextStyle Function(TextStyle style) transform) =>
      _map(transform);

  /// Returns a copy with the given roles replaced.
  CoilTextTheme copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? field,
    TextStyle? caption,
    TextStyle? micro,
  }) => CoilTextTheme._(
    _colors,
    display: display ?? this.display,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    body: body ?? this.body,
    field: field ?? this.field,
    caption: caption ?? this.caption,
    micro: micro ?? this.micro,
  );

  /// Interpolates every role with [TextStyle.lerp], for animated theme
  /// changes.
  // A static lerp, like TextStyle.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilTextTheme lerp(CoilTextTheme a, CoilTextTheme b, double t) {
    if (identical(a, b)) return a;
    TextStyle l(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return CoilTextTheme._(
      t < 0.5 ? a._colors : b._colors,
      display: l(a.display, b.display),
      title: l(a.title, b.title),
      subtitle: l(a.subtitle, b.subtitle),
      body: l(a.body, b.body),
      field: l(a.field, b.field),
      caption: l(a.caption, b.caption),
      micro: l(a.micro, b.micro),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoilTextTheme &&
      other.display == display &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.body == body &&
      other.field == field &&
      other.caption == caption &&
      other.micro == micro &&
      other._colors == _colors;

  @override
  int get hashCode =>
      Object.hash(display, title, subtitle, body, field, caption, micro);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    for (final (name, style) in [
      ('display', display),
      ('title', title),
      ('subtitle', subtitle),
      ('body', body),
      ('field', field),
      ('caption', caption),
      ('micro', micro),
    ]) {
      properties.add(DiagnosticsProperty<TextStyle>(name, style));
    }
  }
}

/// The text of the whole system, as theme data
/// (`CoilThemeData.typography`): the roles of [CoilTextTheme] for each tier
/// and size step.
///
/// The default is the platform's UI font (San Francisco on Apple platforms,
/// Roboto on Android) on coil's type scale. coil bundles no font. For a
/// font of your own, put it under the scale with [CoilTypography.from]:
///
/// ```dart
/// CoilTypography.from(const TextStyle(fontFamily: 'Brand'))
/// ```
///
/// [CoilTypography.allo] and [CoilTypography.inter] are tuned for those
/// fonts. The app bundles the font itself, and in debug builds coil reports
/// a font that a typography names but the app doesn't bundle.
///
/// Every role's optical size (`opsz`) follows its font size, as CSS does on
/// its own, unless the base style sets `opsz`. Fonts without the axis
/// ignore it.
@immutable
class CoilTypography with Diagnosticable {
  /// Creates typography from a text theme per tier and size step. The
  /// default is the platform font on coil's type scale.
  const CoilTypography({
    this.pointer = _pointer,
    this.pointerCompact = _pointerCompact,
    this.touch = _touch,
    this.touchCompact = _touchCompact,
  });

  /// coil's type scale on [base]: [base]'s family, axes and features under
  /// every role, and each role's size, line height and weight on top.
  ///
  /// The axes of [base] and of a role combine by tag, the role's winning.
  /// Every role gets `opsz` at its font size, unless [base] sets `opsz`.
  factory CoilTypography.from(
    TextStyle base, {
    CoilTypography scale = CoilTypography.platform,
  }) => scale._map((role) => _place(base, role));

  /// [Allo](https://allo.joshpuckett.me), a friendly variable sans, with
  /// its axes and stylistic sets.
  ///
  /// The app bundles the variable font (`AlloVariable.ttf`, SIL Open Font
  /// License) under [family]:
  ///
  /// ```yaml
  /// flutter:
  ///   fonts:
  ///     - family: Allo
  ///       fonts:
  ///         - asset: fonts/AlloVariable.ttf
  /// ```
  ///
  /// * [roundness] is the `ROND` axis: 0 sharp, 50 friendly, 100 round.
  /// * [opticalSize] pins the `opsz` axis (9–32). By default it follows the
  ///   font size up to 14, where Allo opens its spacing up for small text,
  ///   and rises half as fast above, since Allo's headline design tightens
  ///   quickly. Pin it to 14 for the text cut everywhere.
  ///
  /// Each role also gets a little letter spacing (up to 0.006em, none
  /// below 13), so Allo sets as evenly across the scale as the Inter it was
  /// tuned on.
  /// * [singleStoryA] (`ss01`) draws a single-story a.
  /// * [disambiguate] (`ss02`) draws a serifed I, a tailed l, a footed 1 and
  ///   a slashed zero, so they can't be mistaken for each other.
  /// * [openFigures] (`ss03`) opens the 4, 6 and 9.
  ///
  /// Contextual alternates stay on, as the font intends: typed arrows
  /// (`->`) and punctuation that lifts beside capitals.
  factory CoilTypography.allo({
    String family = 'Allo',
    String? package,
    double roundness = 50,
    double? opticalSize,
    bool singleStoryA = false,
    bool disambiguate = false,
    bool openFigures = false,
  }) {
    assert(roundness >= 0 && roundness <= 100, 'roundness is 0–100');
    return CoilTypography.from(
      TextStyle(
        fontFamily: family,
        package: package,
        fontVariations: [
          FontVariation('ROND', roundness),
          FontVariation.opticalSize(opticalSize ?? 14),
        ],
        fontFeatures: [
          if (singleStoryA) const FontFeature.enable('ss01'),
          if (disambiguate) const FontFeature.enable('ss02'),
          if (openFigures) const FontFeature.enable('ss03'),
        ],
      ),
    ).map((role) {
      final size = role.fontSize ?? 14;
      return role.copyWith(
        letterSpacing: _alloTracking(size) * size,
        fontVariations: [
          for (final axis in [...?role.fontVariations])
            if (axis.axis != 'opsz') axis,
          FontVariation.opticalSize(opticalSize ?? _alloOpticalSize(size)),
        ],
      );
    });
  }

  /// [Inter](https://rsms.me/inter), a neutral variable sans for screens.
  ///
  /// The app bundles the variable font (`InterVariable.ttf`, SIL Open Font
  /// License) under [family]:
  ///
  /// ```yaml
  /// flutter:
  ///   fonts:
  ///     - family: Inter
  ///       fonts:
  ///         - asset: fonts/InterVariable.ttf
  /// ```
  ///
  /// * [opticalSize] pins the `opsz` axis (14–32). By default it follows the
  ///   font size, so titles and display text use Inter Display's tighter
  ///   spacing.
  /// * [disambiguate] (`ss02`) draws letters and figures that can't be
  ///   mistaken for each other, such as a tailed l and a slashed zero.
  /// * [openFigures] (`ss01`) opens the 4, 6 and 9.
  factory CoilTypography.inter({
    String family = 'Inter',
    String? package,
    double? opticalSize,
    bool disambiguate = false,
    bool openFigures = false,
  }) => CoilTypography.from(
    TextStyle(
      fontFamily: family,
      package: package,
      fontVariations: [
        if (opticalSize != null) FontVariation.opticalSize(opticalSize),
      ],
      fontFeatures: [
        if (openFigures) const FontFeature.enable('ss01'),
        if (disambiguate) const FontFeature.enable('ss02'),
      ],
    ),
  );

  /// The platform's UI font on coil's type scale. The default.
  static const platform = CoilTypography();

  /// The pointer tier, regular size step.
  final CoilTextTheme pointer;

  /// The pointer tier, compact size step.
  final CoilTextTheme pointerCompact;

  /// The touch tier, regular size step.
  final CoilTextTheme touch;

  /// The touch tier, compact size step.
  final CoilTextTheme touchCompact;

  /// The text theme for [tier] and [size].
  /// The text theme for [tier] and [size] in [colors]: every role in the
  /// foreground color, with the `muted`, `brand` and `destructive`
  /// variants. `CoilTheme.textOf` reads it for a widget's place.
  CoilTextTheme colored(CoilTier tier, CoilSize size, CoilColors colors) {
    assert(() {
      debugCheckFontsBundled();
      return true;
    }(), 'never fails: it only reports a font the app does not bundle');
    return resolve(tier, size)._withColor(colors.foreground, colors);
  }

  /// The text theme for [tier] and [size], without colors.
  CoilTextTheme resolve(CoilTier tier, CoilSize size) => switch ((tier, size)) {
    (CoilTier.pointer, CoilSize.regular) => pointer,
    (CoilTier.pointer, CoilSize.compact) => pointerCompact,
    (CoilTier.touch, CoilSize.regular) => touch,
    (CoilTier.touch, CoilSize.compact) => touchCompact,
  };

  CoilTypography _map(TextStyle Function(TextStyle role) transform) =>
      CoilTypography(
        pointer: pointer.map(transform),
        pointerCompact: pointerCompact.map(transform),
        touch: touch.map(transform),
        touchCompact: touchCompact.map(transform),
      );

  /// Every role of every size set with [transform] applied.
  CoilTypography map(TextStyle Function(TextStyle role) transform) =>
      _map(transform);

  /// Returns a copy with the given text themes replaced.
  CoilTypography copyWith({
    CoilTextTheme? pointer,
    CoilTextTheme? pointerCompact,
    CoilTextTheme? touch,
    CoilTextTheme? touchCompact,
  }) => CoilTypography(
    pointer: pointer ?? this.pointer,
    pointerCompact: pointerCompact ?? this.pointerCompact,
    touch: touch ?? this.touch,
    touchCompact: touchCompact ?? this.touchCompact,
  );

  /// Interpolates every role, so a change of weight, size or axis, such as
  /// Allo's roundness, animates. A change of font family switches halfway.
  // A static lerp, like TextStyle.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilTypography lerp(CoilTypography a, CoilTypography b, double t) {
    if (identical(a, b)) return a;
    return CoilTypography(
      pointer: CoilTextTheme.lerp(a.pointer, b.pointer, t),
      pointerCompact: CoilTextTheme.lerp(a.pointerCompact, b.pointerCompact, t),
      touch: CoilTextTheme.lerp(a.touch, b.touch, t),
      touchCompact: CoilTextTheme.lerp(a.touchCompact, b.touchCompact, t),
    );
  }

  /// Whether [debugCheckFontsBundled] reports a font family the app doesn't
  /// bundle. Tests that load fonts with a `FontLoader` instead of the asset
  /// bundle turn it off.
  static bool debugCheckFonts = true;

  static Future<Set<String>>? _bundledFamilies;
  static final _reported = <String>{};

  /// Reports, once per family and in debug builds only, a font family that
  /// this typography names but the app's font manifest doesn't declare.
  ///
  /// Flutter falls back to the platform font without a word when a family
  /// is missing, which is easy to miss next to a similar font.
  void debugCheckFontsBundled() {
    if (!debugCheckFonts) return;
    final families = {
      for (final text in [pointer, pointerCompact, touch, touchCompact])
        for (final style in [
          text.display,
          text.title,
          text.subtitle,
          text.body,
          text.field,
          text.caption,
          text.micro,
        ])
          ?style.fontFamily,
    }.difference(_reported);
    if (families.isEmpty) return;
    _reported.addAll(families);
    (_bundledFamilies ??= _loadBundledFamilies()).then((bundled) {
      for (final family in families.difference(bundled)) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts([
              ErrorSummary('The font family "$family" is not bundled.'),
              ErrorDescription(
                "The theme's CoilTypography sets it, but the app's font "
                'manifest does not declare it, so Flutter draws the '
                "platform's font instead.",
              ),
              ErrorHint(
                'Add the font files to the app and declare the family in '
                "its pubspec.yaml, under the name the typography uses:\n\n"
                'flutter:\n'
                '  fonts:\n'
                '    - family: ${family.split('/').last}\n'
                '      fonts:\n'
                '        - asset: fonts/<the font file>.ttf\n\n'
                'CoilTypography.allo and CoilTypography.inter document '
                'where to get their fonts.',
              ),
            ]),
            library: 'coil',
            context: ErrorDescription("while checking the theme's fonts"),
          ),
        );
      }
    });
  }

  static Future<Set<String>> _loadBundledFamilies() async {
    try {
      final manifest = await rootBundle.loadString('FontManifest.json');
      return {
        for (final entry in jsonDecode(manifest) as List<Object?>)
          if (entry case {'family': final String family}) family,
      };
    } on Object {
      // No manifest, such as in a test: nothing to compare against.
      return {for (final family in _reported) family};
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CoilTypography &&
      other.pointer == pointer &&
      other.pointerCompact == pointerCompact &&
      other.touch == touch &&
      other.touchCompact == touchCompact;

  @override
  int get hashCode => Object.hash(pointer, pointerCompact, touch, touchCompact);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      StringProperty('fontFamily', pointer.body.fontFamily, defaultValue: null),
    );
  }
}

/// Allo's optical size for [size]: the size itself up to 14, where Allo
/// opens its spacing for small text, then half as fast. Allo's display
/// design tightens faster than Inter's, so following the size all the way
/// would set titles and display text noticeably tighter than the body.
double _alloOpticalSize(double size) =>
    size <= 14 ? size : 14 + (size - 14) / 2;

/// Allo's letter spacing for [size], in em. Even at its text size Allo runs
/// about 2% narrower than Inter, the font coil's scale was tuned on; this
/// opens it up so every role sets within about ±0.5% of Inter's width.
double _alloTracking(double size) {
  if (size < 13) return 0;
  if (size < 14) return 0.005;
  if (size <= 18) return 0.006;
  if (size <= 24) return 0.003;
  return 0.002;
}

/// [role] on top of [base]: the role's size, line height and weight over
/// the base's family, axes and features, with axes and features combined by
/// tag, the role's winning, and `opsz` at the font size unless set.
TextStyle _place(TextStyle base, TextStyle role) {
  // A role that doesn't inherit would replace the base entirely.
  final merged = base.merge(role.copyWith(inherit: true));
  final size = merged.fontSize ?? 14;
  final axes = <String, FontVariation>{
    for (final axis in [...?base.fontVariations, ...?role.fontVariations])
      axis.axis: axis,
  }..putIfAbsent('opsz', () => FontVariation.opticalSize(size));
  final features = <String, FontFeature>{
    for (final feature in [...?base.fontFeatures, ...?role.fontFeatures])
      feature.feature: feature,
  };
  return merged.copyWith(
    inherit: false,
    fontVariations: axes.values.toList(),
    fontFeatures: features.values.toList(),
    letterSpacing: merged.letterSpacing ?? 0,
    leadingDistribution: TextLeadingDistribution.even,
    decoration: TextDecoration.none,
    textBaseline: TextBaseline.alphabetic,
  );
}

/// A role of coil's type scale: a font size on a line box of
/// [lineHeight], with even leading, at a weight. Only for coil's own scale,
/// so it can be const; any change to a role makes a plain [TextStyle].
class _Role extends TextStyle {
  const _Role(double fontSize, double lineHeight, [FontWeight? weight])
    : super(
        inherit: false,
        fontSize: fontSize,
        height: lineHeight / fontSize,
        fontWeight: weight ?? FontWeight.w400,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
        decoration: TextDecoration.none,
        textBaseline: TextBaseline.alphabetic,
      );
}

/// Titles and selected labels: between medium and semibold, so a selected
/// label doesn't shout.
const _semibold = FontWeight(550);

const _bold = FontWeight.w700;

// coil's type scale (DESIGN.md §3.1). Touch body is 16/22: it keeps the
// pointer's text-to-height ratio (13 in 36 is 16 in 44).
const _pointer = CoilTextTheme(
  display: _Role(28, 34, _bold),
  title: _Role(16, 22, _semibold),
  subtitle: _Role(14, 20),
  body: _Role(13, 20),
  field: _Role(13, 20),
  caption: _Role(12, 16),
  micro: _Role(11, 14),
);

const _pointerCompact = CoilTextTheme(
  display: _Role(24, 30, _bold),
  title: _Role(14, 20, _semibold),
  subtitle: _Role(13, 18),
  body: _Role(12, 18),
  field: _Role(12, 18),
  caption: _Role(11, 14),
  micro: _Role(11, 14),
);

const _touch = CoilTextTheme(
  display: _Role(28, 34, _bold),
  title: _Role(17, 22, _semibold),
  subtitle: _Role(16, 22),
  body: _Role(16, 22),
  field: _Role(16, 22),
  caption: _Role(13, 18),
  micro: _Role(11, 14),
);

// Touch fields stay at 16, below which iOS zooms into a focused field.
const _touchCompact = CoilTextTheme(
  display: _Role(28, 34, _bold),
  title: _Role(16, 22, _semibold),
  subtitle: _Role(15, 20),
  body: _Role(14, 20),
  field: _Role(16, 20),
  caption: _Role(12, 16),
  micro: _Role(11, 14),
);

/// Small helpers for the text styles coil's roles produce.
extension CoilTextStyleTools on TextStyle {
  /// The height of one line box: [fontSize] × [height], as coil's roles
  /// set them.
  double get lineHeight => (fontSize ?? 14) * (height ?? 1);

  /// This style with tabular figures, for numbers that line up: times,
  /// table cells, counters.
  TextStyle get tabular => copyWith(
    fontFeatures: [
      for (final feature in [...?fontFeatures])
        if (feature.feature != 'tnum') feature,
      const FontFeature.tabularFigures(),
    ],
  );
}

/// The [IconThemeData.weight]s controls give their icon slots.
///
/// Controls raise the weight on hover. Variable icon fonts read `weight`
/// directly; a stroke icon can scale its stroke with it (`1.5 * weight /
/// 400` goes from a 1.5 to a 2 stroke).
abstract final class CoilIconWeight {
  /// At rest: a 1.5 stroke.
  static const double rest = 400;

  /// Hovered or active: a 2 stroke (400 × 2 / 1.5).
  static const double emphasis = 1600 / 3;
}

/// The size a painted glyph should draw at, the way Flutter's `Icon` sizes
/// itself: the ambient [IconTheme]'s size, scaled by the ambient
/// `TextScaler` when [IconThemeData.applyTextScaling] is true (coil's
/// icon themes set it, so slot icons and drawn glyphs grow with text).
abstract final class CoilIconSize {
  /// The glyph size at [context]; [fallback] when the theme has none.
  static double of(BuildContext context, {double fallback = 16}) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? fallback;
    return theme.applyTextScaling ?? false
        ? MediaQuery.textScalerOf(context).scale(size)
        : size;
  }
}
