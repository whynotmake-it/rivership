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
          CoilFieldGroup(
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
        ],
      ),
    );
  }

  static String _factor(CatalogSettings settings) =>
      settings.slowMoFactor.toStringAsFixed(0);
}
