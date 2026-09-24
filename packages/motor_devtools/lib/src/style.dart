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
    required this.outline,
    required this.frame,
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
    outline: Color(0xFFD4D4D8),
    frame: Color(0xFF8E8E96),
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
    outline: Color(0xFF3F3F46),
    frame: Color(0xFF6B6B74),
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
    outline: outline,
    frame: frame,
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

  /// The edge of handles.
  final Color outline;

  /// The edge of the bubble and panel. It is opaque and contrasts with both
  /// the surface and similar app backgrounds, so the tools stand out.
  final Color frame;

  /// A title, such as a controller name.
  TextStyle get title => TextStyle(
    color: text,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  /// Body text.
  TextStyle get body => TextStyle(
    color: text,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.2,
  );

  /// Small secondary text.
  TextStyle get caption => TextStyle(
    color: secondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.2,
  );

  /// A small section heading.
  TextStyle get label => TextStyle(
    color: secondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  /// Axis labels on graphs.
  TextStyle get axis => TextStyle(
    color: tertiary,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
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
    letterSpacing: 0,
    height: 1.2,
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
const quickMotion = Motion.smoothSpring(duration: Duration(milliseconds: 220));

/// The devtools' rounded shape: a superellipse with corner [radius].
RoundedSuperellipseBorder rounded(
  double radius, {
  Color? side,
  double sideWidth = 1,
}) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: side == null
      ? BorderSide.none
      : BorderSide(color: side, width: sideWidth),
);

/// Pointers that went down on a control with gestures of its own.
final heldPointers = <int>{};

/// Holds pointers that go down on [child], so a drag that starts there keeps
/// [child]'s own behavior rather than moving the devtools window.
class HoldsPointer extends StatelessWidget {
  /// Holds pointers that go down on [child].
  const HoldsPointer({required this.child, super.key});

  /// The control.
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (event) => heldPointers.add(event.pointer),
    onPointerUp: (event) => heldPointers.remove(event.pointer),
    onPointerCancel: (event) => heldPointers.remove(event.pointer),
    child: child,
  );
}

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
      child: HoldsPointer(
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
      ),
    );
  }
}

/// The painted icons used by the devtools, so they need no icon font.
enum Glyph {
  /// A ball above a concentric motion arc: the logo.
  logo,

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

  /// A horizontal bar: minimize.
  minimize,

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
      case Glyph.logo:
        // The geometry of example_design's LogoGlyph, which a published
        // package can't depend on.
        const height = 1 + 1.5 + 1 / 6 + 1 / 4;
        const radius = 18 / height;
        const center = Offset(12, 3 + radius);
        const spread = math.pi * .3;
        canvas
          ..drawCircle(center, radius, fill)
          ..drawArc(
            Rect.fromCircle(center: center, radius: radius * 1.5 + radius / 6),
            (math.pi - spread) / 2,
            spread,
            false,
            stroke..strokeWidth = radius / 2,
          );
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
        // Material's `replay` icon, so it needs no icon font.
        canvas.drawPath(
          Path()
            ..moveTo(12, 5)
            ..lineTo(12, 1)
            ..lineTo(7, 6)
            ..lineTo(12, 11)
            ..lineTo(12, 7)
            ..cubicTo(15.31, 7, 18, 9.69, 18, 13)
            ..cubicTo(18, 16.31, 15.31, 19, 12, 19)
            ..cubicTo(8.69, 19, 6, 16.31, 6, 13)
            ..lineTo(4, 13)
            ..cubicTo(4, 17.42, 7.58, 21, 12, 21)
            ..cubicTo(16.42, 21, 20, 17.42, 20, 13)
            ..cubicTo(20, 8.58, 16.42, 5, 12, 5)
            ..close(),
          fill,
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
        stroke.strokeWidth = 1.7;
        canvas
          ..drawPath(
            Path()
              ..moveTo(4.5, 19.5)
              ..lineTo(5.5, 15)
              ..lineTo(15.5, 5)
              ..lineTo(19, 8.5)
              ..lineTo(9, 18.5)
              ..close(),
            stroke,
          )
          ..drawLine(const Offset(13, 7.5), const Offset(16.5, 11), stroke);
      case Glyph.minimize:
        canvas.drawLine(const Offset(7, 12), const Offset(17, 12), stroke);
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
        decoration: ShapeDecoration(
          color: filled ? palette.text : palette.fill,
          shape: const CircleBorder(),
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
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(color: palette.fill, shape: rounded(9)),
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
                    decoration: ShapeDecoration(
                      color: palette.surface,
                      shape: rounded(7, side: palette.hairline),
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
              child: HoldsPointer(
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
    const track = Radius.circular(1.5);
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0, y - 1.5, size.width, y + 1.5, track),
        Paint()..color = palette.fill,
      )
      ..drawRRect(
        RRect.fromLTRBR(0, y - 1.5, x, y + 1.5, track),
        Paint()..color = palette.text,
      )
      ..drawCircle(Offset(x, y), knob, Paint()..color = palette.surface)
      ..drawCircle(
        Offset(x, y),
        knob,
        Paint()
          ..color = palette.outline
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.palette != palette;
}

/// The spring used to fold and unfold sections.
const foldMotion = Motion.smoothSpring(duration: Duration(milliseconds: 300));

/// Unfolds [child] downward while [open], and removes it once folded.
class Disclosure extends StatefulWidget {
  /// Shows [child] while [open].
  const Disclosure({required this.open, required this.child, super.key});

  /// Whether [child] is shown.
  final bool open;

  /// The folding content.
  final Widget child;

  static const _closeMotion = Motion.smoothSpring(
    duration: Duration(milliseconds: 380),
  );

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> {
  /// Whether to unfold. It follows [Disclosure.open] one frame late when
  /// opening, so the content is built before the unfold starts.
  late var _open = widget.open;

  @override
  void didUpdateWidget(Disclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.open) {
      _open = false;
    } else if (!_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) setState(() => _open = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    final building = widget.open;
    return SingleMotionBuilder(
      value: open ? 1 : 0,
      motion: open ? foldMotion : Disclosure._closeMotion,
      debugLabel: internalDebugLabel,
      child: widget.child,
      builder: (context, t, child) {
        if (!building && !open && t < 0.001) return const SizedBox.shrink();
        final height = t.clamp(0.0, 1.0);
        // Opening, the height leads and the content fades in behind it.
        // Closing, the content fades and lifts before the height folds, so
        // the clip edge never cuts through visible content.
        final opacity = open
            ? ((t - 0.25) / 0.75).clamp(0.0, 1.0)
            : ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        return ClipRect(
          clipBehavior: height >= 1 ? Clip.none : Clip.hardEdge,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: height,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - opacity)),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
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
        height: 32,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(
          color: selected
              ? palette.text
              : outlined
              ? null
              : palette.fill,
          shape: rounded(
            8,
            side: outlined && !selected ? palette.hairline : null,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marked) ...[
              Container(
                width: 5,
                height: 5,
                decoration: ShapeDecoration(
                  color: palette.accent,
                  shape: const CircleBorder(),
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

/// A small text button in the accent color.
class TextAction extends StatelessWidget {
  /// Creates a button reading [label].
  const TextAction(this.label, {required this.onTap, super.key});

  /// The text.
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: palette.label.copyWith(color: palette.accent, fontSize: 12),
        ),
      ),
    );
  }
}

/// A short note on a tinted background.
class Note extends StatelessWidget {
  /// Shows [text].
  const Note(this.text, {super.key});

  /// The note.
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: ShapeDecoration(color: palette.fill, shape: rounded(10)),
      child: Text(text, style: palette.caption),
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
