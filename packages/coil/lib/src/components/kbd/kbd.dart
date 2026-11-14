import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Which surface a [CoilKbd] sits on.
enum CoilKbdTone {
  /// A page or popover: a faint foreground fill with muted text.
  normal,

  /// An inverted surface, such as a tooltip bubble: a faint background
  /// fill with background-colored text.
  inverted,
}

/// Overrides for how a [CoilKbd] looks; unset fields come from
/// [CoilKbdStyle.fallback].
class CoilKbdStyle extends CoilComponentStyle<CoilKbdStyle> {
  /// Creates a key style.
  const CoilKbdStyle({
    this.fill,
    this.textStyle,
    this.radius,
    this.size,
    this.paddingX,
    this.gap,
  });

  /// The defaults for [tone] from [theme]'s tokens.
  factory CoilKbdStyle.fallback(CoilThemeData theme, CoilKbdTone tone) {
    final c = theme.colors;
    final (fill, text) = switch (tone) {
      CoilKbdTone.normal => (
        CoilColorMix.withTransparent(c.foreground, 0.08),
        c.mutedForeground,
      ),
      CoilKbdTone.inverted => (
        CoilColorMix.withTransparent(c.background, 0.15),
        c.background,
      ),
    };
    return CoilKbdStyle(
      fill: fill,
      textStyle: theme.typography
          .style(const CoilTypeStep(11, 14), color: text)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      radius: theme.shape == CoilShape.sharp ? 0 : 3,
      size: 18,
      paddingX: 4,
      gap: 2,
    );
  }

  /// The cap's fill.
  final Color? fill;

  /// The key's text style.
  final TextStyle? textStyle;

  /// The cap's corner radius.
  final double? radius;

  /// The cap's smallest height and width, before text scaling.
  final double? size;

  /// The space at each side of a key's text.
  final double? paddingX;

  /// The space between the caps of a combination.
  final double? gap;

  @override
  CoilKbdStyle merge(CoilKbdStyle? other) => other == null
      ? this
      : CoilKbdStyle(
          fill: other.fill ?? fill,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          size: other.size ?? size,
          paddingX: other.paddingX ?? paddingX,
          gap: other.gap ?? gap,
        );

  @override
  List<Object?> get props => [fill, textStyle, radius, size, paddingX, gap];
}

/// A keyboard shortcut, one small cap per key: `CoilKbd('⇧⌘O')` draws ⇧,
/// ⌘ and O.
///
/// Modifier glyphs (⌘ ⇧ ⌥ ⌃) are keys of their own, `+` and spaces
/// separate the rest, so `'Ctrl+K'` draws Ctrl and K. Use
/// [CoilKbd.keys] for a key whose name has a space, like `Page Up`.
/// Screen readers hear the combination as one label.
class CoilKbd extends StatelessWidget {
  /// Shows [combination] split into keys.
  CoilKbd(
    String combination, {
    super.key,
    this.tone = CoilKbdTone.normal,
    this.style,
  }) : keys = split(combination);

  /// Shows [keys] as given, one cap each.
  const CoilKbd.keys(
    this.keys, {
    super.key,
    this.tone = CoilKbdTone.normal,
    this.style,
  });

  /// The keys, in order.
  final List<String> keys;

  /// Which surface the caps sit on.
  final CoilKbdTone tone;

  /// Overrides the theme's key style.
  final CoilKbdStyle? style;

  static final _keyPattern = RegExp(r'[⌘⇧⌥⌃]|[^⌘⇧⌥⌃+\s]+|\+$');

  /// Splits [combination] into keys: `'⇧⌘O'` is `['⇧', '⌘', 'O']`,
  /// `'Ctrl+K'` is `['Ctrl', 'K']`.
  static List<String> split(String combination) => [
    for (final match in _keyPattern.allMatches(combination)) match[0]!,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final look = CoilKbdStyle.fallback(
      theme,
      tone,
    ).merge(CoilTheme.styleOf<CoilKbdStyle>(context)).merge(style);
    final size = MediaQuery.textScalerOf(context).scale(look.size!);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(look.radius!),
    );
    return Semantics(
      label: keys.join(' '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: look.gap!,
        children: [
          for (final key in keys)
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: size, minHeight: size),
              child: DecoratedBox(
                decoration: ShapeDecoration(color: look.fill, shape: shape),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: look.paddingX!),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      key,
                      maxLines: 1,
                      softWrap: false,
                      style: look.textStyle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
