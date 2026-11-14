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
    onPressed: () => showPreviewSettings(context),
  );
}

/// The sections of the preview settings.
enum PreviewSection { appearance, shape, motion, accessibility, device }

/// Opens the preview settings in a [CoilSettingsDialog].
///
/// The dialog goes on the catalog's navigator, below the settings scope,
/// and captures no themes, so it restyles live as settings change: switch
/// to dark and the dialog turns dark with the page behind it.
Future<void> showPreviewSettings(
  BuildContext context, {
  PreviewSection initialSection = PreviewSection.appearance,
}) => showCoilSettingsDialog<PreviewSection>(
  context: context,
  title: const Text('Preview settings'),
  initialSection: initialSection,
  sections: [
    CoilSettingsSection(
      value: PreviewSection.appearance,
      label: const Text('Appearance'),
      icon: const CatalogIcon(Glyph.palette),
      description: const Text(
        'The palette comes from CoilColors.fromSeed: a brand color and a '
        'neutral tone.',
      ),
      builder: (context) => const _Appearance(),
    ),
    CoilSettingsSection(
      value: PreviewSection.shape,
      label: const Text('Shape and spacing'),
      icon: const CatalogIcon(Glyph.sliders),
      description: const Text('Corner radii and control sizes.'),
      builder: (context) => const _ShapeAndSpacing(),
    ),
    CoilSettingsSection(
      value: PreviewSection.motion,
      label: const Text('Motion'),
      icon: const CatalogIcon(Glyph.play),
      description: const Text('The springs every component moves on.'),
      builder: (context) => const _Motion(),
    ),
    CoilSettingsSection(
      value: PreviewSection.accessibility,
      label: const Text('Accessibility'),
      icon: const CatalogIcon(Glyph.user),
      description: const Text(
        'What the platform tells the app about the person using it.',
      ),
      builder: (context) => const _Accessibility(),
    ),
    CoilSettingsSection(
      value: PreviewSection.device,
      label: const Text('Device'),
      icon: const CatalogIcon(Glyph.monitor),
      description: const Text('Input and feedback on this device.'),
      builder: (context) => const _Device(),
    ),
  ],
);

/// A select or slider at the end of a setting row: wide enough for the
/// longest option, the same for every row so the controls line up.
class _Control extends StatelessWidget {
  const _Control({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: 180, child: child);
}

/// A setting row with a [CoilSelect] over an enum's values.
class _SelectRow<T> extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.values,
    required this.text,
    required this.onChanged,
    this.description,
    this.icon,
  });

  final Widget label;
  final Widget? description;
  final T value;
  final List<T> values;
  final String Function(T value) text;
  final Widget? Function(T value)? icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => CoilSettingRow(
    label: label,
    description: description,
    trailing: _Control(
      child: CoilSelect<T>(
        value: value,
        onChanged: onChanged,
        options: [
          for (final option in values)
            CoilOption(
              value: option,
              label: Text(text(option)),
              searchText: text(option),
              icon: icon?.call(option),
            ),
        ],
      ),
    ),
  );
}

/// A setting row with a [CoilSwitch].
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final Widget? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CoilSettingRow(
    label: Text(label),
    description: description,
    trailing: CoilSwitch(
      value: value,
      semanticLabel: label,
      onChanged: onChanged,
    ),
  );
}

/// A setting row with a [CoilSlider]: a bordered row like the selects.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
    this.leading,
  });

  final String label;
  final Widget? leading;
  final double value;
  final double max;
  final int divisions;
  final String Function(double value) valueText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => CoilSettingRow(
    label: Row(
      spacing: 8,
      children: [
        ?leading,
        Flexible(child: Text(label)),
      ],
    ),
    trailing: _Control(
      child: CoilSlider(
        semanticLabel: label,
        max: max,
        divisions: divisions,
        value: value,
        valueBuilder: (_, v) => Text(valueText(v)),
        semanticFormatter: valueText,
        onChanged: onChanged,
      ),
    ),
  );
}

class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [
        _SelectRow<CatalogThemeMode>(
          label: const Text('Theme'),
          value: settings.themeMode,
          values: CatalogThemeMode.values,
          text: (mode) => switch (mode) {
            CatalogThemeMode.system => 'System',
            CatalogThemeMode.light => 'Light',
            CatalogThemeMode.dark => 'Dark',
          },
          icon: (mode) => CatalogIcon(switch (mode) {
            CatalogThemeMode.system => Glyph.monitor,
            CatalogThemeMode.light => Glyph.sun,
            CatalogThemeMode.dark => Glyph.moon,
          }),
          onChanged: (value) => settings.themeMode = value,
        ),
        _SelectRow<CatalogBrand>(
          label: const Text('Brand color'),
          description: const Text('Also the focus ring.'),
          value: settings.brand,
          values: CatalogBrand.values,
          text: (brand) => brand.label,
          icon: (brand) => _Swatch(brand.color),
          onChanged: (value) => settings.brand = value,
        ),
        _SliderRow(
          label: 'Neutral hue',
          leading: _Swatch(
            CoilColorMix.oklch(0.7, 0.12, settings.neutralHue),
          ),
          max: 355,
          divisions: 71,
          value: settings.neutralHue,
          valueText: (v) => '${v.round()}°',
          onChanged: (value) => settings.neutralHue = value,
        ),
        _SliderRow(
          label: 'Neutral tint',
          max: 0.05,
          divisions: 50,
          value: settings.neutralChroma,
          valueText: (v) => v == 0 ? 'Grey' : v.toStringAsFixed(3),
          onChanged: (value) => settings.neutralChroma = value,
        ),
        _SelectRow<CatalogFont>(
          label: const Text('Font'),
          value: settings.font,
          values: CatalogFont.values,
          text: (font) => font.label,
          onChanged: (value) => settings.font = value,
        ),
      ],
    );
  }
}

class _ShapeAndSpacing extends StatelessWidget {
  const _ShapeAndSpacing();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [
        _SelectRow<CatalogShape>(
          label: const Text('Shape'),
          value: settings.shape,
          values: CatalogShape.values,
          text: (shape) => shape.label,
          onChanged: (value) => settings.shape = value,
        ),
        if (settings.shape == CatalogShape.custom)
          _SliderRow(
            label: 'Corner radius',
            max: 20,
            divisions: 20,
            value: settings.customRadius,
            valueText: (v) => '${v.round()} px',
            onChanged: (value) => settings.customRadius = value,
          ),
        _SelectRow<CatalogSpacing>(
          label: const Text('Spacing'),
          description: const Text(
            'Roomy makes every control 4 px taller and wider.',
          ),
          value: settings.spacing,
          values: CatalogSpacing.values,
          text: (spacing) => spacing.label,
          onChanged: (value) => settings.spacing = value,
        ),
      ],
    );
  }
}

class _Motion extends StatelessWidget {
  const _Motion();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [
        _SelectRow<CatalogMotion>(
          label: const Text('Springs'),
          value: settings.motion,
          values: CatalogMotion.values,
          text: (motion) => motion.label,
          onChanged: (value) => settings.motion = value,
        ),
        _SwitchRow(
          label: 'Slow motion',
          description: Text(
            'Everything runs '
            '${settings.slowMoFactor.toStringAsFixed(0)}× slower.',
          ),
          value: settings.slowMo,
          onChanged: (value) => settings.slowMo = value,
        ),
      ],
    );
  }
}

class _Accessibility extends StatelessWidget {
  const _Accessibility();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [
        _SelectRow<CatalogTextScale>(
          label: const Text('Text scale'),
          value: settings.textScale,
          values: CatalogTextScale.values,
          text: (scale) => scale.label,
          onChanged: (value) => settings.textScale = value,
        ),
        _SwitchRow(
          label: 'High contrast',
          description: const Text('Off follows the platform.'),
          value: settings.highContrast,
          onChanged: (value) => settings.highContrast = value,
        ),
        _SwitchRow(
          label: 'Reduce motion',
          description: const Text('Off follows the platform.'),
          value: settings.reducedMotion,
          onChanged: (value) => settings.reducedMotion = value,
        ),
        _SwitchRow(
          label: 'Right to left',
          value: settings.rtl,
          onChanged: (value) => settings.rtl = value,
        ),
        _SwitchRow(
          label: 'Bold focus ring',
          description: const Text('2 px instead of 1. High contrast is 2.'),
          value: settings.boldFocusRing,
          onChanged: (value) => settings.boldFocusRing = value,
        ),
      ],
    );
  }
}

class _Device extends StatelessWidget {
  const _Device();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [
        _SelectRow<CatalogTier>(
          label: const Text('Size tier'),
          description: const Text(
            'Auto picks pointer on desktop and touch on phones.',
          ),
          value: settings.tier,
          values: CatalogTier.values,
          text: (tier) => tier.label,
          onChanged: (value) => settings.tier = value,
        ),
        _SwitchRow(
          label: 'Haptics',
          description: const Text("Off turns coil's haptics off."),
          value: !settings.hapticsOff,
          onChanged: (value) => settings.hapticsOff = !value,
        ),
      ],
    );
  }
}

/// A color dot, for the brand options and the neutral hue.
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
