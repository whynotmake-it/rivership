import 'package:coil/coil.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_devtools/motor_devtools.dart';

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
enum PreviewSection { appearance, type, behavior, accessibility }

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
        'Theme, brand color, corner radii, and spacing.',
      ),
      builder: (context) => const _Appearance(),
    ),
    CoilSettingsSection(
      value: PreviewSection.type,
      label: const Text('Type'),
      icon: const CatalogIcon(Glyph.type),
      description: const Text(
        'Font family and OpenType features for the bundled Allo and Inter '
        'typefaces.',
      ),
      builder: (context) => const _Type(),
    ),
    CoilSettingsSection(
      value: PreviewSection.behavior,
      label: const Text('Behavior'),
      icon: const CatalogIcon(Glyph.play),
      description: const Text(
        'Spring feel, frame rate, and input feedback on this device.',
      ),
      builder: (context) => const _Behavior(),
    ),
    CoilSettingsSection(
      value: PreviewSection.accessibility,
      label: const Text('Accessibility'),
      icon: const CatalogIcon(Glyph.user),
      description: const Text(
        'Simulate platform accessibility preferences such as text scale, '
        'contrast, and reduced motion.',
      ),
      builder: (context) => const _Accessibility(),
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

/// Colors, shape and spacing: how the components look.
class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [..._colorRows(settings), ..._shapeRows(settings)],
    );
  }
}

/// How the components move, and the device they run on.
class _Behavior extends StatelessWidget {
  const _Behavior();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    return CoilSettingsList(
      children: [..._motionRows(settings), ..._deviceRows(settings)],
    );
  }
}

List<Widget> _colorRows(CatalogSettings settings) => [
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
    description: const Text('Also tints the focus ring.'),
    value: settings.brand,
    values: CatalogBrand.values,
    text: (brand) => brand.label,
    icon: (brand) => _Swatch(brand.color),
    onChanged: (value) => settings.brand = value,
  ),
  _SelectRow<CoilBrandFill>(
    label: const Text('Brand fill'),
    description: const Text(
      'Accessible deepens the fill until labels reach 4.5:1 contrast.',
    ),
    value: settings.brandFill,
    values: CoilBrandFill.values,
    text: (policy) => switch (policy) {
      CoilBrandFill.accessible => 'Accessible',
      CoilBrandFill.exact => 'Exact',
    },
    onChanged: (value) => settings.brandFill = value,
  ),
  _SwitchRow(
    label: 'Brand selection',
    description: const Text(
      'Highlight selected tabs, segments, radios, and the text cursor in '
      'the brand color.',
    ),
    value: settings.brandSelection,
    onChanged: (value) => settings.brandSelection = value,
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
    valueText: (v) => v == 0 ? 'Gray' : v.toStringAsFixed(3),
    onChanged: (value) => settings.neutralChroma = value,
  ),
];

class _Type extends StatelessWidget {
  const _Type();

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    final tuned =
        settings.font == CatalogFont.allo || settings.font == CatalogFont.inter;
    return CoilSettingsList(
      children: [
        _SelectRow<CatalogFont>(
          label: const Text('Font'),
          value: settings.font,
          values: CatalogFont.values,
          text: (font) => font.label,
          onChanged: (value) => settings.font = value,
        ),
        if (settings.font == CatalogFont.allo)
          _SliderRow(
            label: 'Roundness',
            max: 100,
            divisions: 20,
            value: settings.roundness,
            valueText: (v) => switch (v.round()) {
              0 => 'Sharp',
              50 => 'Friendly',
              100 => 'Round',
              final round => '$round',
            },
            onChanged: (value) => settings.roundness = value,
          ),
        if (tuned) ...[
          _SwitchRow(
            label: 'Optical sizing',
            description: const Text(
              'Adjusts letter spacing and detail by font size: open for small '
              'text, tighter for titles. When off, every size uses standard '
              'body proportions.',
            ),
            value: settings.opticalSizing,
            onChanged: (value) => settings.opticalSizing = value,
          ),
          if (settings.font == CatalogFont.allo)
            _SwitchRow(
              label: 'Single-story a',
              value: settings.singleStoryA,
              onChanged: (value) => settings.singleStoryA = value,
            ),
          _SwitchRow(
            label: 'Distinct letters and figures',
            description: const Text(
              'Makes I, l, 1, and 0 easy to tell apart.',
            ),
            value: settings.disambiguate,
            onChanged: (value) => settings.disambiguate = value,
          ),
          _SwitchRow(
            label: 'Open figures',
            description: const Text('Open forms of 4, 6, and 9.'),
            value: settings.openFigures,
            onChanged: (value) => settings.openFigures = value,
          ),
        ],
      ],
    );
  }
}

/// The plasticity slider's value: its three steps by name.
String _plasticityText(double amount) => switch (amount) {
  <= 0 => 'Off',
  <= 0.5 => 'Subtle',
  _ => 'Strong',
};

List<Widget> _shapeRows(CatalogSettings settings) => [
  _SelectRow<CatalogShape>(
    label: const Text('Shape'),
    value: settings.shape,
    values: CatalogShape.values,
    text: (shape) => shape.label,
    onChanged: (value) => settings.shape = value,
  ),
  CoilSettingRow(
    label: const Text('Plasticity'),
    description: const Text(
      'Subtle top-to-bottom lighting on interactive controls.',
    ),
    trailing: _Control(
      child: CoilSlider(
        steps: const [0, 0.5, 1],
        value: settings.plasticity,
        valueBuilder: (_, v) => Text(_plasticityText(v)),
        semanticFormatter: _plasticityText,
        onChanged: (value) => settings.plasticity = value,
      ),
    ),
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
];

List<Widget> _motionRows(CatalogSettings settings) => [
  _SelectRow<CatalogMotion>(
    label: const Text('Springs'),
    value: settings.motion,
    values: CatalogMotion.values,
    text: (motion) => motion.label,
    onChanged: (value) => settings.motion = value,
  ),
  _SelectRow<CatalogFrameRate>(
    label: const Text('Frame rate'),
    description: const Text(
      'Caps how often springs update, to test lower refresh rates.',
    ),
    value: settings.frameRate,
    values: CatalogFrameRate.values,
    text: (rate) => rate.label,
    onChanged: (value) => settings.frameRate = value,
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
];

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
          description: const Text('Follows the system setting when off.'),
          value: settings.highContrast,
          onChanged: (value) => settings.highContrast = value,
        ),
        _SwitchRow(
          label: 'Reduce motion',
          description: const Text('Follows the system setting when off.'),
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
          description: const Text(
            'Draws a 2 px focus ring instead of 1 px. High contrast always '
            'uses 2 px.',
          ),
          value: settings.boldFocusRing,
          onChanged: (value) => settings.boldFocusRing = value,
        ),
      ],
    );
  }
}

List<Widget> _deviceRows(CatalogSettings settings) => [
  if (kMotorDevTools)
    ValueListenableBuilder(
      valueListenable: coilDevtoolsVisible,
      builder: (context, visible, _) => _SwitchRow(
        label: 'Motor DevTools',
        description: const Text(
          'Inspect and tune the springs every component moves on.',
        ),
        value: visible,
        onChanged: (value) => coilDevtoolsVisible.value = value,
      ),
    ),
  _SelectRow<CatalogTier>(
    label: const Text('Size tier'),
    description: const Text(
      'Auto switches between pointer and touch based on the current viewport.',
    ),
    value: settings.tier,
    values: CatalogTier.values,
    text: (tier) => tier.label,
    onChanged: (value) => settings.tier = value,
  ),
  _SwitchRow(
    label: 'Haptics',
    description: const Text(
      'Triggers subtle tactile feedback on supported devices.',
    ),
    value: !settings.hapticsOff,
    onChanged: (value) => settings.hapticsOff = !value,
  ),
  _SwitchRow(
    label: 'Pointing-hand cursor',
    description: const Text(
      'Shows a pointing hand over interactive controls; when off, uses the '
      'default arrow.',
    ),
    value: settings.pointingCursor,
    onChanged: (value) => settings.pointingCursor = value,
  ),
];

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
