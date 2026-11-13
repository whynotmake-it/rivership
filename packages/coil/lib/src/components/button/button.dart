import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The visual style of a [CoilButton].
enum CoilButtonVariant {
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
/// [child] is the label.
/// [leading] and [trailing] are icon slots that take any widget, styled
/// through [IconTheme]: the size for the current density, the label color,
/// and a `weight` that rises from [CoilIconWeight.rest] to
/// [CoilIconWeight.emphasis] on hover (the web's 1.5 → 2 stroke). The
/// package bundles no icons. [loadingIndicator] replaces the built-in
/// spinner.
///
/// Pressing collapses the fill by exactly 1 px per side at any width (the
/// web's shrinking box-shadow spread), rather than scaling.
class CoilButton extends StatefulWidget {
  /// Creates a labeled button.
  const CoilButton({
    required this.onPressed,
    required Widget this.child,
    super.key,
    this.leading,
    this.trailing,
    this.variant = CoilButtonVariant.primary,
    this.size,
    this.loading = false,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.semanticLabel,
    this.loadingIndicator,
  }) : icon = null;

  /// Creates a square, icon-only button. [semanticLabel] names it for
  /// assistive technology.
  const CoilButton.icon({
    required this.onPressed,
    required Widget this.icon,
    required String this.semanticLabel,
    this.loadingIndicator,
    super.key,
    this.variant = CoilButtonVariant.primary,
    this.size,
    this.loading = false,
    this.selected = false,
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
  final CoilButtonVariant variant;

  /// Pins the button to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Shows a spinner and blocks presses while keeping full strength (a
  /// loading button is busy, not unavailable).
  final bool loading;

  /// Forces the pressed colors, for a button that holds something open
  /// (a menu trigger while its menu shows).
  final bool selected;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// instance.
  final CoilMotion? motion;

  /// Overrides the label for assistive technology.
  final String? semanticLabel;

  /// Replaces the built-in spinner shown while [loading]. It is laid out in
  /// an icon-sized box and inherits the label color through [IconTheme] and
  /// [DefaultTextStyle].
  final Widget? loadingIndicator;

  @override
  State<CoilButton> createState() => _CoilButtonState();
}

/// What a button looks like in one set of states.
@immutable
class _ButtonLook {
  const _ButtonLook({
    required this.fill,
    required this.label,
    required this.spread,
    required this.iconWeight,
  });

  final Color fill;
  final Color label;
  final double spread;
  final double iconWeight;
}

class _CoilButtonState extends State<CoilButton> {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  Track<Color>? _fill;
  Track<Color>? _label;
  Track<double>? _spread;
  Track<double>? _iconWeight;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  _ButtonLook _look(CoilColors c, Set<WidgetState> states) {
    final hovered =
        !widget.loading && states.contains(WidgetState.hovered) && _enabled;
    final pressed =
        !widget.loading && states.contains(WidgetState.pressed) && _enabled;
    final held = widget.selected || pressed;
    final dark = c.brightness == Brightness.dark;
    final clear = c.hover.withValues(alpha: 0);

    final Color fill;
    final Color label;
    switch (widget.variant) {
      case CoilButtonVariant.primary:
        fill = held
            ? CoilColorMix.oklab(c.foreground, c.background, 0.8)
            : hovered
            ? CoilColorMix.oklab(c.foreground, c.background, 0.9)
            : c.foreground;
        label = c.background;
      case CoilButtonVariant.secondary:
        fill = !held && hovered ? c.tintHover : c.tint;
        label = c.foreground;
      case CoilButtonVariant.tertiary:
        fill = held
            ? c.active
            : hovered
            ? c.hover
            : clear;
        label = c.foreground;
      case CoilButtonVariant.ghost:
        fill = held
            ? c.active
            : hovered
            ? c.hover
            : clear;
        label = held || hovered ? c.foreground : c.mutedForeground;
      case CoilButtonVariant.destructive:
        final rest = dark ? 0.20 : 0.15;
        final hover = dark ? 0.30 : 0.25;
        fill = c.red.withValues(
          alpha: widget.selected ? hover : (!pressed && hovered ? hover : rest),
        );
        label = c.redLabel;
    }
    return _ButtonLook(
      fill: fill,
      label: label,
      spread: pressed ? 0 : 1,
      iconWeight: hovered ? CoilIconWeight.emphasis : CoilIconWeight.rest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final iconOnly = widget.icon != null;
    final iconSize = sizes.iconSize;

    return Semantics(
      container: true,
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      value: widget.loading ? 'Loading' : null,
      child: CoilInteraction(
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
          final iconWeight = _iconWeight ??= Track(
            .single,
            initial: look.iconWeight,
          );
          final pressing = states.contains(WidgetState.pressed);
          final radius = theme.shape.item;
          final disabled = widget.onPressed == null && !widget.loading;

          return Opacity(
            opacity: disabled ? 0.5 : 1,
            child: CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: BorderRadius.circular(radius),
              child: TrackBuilder(
                animations: [
                  fill([.to(look.fill, motion: _motion.fade)]),
                  labelTrack([.to(look.label, motion: _motion.fade)]),
                  spread([
                    .to(
                      look.spread,
                      motion: pressing ? _motion.quick : _motion.standard,
                    ),
                  ]),
                  iconWeight([.to(look.iconWeight, motion: _motion.fade)]),
                ],
                builder: (context, value, _) {
                  final labelColor = value(labelTrack);
                  return CustomPaint(
                    painter: _ButtonSurfacePainter(
                      fill: value(fill),
                      spread: value(spread).clamp(0.0, 1.0),
                      radius: radius,
                      border: widget.variant == CoilButtonVariant.tertiary
                          ? theme.colors.border
                          : null,
                    ),
                    child: IconTheme(
                      data: IconThemeData(
                        size: iconSize,
                        applyTextScaling: true,
                        color: labelColor,
                        weight: value(iconWeight),
                      ),
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
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _spinner(CoilMetrics sizes) => SizedBox.square(
    dimension: sizes.iconSize,
    child: widget.loadingIndicator ?? _CoilSpinner(size: sizes.iconSize),
  );

  Widget _iconContent(CoilMetrics sizes) => SizedBox.square(
    dimension: sizes.controlHeight,
    child: Center(
      child: widget.loading ? _spinner(sizes) : widget.icon,
    ),
  );

  Widget _labelContent(CoilMetrics sizes) {
    final leading = widget.leading;
    final trailing = widget.trailing;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: sizes.buttonGap,
      children: [
        if (leading != null) leading,
        widget.child!,
        if (trailing != null) trailing,
      ],
    );
    if (widget.loading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: content),
          _spinner(sizes),
        ],
      );
    }
    // A minimum height plus symmetric padding: the label's line box sits
    // centered, and the button grows with the text scale.
    final padY = sizes.controlPaddingY(sizes.body);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: sizes.controlHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: leading != null
              ? sizes.buttonIconPaddingX
              : sizes.buttonPaddingX,
          end: trailing != null
              ? sizes.buttonIconPaddingX
              : sizes.buttonPaddingX,
          top: padY,
          bottom: padY,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: content),
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
    RSuperellipse box(double inset, double r) =>
        RSuperellipse.fromRectAndRadius(
          bounds.deflate(inset),
          Radius.circular(math.max(0, r)),
        );

    final border = this.border;
    if (border == null) {
      canvas.drawRSuperellipse(
        box(1 - spread, radius + spread),
        Paint()..color = fill,
      );
      return;
    }
    // Tertiary: the fill only reaches the surface box (1 px in); the ring
    // sits outside it at rest and inside it when pressed. The ring is the
    // even-odd difference of two concentric superellipses.
    canvas
      ..drawRSuperellipse(box(1, radius), Paint()..color = fill)
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRSuperellipse(box(1 - spread, radius + spread))
          ..addRSuperellipse(box(2 - spread, radius + spread - 1)),
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
class _CoilSpinner extends StatelessWidget {
  const _CoilSpinner({required this.size});

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
          // Grows with text, like the icons beside it.
          size: Size.square(MediaQuery.textScalerOf(context).scale(size)),
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
