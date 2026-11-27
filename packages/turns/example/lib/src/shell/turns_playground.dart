import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:motor/motor.dart';

/// A demo with a settings panel: docked beside the demo on wide screens,
/// sliding over it from the side on narrow ones.
class PlaygroundLayout extends StatefulWidget {
  const PlaygroundLayout({
    required this.body,
    required this.settings,
    super.key,
    this.settingsKey,
    this.buttonTop = 10,
  });

  final Widget body;

  /// The panel's sections, usually [PlaygroundSection]s.
  final List<Widget> settings;

  /// Key on the button that opens the panel on narrow screens.
  final Key? settingsKey;

  /// How far from the top the settings button floats on narrow screens,
  /// clear of the demo's own header controls.
  final double buttonTop;

  /// Windows at least this wide dock the panel beside the demo.
  static const dockBreakpoint = 900.0;

  static const panelWidth = 320.0;

  @override
  State<PlaygroundLayout> createState() => _PlaygroundLayoutState();
}

class _PlaygroundLayoutState extends State<PlaygroundLayout> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final motion = CoilTheme.motionOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final docked = constraints.maxWidth >= PlaygroundLayout.dockBreakpoint;
        final panel = _Panel(
          onClose: docked ? null : () => setState(() => _open = false),
          children: widget.settings,
        );
        if (docked) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: widget.body),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaces[1],
                  border: BorderDirectional(
                    start: BorderSide(color: colors.border),
                  ),
                ),
                child: SizedBox(
                  width: PlaygroundLayout.panelWidth,
                  child: panel,
                ),
              ),
            ],
          );
        }
        final width = (constraints.maxWidth - 40).clamp(
          0.0,
          PlaygroundLayout.panelWidth,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.body,
            PositionedDirectional(
              top: widget.buttonTop,
              end: 12,
              child: CoilTooltip(
                message: const Text('Settings'),
                child: CoilButton.icon(
                  key: widget.settingsKey,
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  semanticLabel: 'Open settings',
                  icon: const Icon(LucideIcons.slidersHorizontal),
                  onPressed: () => setState(() => _open = true),
                ),
              ),
            ),
            SingleMotionBuilder(
              value: _open ? 1 : 0,
              motion: _open ? motion.standard : motion.fadeExit,
              child: panel,
              builder: (context, t, child) {
                final clamped = t.clamp(0.0, 1.0);
                if (clamped <= 0.001) return const SizedBox.shrink();
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _open = false),
                        child: ColoredBox(
                          color: colors.foreground.withValues(
                            alpha: 0.12 * clamped,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 8,
                      bottom: 8,
                      end: 8,
                      width: width,
                      child: IgnorePointer(
                        ignoring: !_open,
                        child: Opacity(
                          opacity: clamped,
                          child: Transform.translate(
                            offset: Offset((1 - t) * 24, 0),
                            child: CoilSurface(
                              offset: CoilSurface.popoverOffset,
                              shadowLevel: 2,
                              borderRadius: BorderRadius.circular(
                                CoilTheme.radiiOf(context).container,
                              ),
                              child: child!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.onClose});

  final List<Widget> children;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Settings',
                  style: text.body.copyWith(fontWeight: text.emphasis),
                ),
              ),
              if (onClose case final onClose?)
                CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  semanticLabel: 'Close settings',
                  icon: const Icon(LucideIcons.x),
                  onPressed: onClose,
                )
              else
                const SizedBox(height: 32),
            ],
          ),
        ),
        Expanded(
          child: CoilScrollArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled group of settings.
class PlaygroundSection extends StatelessWidget {
  const PlaygroundSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(title.toUpperCase(), style: text.muted.micro),
        ),
        ...children,
      ],
    );
  }
}

/// A label, an optional hint, and the control under them.
class PlaygroundSetting extends StatelessWidget {
  const PlaygroundSetting({
    required this.label,
    required this.child,
    super.key,
    this.hint,
    this.value,
  });

  final String label;

  /// One short line on what the setting changes.
  final String? hint;

  /// The current value, shown at the end of the label row.
  final String? value;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: text.caption)),
            if (value case final value?)
              Text(value, style: text.muted.caption.tabular),
          ],
        ),
        if (hint case final hint?) ...[
          const SizedBox(height: 2),
          Text(hint, style: text.muted.micro),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// A single choice out of a few, as a segmented control.
class PlaygroundChoice<T> extends StatelessWidget {
  const PlaygroundChoice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
    this.hint,
  });

  final String label;
  final String? hint;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => PlaygroundSetting(
    label: label,
    hint: hint,
    // More than three segments don't fit the panel; those become a select.
    child: options.length > 3
        ? CoilSelect<T>(
            size: CoilSize.compact,
            value: value,
            onChanged: (picked) {
              if (picked != null) onChanged(picked);
            },
            options: [
              for (final MapEntry(:key, :value) in options.entries)
                CoilOption(value: key, label: Text(value)),
            ],
          )
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: CoilToggleGroup<T>(
              size: CoilSize.compact,
              semanticLabel: label,
              values: {value},
              onChanged: (values) {
                final picked = values.difference({value});
                if (picked.isNotEmpty) onChanged(picked.first);
              },
              options: [
                for (final MapEntry(:key, :value) in options.entries)
                  CoilOption(value: key, label: Text(value)),
              ],
            ),
          ),
  );
}

/// An on/off setting with its label beside the switch.
class PlaygroundToggle extends StatelessWidget {
  const PlaygroundToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    // The whole row toggles, not just the switch.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: _toggleRow(text),
      ),
    );
  }

  Widget _toggleRow(CoilTextTheme text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.caption),
              if (hint case final hint?) ...[
                const SizedBox(height: 2),
                Text(hint, style: text.muted.micro),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        CoilSwitch(
          value: value,
          onChanged: onChanged,
          semanticLabel: label,
        ),
      ],
    );
  }
}

/// A continuous or stepped value.
class PlaygroundSlider extends StatelessWidget {
  const PlaygroundSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    super.key,
    this.hint,
    this.divisions,
  });

  final String label;
  final String? hint;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    // The scrubber carries the label and the value inside its track.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoilSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          size: CoilSize.compact,
          label: Text(label),
          valueBuilder: (context, value) => Text(format(value)),
          semanticFormatter: format,
          semanticLabel: label,
          onChanged: onChanged,
        ),
        if (hint case final hint?) ...[
          const SizedBox(height: 4),
          Text(hint, style: text.muted.micro),
        ],
      ],
    );
  }
}

/// One-tap presets that set several settings at once; the preset matching
/// the current values shows selected.
class PlaygroundPresets<T> extends StatelessWidget {
  const PlaygroundPresets({
    required this.presets,
    required this.selected,
    required this.onPick,
    super.key,
  });

  /// Each preset's label.
  final Map<T, String> presets;

  /// The preset the current values match, if any.
  final T? selected;

  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 2,
    runSpacing: 2,
    children: [
      for (final MapEntry(:key, :value) in presets.entries)
        CoilButton(
          variant: key == selected
              ? CoilButtonVariant.secondary
              : CoilButtonVariant.ghost,
          size: CoilSize.compact,
          selected: key == selected,
          onPressed: () => onPick(key),
          child: Text(value),
        ),
    ],
  );
}
