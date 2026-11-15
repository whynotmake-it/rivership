import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// Text in one of coil's type roles.
class RoleText extends StatelessWidget {
  const RoleText(
    this.text, {
    super.key,
    this.step = const CoilTypeStep(13, 20),
    this.weight = CoilWeight.normal,
    this.muted = false,
    this.maxLines,
    this.align,
  });

  /// Body text.
  const RoleText.body(String text, {Key? key, bool muted = false})
    : this(text, key: key, muted: muted);

  /// Captions and descriptions.
  const RoleText.caption(String text, {Key? key, bool muted = true})
    : this(text, key: key, step: const CoilTypeStep(12, 16), muted: muted);

  /// Section titles.
  const RoleText.title(String text, {Key? key})
    : this(
        text,
        key: key,
        step: const CoilTypeStep(14, 20),
        weight: CoilWeight.semibold,
      );

  final String text;
  final CoilTypeStep step;
  final CoilWeight weight;
  final bool muted;
  final int? maxLines;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    return Text(
      text,
      maxLines: maxLines,
      textAlign: align,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: theme.typography.style(
        step,
        weight: weight,
        color: muted ? theme.colors.mutedForeground : theme.colors.foreground,
      ),
    );
  }
}

/// A raised panel on coil's surface ladder.
class Panel extends StatelessWidget {
  const Panel({required this.child, super.key, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final colors = CoilTheme.of(context).colors;
    return CoilSurface(
      offset: CoilSurface.popoverOffset,
      shadowLevel: 1,
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.border),
          ),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// A titled group of controls in a panel.
class Section extends StatelessWidget {
  const Section({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoleText.caption(title),
          const SizedBox(height: 8),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }
}

/// A slider row with a label and a formatted value.
class PropertySlider extends StatelessWidget {
  const PropertySlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
    this.format,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double value)? format;

  @override
  Widget build(BuildContext context) {
    return CoilSlider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      label: Text(label),
      valueBuilder: (context, value) =>
          Text(format?.call(value) ?? value.toStringAsFixed(2)),
      onChanged: onChanged,
    );
  }
}

/// One choice out of a few, as coil tabs.
class Segmented<T extends Object> extends StatelessWidget {
  const Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: CoilTabs<T>(
        value: value,
        size: CoilSize.compact,
        tabs: [
          for (final MapEntry(:key, value: label) in options.entries)
            CoilTab(value: key, label: Text(label)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Colors offered for the dots. Null follows the theme's ink.
const swatches = <Color?>[
  null,
  Color(0xFFE5533D),
  Color(0xFFF5A524),
  Color(0xFF3AAA6B),
  Color(0xFF3D8BE5),
  Color(0xFF8A6CF0),
  Color(0xFFE85DAF),
];

/// Round color buttons; the first is the theme's ink.
class SwatchPicker extends StatelessWidget {
  const SwatchPicker({required this.value, required this.onChanged, super.key});

  final Color? value;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final swatch in swatches)
          Semantics(
            button: true,
            selected: swatch == value,
            label: swatch == null ? 'Ink' : 'Color',
            child: GestureDetector(
              onTap: () => onChanged(swatch),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: swatch ?? colors.foreground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: swatch == value ? colors.brand : colors.border,
                      width: swatch == value ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
