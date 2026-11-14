import 'package:coil/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

  /// The defaults from [theme]'s tokens, with [text] the ambient text
  /// color: the keys take it, and the fill is a faint wash of it, so the
  /// caps fit any surface, an inverted tooltip bubble included.
  factory CoilKbdStyle.fallback(CoilThemeData theme, Color text) =>
      CoilKbdStyle(
        fill: text.withValues(alpha: text.a * 0.15),
        textStyle: theme.typography
            .style(const CoilTypeStep(11, 14), color: text)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        radius: theme.shape == CoilShape.sharp ? 0 : 3,
        size: 18,
        paddingX: 4,
        gap: 2,
      );

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
/// Screen readers hear the combination as one label. The caps take their
/// colors from the ambient [DefaultTextStyle], so they suit any surface.
class CoilKbd extends StatelessWidget {
  /// Shows [combination] split into keys.
  CoilKbd(
    String combination, {
    super.key,
    this.style,
  }) : keys = split(combination);

  /// Shows [keys] as given, one cap each.
  const CoilKbd.keys(
    this.keys, {
    super.key,
    this.style,
  });

  /// Shows the keys that trigger [activator]: a [SingleActivator] or a
  /// [CharacterActivator]. Modifiers come first, as glyphs on Apple
  /// platforms (⌃ ⌥ ⇧ ⌘) and as words elsewhere (Ctrl Alt Shift).
  CoilKbd.activator(
    ShortcutActivator activator, {
    super.key,
    this.style,
  }) : keys = keysOf(activator);

  /// The keys, in order.
  final List<String> keys;

  /// Overrides the theme's key style.
  final CoilKbdStyle? style;

  static final _keyPattern = RegExp(r'[⌘⇧⌥⌃]|[^⌘⇧⌥⌃+\s]+|\+$');

  /// The key names for [activator], as [CoilKbd.activator] shows them.
  static List<String> keysOf(ShortcutActivator activator) {
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    List<String> modifiers({
      required bool control,
      required bool alt,
      required bool shift,
      required bool meta,
    }) => [
      if (control) ...[if (apple) '⌃' else 'Ctrl'],
      if (alt) ...[if (apple) '⌥' else 'Alt'],
      if (shift) ...[if (apple) '⇧' else 'Shift'],
      if (meta) ...[if (apple) '⌘' else 'Meta'],
    ];
    return switch (activator) {
      SingleActivator() => [
        ...modifiers(
          control: activator.control,
          alt: activator.alt,
          shift: activator.shift,
          meta: activator.meta,
        ),
        activator.trigger.keyLabel,
      ],
      CharacterActivator() => [
        ...modifiers(
          control: activator.control,
          alt: activator.alt,
          shift: false,
          meta: activator.meta,
        ),
        activator.character,
      ],
      _ => throw ArgumentError.value(
        activator,
        'activator',
        'CoilKbd shows SingleActivator and CharacterActivator',
      ),
    };
  }

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
      DefaultTextStyle.of(context).style.color ?? theme.colors.mutedForeground,
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
