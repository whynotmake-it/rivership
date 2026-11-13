import 'dart:math' as math;

import 'package:fluid_functionalism/src/foundation/color_mix.dart';
import 'package:fluid_functionalism/src/foundation/fluid_colors.dart';
import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart';
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/icons/fluid_icon.dart';
import 'package:fluid_functionalism/src/primitives/fluid_focus_ring.dart';
import 'package:fluid_functionalism/src/primitives/fluid_label.dart';
import 'package:fluid_functionalism/src/primitives/fluid_pressable.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The visual style of a [FluidButton].
enum FluidButtonVariant {
  /// Solid foreground fill: the one main action.
  primary,

  /// A see-through tint that takes on the surface beneath it.
  secondary,

  /// Transparent with a hairline border.
  tertiary,

  /// No fill until hovered; a muted label.
  ghost,

  /// A red wash under a red label.
  destructive,
}

/// A button (`registry/radix/button.tsx`).
///
/// [child] is the label; [leading] and [trailing] are icon slots that take
/// any widget. They get a [FluidIconTheme] (and [IconTheme]) with the size
/// for the current density and a stroke that thickens from 1.5 to 2 on
/// hover, which [FluidIcon]s follow.
///
/// Pressing collapses the fill by exactly 1 px per side at any width (the
/// web's shrinking box-shadow spread), rather than scaling.
class FluidButton extends StatefulWidget {
  /// Creates a labeled button.
  const FluidButton({
    required this.onPressed,
    required Widget this.child,
    super.key,
    this.leading,
    this.trailing,
    this.variant = FluidButtonVariant.primary,
    this.density,
    this.loading = false,
    this.active = false,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.semanticLabel,
  }) : icon = null;

  /// Creates a square, icon-only button. [semanticLabel] names it for
  /// assistive technology.
  const FluidButton.icon({
    required this.onPressed,
    required Widget this.icon,
    required String this.semanticLabel,
    super.key,
    this.variant = FluidButtonVariant.primary,
    this.density,
    this.loading = false,
    this.active = false,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
  }) : child = null,
       leading = null,
       trailing = null;

  /// Called on tap, Enter or Space. Null disables the button.
  final VoidCallback? onPressed;

  /// The label.
  final Widget? child;

  /// The icon of an icon-only button.
  final Widget? icon;

  /// A widget before the label, usually an icon.
  final Widget? leading;

  /// A widget after the label, usually an icon.
  final Widget? trailing;

  /// The visual style.
  final FluidButtonVariant variant;

  /// Pins the button to one size step. Null follows [FluidSizeScope].
  final FluidDensity? density;

  /// Shows a spinner and blocks presses while keeping full strength (a
  /// loading button is busy, not unavailable).
  final bool loading;

  /// Forces the pressed colors, for a button that holds something open
  /// (a menu trigger while its menu shows).
  final bool active;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([FluidThemeData.motion]) for this
  /// instance.
  final FluidMotionThemeData? motion;

  /// Overrides the label for assistive technology.
  final String? semanticLabel;

  @override
  State<FluidButton> createState() => _FluidButtonState();
}

/// What a button looks like in one set of states.
@immutable
class _ButtonLook {
  const _ButtonLook({
    required this.fill,
    required this.label,
    required this.spread,
    required this.stroke,
  });

  final Color fill;
  final Color label;
  final double spread;
  final double stroke;
}

class _FluidButtonState extends State<FluidButton> {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  FluidMotionThemeData get _motion =>
      FluidTheme.motionOf(context, override: widget.motion);

  Track<Color>? _fill;
  Track<Color>? _label;
  Track<double>? _spread;
  Track<double>? _stroke;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  _ButtonLook _look(FluidColors c, Set<WidgetState> states) {
    final hovered =
        !widget.loading && states.contains(WidgetState.hovered) && _enabled;
    final pressed =
        !widget.loading && states.contains(WidgetState.pressed) && _enabled;
    final held = widget.active || pressed;
    final dark = c.brightness == Brightness.dark;
    final clear = c.hover.withValues(alpha: 0);

    final Color fill;
    final Color label;
    switch (widget.variant) {
      case FluidButtonVariant.primary:
        fill = held
            ? FluidColorMix.oklab(c.foreground, c.background, 0.8)
            : hovered
            ? FluidColorMix.oklab(c.foreground, c.background, 0.9)
            : c.foreground;
        label = c.background;
      case FluidButtonVariant.secondary:
        fill = !held && hovered ? c.tintHover : c.tint;
        label = c.foreground;
      case FluidButtonVariant.tertiary:
        fill = held
            ? c.active
            : hovered
            ? c.hover
            : clear;
        label = c.foreground;
      case FluidButtonVariant.ghost:
        fill = held
            ? c.active
            : hovered
            ? c.hover
            : clear;
        label = held || hovered ? c.foreground : c.mutedForeground;
      case FluidButtonVariant.destructive:
        final rest = dark ? 0.20 : 0.15;
        final hover = dark ? 0.30 : 0.25;
        fill = c.red.withValues(
          alpha: widget.active ? hover : (!pressed && hovered ? hover : rest),
        );
        label = c.redLabel;
    }
    return _ButtonLook(
      fill: fill,
      label: label,
      spread: pressed ? 0 : 1,
      stroke: hovered ? 2 : 1.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final sizes = FluidTheme.sizesOf(context, density: widget.density);
    final iconOnly = widget.icon != null;
    final iconSize = sizes.iconSize;

    return Semantics(
      container: true,
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      value: widget.loading ? 'Loading' : null,
      child: FluidPressable(
        onPressed: _enabled ? widget.onPressed : null,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        statesController: widget.statesController,
        minHitTarget: sizes.minHitTarget,
        builder: (context, states, _) {
          final look = _look(theme.colors, states);
          final fill = _fill ??= Track(.colorRgb, initial: look.fill);
          final labelTrack = _label ??= Track(.colorRgb, initial: look.label);
          final spread = _spread ??= Track(.single, initial: look.spread);
          final stroke = _stroke ??= Track(.single, initial: look.stroke);
          final pressing = states.contains(WidgetState.pressed);
          final radius = theme.shape.item;
          final disabled = widget.onPressed == null && !widget.loading;

          return Opacity(
            opacity: disabled ? 0.5 : 1,
            child: FluidFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: BorderRadius.circular(radius),
              child: TrackBuilder(
                animations: [
                  fill([.to(look.fill, motion: _motion.color)]),
                  labelTrack([.to(look.label, motion: _motion.color)]),
                  spread([
                    .to(
                      look.spread,
                      motion: pressing ? _motion.press : _motion.release,
                    ),
                  ]),
                  stroke([.to(look.stroke, motion: _motion.color)]),
                ],
                builder: (context, value, _) {
                  final labelColor = value(labelTrack);
                  final iconTheme = FluidIconThemeData(
                    size: iconSize,
                    strokeWidth: value(stroke),
                    color: labelColor,
                  );
                  return CustomPaint(
                    painter: _ButtonSurfacePainter(
                      fill: value(fill),
                      spread: value(spread).clamp(0.0, 1.0),
                      radius: radius,
                      border: widget.variant == FluidButtonVariant.tertiary
                          ? theme.colors.border
                          : null,
                    ),
                    child: FluidIconTheme(
                      data: iconTheme,
                      child: IconTheme(
                        data: IconThemeData(size: iconSize, color: labelColor),
                        child: DefaultTextStyle(
                          style: theme.typography.style(
                            sizes.body,
                            color: labelColor,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          child: iconOnly
                              ? _iconContent(sizes)
                              : _labelContent(sizes),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _iconContent(FluidSizes sizes) => SizedBox.square(
    dimension: sizes.controlHeight,
    child: Center(
      child: widget.loading ? _FluidSpinner(size: sizes.iconSize) : widget.icon,
    ),
  );

  Widget _labelContent(FluidSizes sizes) {
    final leading = widget.leading;
    final trailing = widget.trailing;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: sizes.buttonGap,
      children: [
        if (leading != null) leading,
        // Centered on its cap height, like CSS text-box trim.
        FluidLabel(child: widget.child!),
        if (trailing != null) trailing,
      ],
    );
    if (widget.loading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: content),
          _FluidSpinner(size: sizes.iconSize),
        ],
      );
    }
    return SizedBox(
      height: sizes.controlHeight,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: leading != null
              ? sizes.buttonIconPaddingX
              : sizes.buttonPaddingX,
          end: trailing != null
              ? sizes.buttonIconPaddingX
              : sizes.buttonPaddingX,
        ),
        child: Center(widthFactor: 1, child: content),
      ),
    );
  }
}

/// Paints the button's fill (and the tertiary hairline).
///
/// The fill sits 1 px inside the bounds and a same-color spread of
/// [spread] px fills it back out; pressing takes the spread to 0. The
/// tertiary border is a 1 px ring whose outer edge follows the same spread,
/// so it moves inward with the surface.
class _ButtonSurfacePainter extends CustomPainter {
  _ButtonSurfacePainter({
    required this.fill,
    required this.spread,
    required this.radius,
    this.border,
  });

  final Color fill;
  final double spread;
  final double radius;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    RRect box(double inset, double r) => RRect.fromRectAndRadius(
      bounds.deflate(inset),
      Radius.circular(math.max(0, r)),
    );

    final border = this.border;
    if (border == null) {
      canvas.drawRRect(
        box(1 - spread, radius + spread),
        Paint()..color = fill,
      );
      return;
    }
    // Tertiary: the fill only reaches the surface box (1 px in); the ring
    // sits outside it at rest and inside it when pressed.
    canvas
      ..drawRRect(box(1, radius), Paint()..color = fill)
      ..drawDRRect(
        box(1 - spread, radius + spread),
        box(2 - spread, radius + spread - 1),
        Paint()..color = border,
      );
  }

  @override
  bool shouldRepaint(_ButtonSurfacePainter old) =>
      old.fill != fill ||
      old.spread != spread ||
      old.radius != radius ||
      old.border != border;
}

/// The loading spinner: an arc turning one eased lap per second.
class _FluidSpinner extends StatelessWidget {
  const _FluidSpinner({required this.size});

  final double size;

  static final _turn = Track<double>(.single, initial: 0);

  @override
  Widget build(BuildContext context) {
    final color =
        DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    return TrackBuilder(
      loop: LoopMode.loop,
      animations: [
        _turn([
          const .to(
            1,
            motion: CurvedMotion(
              Duration(seconds: 1),
              Cubic(0.65, 0, 0.35, 1),
            ),
          ),
        ], from: 0),
      ],
      builder: (context, value, _) => Transform.rotate(
        angle: value(_turn) * 2 * math.pi,
        child: CustomPaint(
          size: Size.square(size),
          painter: _SpinnerPainter(color),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final rect = Rect.fromCircle(
      center: Offset(8 * scale, 8 * scale),
      radius: 6.25 * scale,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round;
    // Two opposing arcs, like the web spinner mid-lap.
    canvas
      ..drawArc(rect, -math.pi / 2, math.pi * 0.55, false, paint)
      ..drawArc(rect, math.pi / 2, math.pi * 0.55, false, paint);
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}
