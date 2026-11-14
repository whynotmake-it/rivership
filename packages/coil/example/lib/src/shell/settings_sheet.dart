import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// The settings button in every page header.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => CoilButton.icon(
    variant: CoilButtonVariant.ghost,
    semanticLabel: 'Preview settings',
    icon: const CatalogIcon(Glyph.settings),
    onPressed: () => showSettingsSheet(context),
  );
}

/// Opens the preview settings in a coil sheet.
///
/// The sheet goes on the catalog's navigator, below the settings scope, and
/// captures no themes, so it restyles live as settings change: switch to
/// dark and the sheet turns dark with the page behind it.
void showSettingsSheet(BuildContext context) {
  unawaited(
    Navigator.of(context).push(
      CoilSheetRoute<void>(
        motion: CoilTheme.motionOf(context).gentle,
        barrierColor: CoilSheetPanel.barrierColorOf(context),
        child: const CoilSheetPanel(
          title: Text('Preview settings'),
          child: SettingsPanel(),
        ),
      ),
    ),
  );
}

/// The controls in the settings sheet.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    // Sheets are touch surfaces whatever the tier (DESIGN.md §13.3).
    return CoilAdaptiveScope(
      tier: CoilTier.touch,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          CoilFieldSet(
            legend: const Text('Appearance'),
            description: const Text(
              'The theme an app passes to CoilTheme. The palette comes from '
              'CoilColors.fromSeed: a brand color and a neutral tone.',
            ),
            children: [
              CoilField(
                label: const Text('Theme'),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogThemeMode>(
                  value: settings.themeMode,
                  onChanged: (value) => settings.themeMode = value,
                  options: const [
                    CoilOption(
                      value: CatalogThemeMode.system,
                      label: 'System',
                      icon: CatalogIcon(Glyph.monitor),
                    ),
                    CoilOption(
                      value: CatalogThemeMode.light,
                      label: 'Light',
                      icon: CatalogIcon(Glyph.sun),
                    ),
                    CoilOption(
                      value: CatalogThemeMode.dark,
                      label: 'Dark',
                      icon: CatalogIcon(Glyph.moon),
                    ),
                  ],
                ),
              ),
              CoilField(
                label: const Text('Brand color'),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogBrand>(
                  value: settings.brand,
                  onChanged: (value) => settings.brand = value,
                  options: [
                    for (final brand in CatalogBrand.values)
                      CoilOption(
                        value: brand,
                        label: brand.label,
                        icon: _Swatch(brand.color),
                      ),
                  ],
                ),
              ),
              CoilSlider(
                label: _SwatchLabel(
                  color: CoilColorMix.oklch(0.7, 0.12, settings.neutralHue),
                  child: const Text('Neutral hue'),
                ),
                max: 355,
                divisions: 71,
                value: settings.neutralHue,
                valueBuilder: (_, v) => Text('${v.round()}°'),
                onChanged: (value) => settings.neutralHue = value,
              ),
              CoilSlider(
                label: const Text('Neutral tint'),
                max: 0.05,
                divisions: 50,
                value: settings.neutralChroma,
                valueBuilder: (_, v) =>
                    Text(v == 0 ? 'Grey' : v.toStringAsFixed(3)),
                onChanged: (value) => settings.neutralChroma = value,
              ),
              CoilField(
                label: const Text('Font'),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogFont>(
                  value: settings.font,
                  onChanged: (value) => settings.font = value,
                  options: [
                    for (final font in CatalogFont.values)
                      CoilOption(value: font, label: font.label),
                  ],
                ),
              ),
              CoilField(
                label: const Text('Shape'),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogShape>(
                  value: settings.shape,
                  onChanged: (value) => settings.shape = value,
                  options: [
                    for (final shape in CatalogShape.values)
                      CoilOption(value: shape, label: shape.label),
                  ],
                ),
              ),
              if (settings.shape == CatalogShape.custom)
                CoilSlider(
                  label: const Text('Corner radius'),
                  max: 20,
                  divisions: 20,
                  value: settings.customRadius,
                  valueBuilder: (_, v) => Text('${v.round()} px'),
                  onChanged: (value) => settings.customRadius = value,
                ),
              CoilField(
                label: const Text('Spacing'),
                description: const Text(
                  'Roomy makes every control 4 px taller and wider.',
                ),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogSpacing>(
                  value: settings.spacing,
                  onChanged: (value) => settings.spacing = value,
                  options: [
                    for (final spacing in CatalogSpacing.values)
                      CoilOption(value: spacing, label: spacing.label),
                  ],
                ),
              ),
              CoilSwitch(
                value: settings.boldFocusRing,
                onChanged: (value) => settings.boldFocusRing = value,
                label: const Text('Bold focus ring'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          CoilFieldSet(
            legend: const Text('Motion'),
            children: [
              CoilField(
                label: const Text('Springs'),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogMotion>(
                  value: settings.motion,
                  onChanged: (value) => settings.motion = value,
                  options: [
                    for (final motion in CatalogMotion.values)
                      CoilOption(value: motion, label: motion.label),
                  ],
                ),
              ),
              CoilSwitch(
                value: settings.reducedMotion,
                onChanged: (value) => settings.reducedMotion = value,
                label: const Text('Reduce motion'),
              ),
              CoilSwitch(
                value: settings.slowMo,
                onChanged: (value) => settings.slowMo = value,
                label: Text('Slow motion (${_factor(settings)}× slower)'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          CoilFieldSet(
            legend: const Text('Device'),
            description: const Text(
              'What the platform tells the app: input, text size, '
              'direction and accessibility.',
            ),
            children: [
              CoilField(
                label: const Text('Size tier'),
                description: const Text(
                  'Auto picks pointer on desktop and touch on phones.',
                ),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogTier>(
                  value: settings.tier,
                  onChanged: (value) => settings.tier = value,
                  options: [
                    for (final tier in CatalogTier.values)
                      CoilOption(value: tier, label: tier.label),
                  ],
                ),
              ),
              CoilField(
                label: const Text('Text scale'),
                orientation: CoilFieldOrientation.responsive,
                child: CoilSelect<CatalogTextScale>(
                  value: settings.textScale,
                  onChanged: (value) => settings.textScale = value,
                  options: [
                    for (final scale in CatalogTextScale.values)
                      CoilOption(value: scale, label: scale.label),
                  ],
                ),
              ),
              CoilSwitch(
                value: settings.rtl,
                onChanged: (value) => settings.rtl = value,
                label: const Text('Right to left'),
              ),
              CoilSwitch(
                value: settings.highContrast,
                onChanged: (value) => settings.highContrast = value,
                label: const Text('High contrast'),
              ),
              CoilSwitch(
                value: !settings.hapticsOff,
                onChanged: (value) => settings.hapticsOff = !value,
                label: const Text('Haptics'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _factor(CatalogSettings settings) =>
      settings.slowMoFactor.toStringAsFixed(0);
}

/// A color dot for the brand color options.
class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = CoilIconSize.of(context) * 0.75;
    return SizedBox.square(
      dimension: CoilIconSize.of(context),
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(size / 2),
            ),
          ),
          child: SizedBox.square(dimension: size),
        ),
      ),
    );
  }
}

/// A slider label led by a color dot.
class _SwatchLabel extends StatelessWidget {
  const _SwatchLabel({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      _Swatch(color),
      Flexible(child: child),
    ],
  );
}
