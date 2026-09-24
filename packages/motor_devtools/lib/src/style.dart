import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The debug label of the devtools' own controllers, which the controller
/// list leaves out.
const internalDebugLabel = 'motor_devtools';

/// Colors and text styles of the devtools, for one brightness.
@immutable
class DevToolsPalette {
  const DevToolsPalette._({
    required this.brightness,
    required this.surface,
    required this.fill,
    required this.pressed,
    required this.hairline,
    required this.text,
    required this.secondary,
    required this.tertiary,
    required this.accent,
    required this.shadow,
  });

  /// Picks the palette for [brightness].
  factory DevToolsPalette.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The light palette.
  static const light = DevToolsPalette._(
    brightness: Brightness.light,
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFF4F4F5),
    pressed: Color(0xFFE9E9EC),
    hairline: Color(0x14000000),
    text: Color(0xFF18181B),
    secondary: Color(0xFF71717A),
    tertiary: Color(0xFFA1A1AA),
    accent: Color(0xFF3D63DD),
    shadow: Color(0x24000000),
  );

  /// The dark palette.
  static const dark = DevToolsPalette._(
    brightness: Brightness.dark,
    surface: Color(0xFF1C1C1F),
    fill: Color(0xFF28282C),
    pressed: Color(0xFF323237),
    hairline: Color(0x17FFFFFF),
    text: Color(0xFFFAFAFA),
    secondary: Color(0xFFA1A1AA),
    tertiary: Color(0xFF71717A),
    accent: Color(0xFF8AA4FF),
    shadow: Color(0x66000000),
  );

  /// This palette with [text] as its text color, and its secondary colors
  /// derived from it.
  DevToolsPalette withText(Color text, {Color? accent}) => DevToolsPalette._(
    brightness: brightness,
    surface: surface,
    fill: text.withValues(alpha: 0.05),
    pressed: text.withValues(alpha: 0.1),
    hairline: text.withValues(alpha: 0.08),
    text: text,
    secondary: text.withValues(alpha: 0.62),
    tertiary: text.withValues(alpha: 0.4),
    accent: accent ?? this.accent,
    shadow: shadow,
  );

  /// The brightness this palette is for.
  final Brightness brightness;

  /// The panel and bubble background.
  final Color surface;

  /// Background of controls and inset areas.
  final Color fill;

  /// Background of a pressed control.
  final Color pressed;

  /// Separators and outlines.
  final Color hairline;

  /// Primary text and marks.
  final Color text;

  /// Secondary text.
  final Color secondary;

  /// Tertiary text and inactive marks.
  final Color tertiary;

  /// The single accent: the playhead and live state.
  final Color accent;

  /// The floating surface's shadow.
  final Color shadow;

  /// A title, such as a controller name.
  TextStyle get title => TextStyle(
    color: text,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.2,
  );

  /// Body text.
  TextStyle get body => TextStyle(
    color: text,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.25,
  );

  /// Small secondary text.
  TextStyle get caption => TextStyle(
    color: secondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  /// A small section heading.
  TextStyle get label => TextStyle(
    color: secondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Axis labels on graphs.
  TextStyle get axis => TextStyle(
    color: tertiary,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Dart code.
  TextStyle get code => TextStyle(
    color: text,
    fontSize: 11,
    height: 1.35,
    fontFamily: 'Menlo',
    fontFamilyFallback: const ['Consolas', 'Roboto Mono', 'monospace'],
  );

  /// Numbers that update live.
  TextStyle get numeric => TextStyle(
    color: secondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.25,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Provides the [DevToolsPalette] to the devtools subtree.
class DevToolsTheme extends InheritedWidget {
  /// Provides [palette] to [child].
  const DevToolsTheme({required this.palette, required super.child, super.key});

  /// The palette in effect.
  final DevToolsPalette palette;

  /// The nearest palette.
  static DevToolsPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevToolsTheme>()?.palette ??
      DevToolsPalette.light;

  @override
  bool updateShouldNotify(DevToolsTheme oldWidget) =>
      oldWidget.palette != palette;
}

/// A quick, lightly damped spring for small interface feedback.
const quickMotion = Motion.smoothSpring(duration: Duration(milliseconds: 260));

/// A tap target that dims and shrinks slightly while pressed.
class Pressable extends StatefulWidget {
  /// Creates a pressable area around [child].
  const Pressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.pressedScale = 0.96,
    super.key,
  });

  /// The content.
  final Widget child;

  /// Called on tap, or null to disable.
  final VoidCallback? onTap;

  /// The accessibility label.
  final String? semanticLabel;

  /// The scale while pressed.
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        child: SingleMotionBuilder(
          value: _pressed ? 1 : 0,
          motion: quickMotion,
          debugLabel: internalDebugLabel,
          child: widget.child,
          builder: (context, value, child) => Opacity(
            opacity: enabled ? 1 - value * 0.3 : 0.4,
            child: Transform.scale(
              scale: 1 - (1 - widget.pressedScale) * value,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The painted icons used by the devtools, so they need no icon font.
enum Glyph {
  /// Three staggered lanes: the devtools mark.
  mark,

  /// A play triangle.
  play,

  /// Two pause bars.
  pause,

  /// A circular replay arrow.
  replay,

  /// A chevron pointing left.
  back,

  /// A chevron pointing right.
  forward,

  /// A cross.
  close,

  /// A pencil.
  edit,
}

/// Paints a [Glyph].
class GlyphIcon extends StatelessWidget {
  /// Paints [glyph] at [size] in [color].
  const GlyphIcon(this.glyph, {required this.color, this.size = 16, super.key});

  /// The icon to paint.
  final Glyph glyph;

  /// The icon's color.
  final Color color;

  /// The icon's square extent.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _GlyphPainter(glyph, color)),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.scale(s / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    switch (glyph) {
      case Glyph.mark:
        stroke.strokeWidth = 2.6;
        canvas
          ..drawLine(const Offset(4, 7), const Offset(14, 7), stroke)
          ..drawLine(const Offset(8, 12), const Offset(20, 12), stroke)
          ..drawLine(const Offset(6, 17), const Offset(12, 17), stroke);
      case Glyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5.5)
            ..lineTo(18.5, 12)
            ..lineTo(8, 18.5)
            ..close(),
          fill..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 5.5)
            ..lineTo(18.5, 12)
            ..lineTo(8, 18.5)
            ..close(),
          stroke..strokeWidth = 1.5,
        );
      case Glyph.pause:
        for (final x in const [7.5, 14.5]) {
          canvas.drawRRect(
            RRect.fromLTRBR(x, 5.5, x + 2.5, 18.5, const Radius.circular(1)),
            fill,
          );
        }
      case Glyph.replay:
        final rect = Rect.fromCircle(center: const Offset(12, 12.5), radius: 7);
        canvas.drawArc(rect, -math.pi * 0.35, math.pi * 1.6, false, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(10.5, 2.5)
            ..lineTo(14.5, 5.3)
            ..lineTo(10.8, 8.5),
          stroke,
        );
      case Glyph.back:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 6)
            ..lineTo(8.5, 12)
            ..lineTo(14.5, 18),
          stroke,
        );
      case Glyph.forward:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 6)
            ..lineTo(15.5, 12)
            ..lineTo(9.5, 18),
          stroke,
        );
      case Glyph.edit:
        canvas
          ..drawLine(const Offset(6.5, 17.5), const Offset(16, 8), stroke)
          ..drawLine(const Offset(14, 6), const Offset(18, 10), stroke)
          ..drawLine(const Offset(5, 19), const Offset(6.5, 17.5), stroke);
      case Glyph.close:
        canvas
          ..drawLine(const Offset(7, 7), const Offset(17, 17), stroke)
          ..drawLine(const Offset(17, 7), const Offset(7, 17), stroke);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// A round icon button.
class GlyphButton extends StatelessWidget {
  /// Creates a button showing [glyph].
  const GlyphButton(
    this.glyph, {
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
    this.size = 32,
    super.key,
  });

  /// The icon.
  final Glyph glyph;

  /// Called on tap.
  final VoidCallback? onTap;

  /// The accessibility label.
  final String semanticLabel;

  /// Whether the button has a solid background, for the primary action.
  final bool filled;

  /// The button's diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      pressedScale: 0.9,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? palette.text : palette.fill,
          shape: BoxShape.circle,
        ),
        child: GlyphIcon(
          glyph,
          color: filled ? palette.surface : palette.text,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// A row of mutually exclusive options with a sliding selection.
class Segmented<T> extends StatelessWidget {
  /// Creates a segmented control over [options].
  const Segmented({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.keyOf,
    super.key,
  });

  /// The options, in order.
  final List<T> options;

  /// The selected option, or null for none.
  final T? selected;

  /// The text shown for an option.
  final String Function(T option) labelOf;

  /// Called when an option is tapped.
  final ValueChanged<T> onSelected;

  /// An optional key for each option's tap target.
  final Key Function(T option)? keyOf;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final index = selected == null ? -1 : options.indexOf(selected as T);
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              if (index >= 0)
                SingleMotionBuilder(
                  value: index * width,
                  motion: quickMotion,
                  debugLabel: internalDebugLabel,
                  builder: (context, left, child) =>
                      Positioned(left: left, top: 0, bottom: 0, child: child!),
                  child: Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow.withValues(alpha: 0.12),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Pressable(
                        key: keyOf?.call(option),
                        onTap: () => onSelected(option),
                        semanticLabel: labelOf(option),
                        pressedScale: 1,
                        child: Center(
                          child: Text(
                            labelOf(option),
                            maxLines: 1,
                            style: palette.caption.copyWith(
                              color: option == selected
                                  ? palette.text
                                  : palette.secondary,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A minimal horizontal slider.
class ValueSlider extends StatelessWidget {
  /// Creates a slider between [min] and [max].
  const ValueSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  /// The name of the value.
  final String label;

  /// The formatted value.
  final String valueLabel;

  /// The current value.
  final double value;

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// Called while dragging.
  final ValueChanged<double> onChanged;

  /// Called once the user lets go.
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: palette.caption),
            const Spacer(),
            Text(valueLabel, style: palette.numeric),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            void update(Offset position) {
              final fraction = (position.dx / constraints.maxWidth).clamp(
                0.0,
                1.0,
              );
              onChanged(min + (max - min) * fraction);
            }

            final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
            return Semantics(
              slider: true,
              label: label,
              value: valueLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => update(details.localPosition),
                onTapUp: (_) => onChangeEnd(),
                onHorizontalDragStart: (details) =>
                    update(details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    update(details.localPosition),
                onHorizontalDragEnd: (_) => onChangeEnd(),
                child: SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: _SliderPainter(fraction, palette),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter(this.fraction, this.palette);

  final double fraction;
  final DevToolsPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const knob = 8.0;
    final y = size.height / 2;
    final x = knob + (size.width - knob * 2) * fraction;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(
          0,
          y - 1.5,
          size.width,
          y + 1.5,
          const Radius.circular(2),
        ),
        Paint()..color = palette.fill,
      )
      ..drawRRect(
        RRect.fromLTRBR(0, y - 1.5, x, y + 1.5, const Radius.circular(2)),
        Paint()..color = palette.text,
      )
      ..drawCircle(
        Offset(x, y + 0.5),
        knob,
        Paint()
          ..color = palette.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      )
      ..drawCircle(Offset(x, y), knob, Paint()..color = palette.surface)
      ..drawCircle(
        Offset(x, y),
        knob,
        Paint()
          ..color = palette.hairline
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.palette != palette;
}

/// The spring used to fold and unfold sections.
const foldMotion = Motion.smoothSpring(duration: Duration(milliseconds: 380));

/// Unfolds [child] downward while [open], and removes it once folded.
class Disclosure extends StatelessWidget {
  /// Shows [child] while [open].
  const Disclosure({required this.open, required this.child, super.key});

  /// Whether [child] is shown.
  final bool open;

  /// The folding content.
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: open ? 1 : 0,
    motion: foldMotion,
    debugLabel: internalDebugLabel,
    child: child,
    builder: (context, t, child) {
      if (!open && t < 0.001) return const SizedBox.shrink();
      if (open && t > 0.999) return child!;
      final visible = t.clamp(0.0, 1.0);
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: visible,
          child: Opacity(opacity: visible, child: child),
        ),
      );
    },
  );
}

/// A tappable row with a chevron that turns while [open].
class DisclosureRow extends StatelessWidget {
  /// Creates a row titled [title].
  const DisclosureRow({
    required this.title,
    required this.open,
    required this.onTap,
    this.trailing,
    super.key,
  });

  /// The row's title.
  final String title;

  /// Short text after the title, such as the current state.
  final String? trailing;

  /// Whether the section below is unfolded.
  final bool open;

  /// Toggles the section.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      pressedScale: 1,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Text(title, style: palette.label),
            const SizedBox(width: 8),
            if (trailing case final trailing?)
              Expanded(
                child: Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.caption,
                ),
              )
            else
              const Spacer(),
            SingleMotionBuilder(
              value: open ? 0.25 : 0,
              motion: foldMotion,
              debugLabel: internalDebugLabel,
              builder: (context, turns, child) =>
                  Transform.rotate(angle: turns * 2 * math.pi, child: child),
              child: GlyphIcon(Glyph.forward, color: palette.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small selectable label.
class Tag extends StatelessWidget {
  /// Creates a tag reading [label].
  const Tag({
    required this.label,
    required this.selected,
    required this.onTap,
    this.marked = false,
    this.outlined = false,
    super.key,
  });

  /// The text.
  final String label;

  /// Whether the tag is selected.
  final bool selected;

  /// Whether to show a dot, such as for a tuned track.
  final bool marked;

  /// Whether an unselected tag is outlined rather than filled.
  final bool outlined;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? palette.text
              : outlined
              ? null
              : palette.fill,
          border: outlined && !selected
              ? Border.all(color: palette.hairline)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marked) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: palette.caption.copyWith(
                color: selected ? palette.surface : palette.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline separator.
class Hairline extends StatelessWidget {
  /// Creates a horizontal hairline.
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: DevToolsTheme.of(context).hairline);
}

/// Formats [duration] compactly, such as `420 ms` or `1.25 s`.
String formatDuration(Duration duration) {
  final ms = duration.inMicroseconds / Duration.microsecondsPerMillisecond;
  if (ms.abs() < 1000) return '${ms.round()} ms';
  return '${(ms / 1000).toStringAsFixed(2)} s';
}

/// Formats a track value for display.
String formatValue(Object? value) => switch (value) {
  final double v => v.toStringAsFixed(2),
  final num v => '$v',
  Offset(:final dx, :final dy) =>
    '${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)}',
  Size(:final width, :final height) =>
    '${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)}',
  Alignment(:final x, :final y) =>
    '${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}',
  final Color c => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}',
  null => '–',
  _ when '$value'.contains('Instance of') => '',
  _ => '$value',
};
