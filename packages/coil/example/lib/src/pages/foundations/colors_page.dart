import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const colorsEntry = CatalogEntry(
  slug: 'colors',
  title: 'Colors',
  group: CatalogGroup.foundations,
  summary: 'Surfaces, neutrals, state tints, brand and status, both themes.',
  page: ColorsPage.new,
);

/// A named color token read from a [CoilColors].
typedef _Token = (String name, Color Function(CoilColors c) read);

final _surfaces = <_Token>[
  for (var level = 1; level <= 8; level++)
    ('surface($level)', (c) => c.surface(level)),
];

final _neutrals = <_Token>[
  ('foreground', (c) => c.foreground),
  ('mutedForeground', (c) => c.mutedForeground),
  ('muted', (c) => c.muted),
  ('accent', (c) => c.accent),
  ('selected', (c) => c.selected),
  ('input', (c) => c.input),
  ('border', (c) => c.border),
];

final _tints = <_Token>[
  ('hover', (c) => c.hover),
  ('active', (c) => c.active),
  ('tint', (c) => c.tint),
  ('tintHover', (c) => c.tintHover),
];

final _brand = <_Token>[
  ('brand', (c) => c.brand),
  ('focusRing', (c) => c.focusRing),
  ('red', (c) => c.red),
  ('redLabel', (c) => c.redLabel),
  ('destructive', (c) => c.destructive),
  ('info', (c) => c.info),
  ('success', (c) => c.success),
  ('warning', (c) => c.warning),
];

class ColorsPage extends StatelessWidget {
  const ColorsPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'Colors',
    summary:
        'Both themes side by side. Turn on high contrast in the settings to '
        'see borders, accent and the focus ring strengthen.',
    children: [
      _TokenSection(
        title: 'Surfaces',
        description:
            'Level 1 is the page. Popovers and sheets sit 2 above what opened '
            'them, dialogs 4.',
        tokens: _TokenGroup.surfaces,
      ),
      _TokenSection(
        title: 'Neutrals',
        description: 'Text, quiet fills and hairlines.',
        tokens: _TokenGroup.neutrals,
      ),
      _TokenSection(
        title: 'State tints',
        description:
            'Hover is 4 %, pressed and selected 7 %. '
            'Never derived from accent.',
        tokens: _TokenGroup.tints,
      ),
      _TokenSection(
        title: 'Brand and status',
        description: 'Color is spent only on meaning.',
        tokens: _TokenGroup.brand,
      ),
      DemoSection(
        title: 'Elevation',
        description:
            'Surface N pairs with shadow N. Dark surfaces add an inset ring.',
        child: _Elevation(),
      ),
    ],
  );
}

enum _TokenGroup {
  surfaces,
  neutrals,
  tints,
  brand;

  List<_Token> get tokens => switch (this) {
    surfaces => _surfaces,
    neutrals => _neutrals,
    tints => _tints,
    brand => _brand,
  };
}

class _TokenSection extends StatelessWidget {
  const _TokenSection({
    required this.title,
    required this.description,
    required this.tokens,
  });

  final String title;
  final String description;
  final _TokenGroup tokens;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    // The app's palettes, so the preview settings (the brand color) show.
    final settings = CatalogSettingsScope.maybeOf(context);
    CoilColors resolve(Brightness brightness) {
      final c =
          settings?.theme(brightness).colors ??
          (brightness == Brightness.dark ? CoilColors.dark : CoilColors.light);
      return highContrast ? c.highContrast() : c;
    }

    return DemoSection(
      title: title,
      description: description,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final light = _ThemeColumn(
            title: 'Light',
            colors: resolve(Brightness.light),
            tokens: tokens.tokens,
          );
          final dark = _ThemeColumn(
            title: 'Dark',
            colors: resolve(Brightness.dark),
            tokens: tokens.tokens,
          );
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [light, const SizedBox(height: 16), dark],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: light),
              const SizedBox(width: 16),
              Expanded(child: dark),
            ],
          );
        },
      ),
    );
  }
}

/// One theme's swatches, drawn on that theme's own background, so the
/// translucent tokens show as they really look.
class _ThemeColumn extends StatelessWidget {
  const _ThemeColumn({
    required this.title,
    required this.colors,
    required this.tokens,
  });

  final String title;
  final CoilColors colors;
  final List<_Token> tokens;

  @override
  Widget build(BuildContext context) {
    final radius = CoilTheme.radiiOf(context).item;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius + 4),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TypeRole.caption.styleOf(
                  context,
                  weight: CoilWeight.semibold,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              for (final (name, read) in tokens)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _Swatch(
                    name: name,
                    color: read(colors),
                    colors: colors,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.colors,
  });

  final String name;
  final Color color;
  final CoilColors colors;

  static String hex(Color c) {
    String two(double v) =>
        (v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final rgb = '#${two(c.r)}${two(c.g)}${two(c.b)}';
    return c.a < 1 ? '$rgb · ${(c.a * 100).round()} %' : rgb;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(28);
    return Row(
      children: [
        SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: color,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(size / 4),
                side: BorderSide(color: colors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeRole.caption.styleOf(
                  context,
                  weight: CoilWeight.semibold,
                  color: colors.foreground,
                ),
              ),
              Text(
                hex(color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeRole.micro
                    .styleOf(context, color: colors.mutedForeground)
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Elevation extends StatelessWidget {
  const _Elevation();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var level = 1; level <= 8; level++)
              SizedBox(
                width: 72,
                height: 56,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.surface(level),
                    shadows: colors.shadow(level),
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: radius,
                        side: colors.insetRing(level),
                      ),
                    ),
                    child: Center(
                      child: RoleText('$level', role: TypeRole.caption),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
