import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/button/button_style.dart';
import 'package:coil/src/components/button/button_variant.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The animated parts of a [CoilButton], as Motor tracks. Use them as keys
/// of [CoilButton.motions] or [CoilThemeData.trackMotions].
final class CoilButtonTrack<T extends Object> extends Track<T> {
  CoilButtonTrack._(super.converter, {required String super.debugLabel});

  /// The surface color. Default motion: `fade`.
  static final fill = CoilButtonTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilButton.fill',
  );

  /// The label and icon color. Default motion: `fade`.
  static final label = CoilButtonTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilButton.label',
  );

  /// The 1 px press collapse, 1 (rest) to 0 (pressed). Default motion:
  /// `quick` while pressing, `standard` on release.
  static final collapse = CoilButtonTrack<double>._(
    .single,
    debugLabel: 'CoilButton.collapse',
  );

  /// The icon weight. Default motion: `fade`.
  static final weight = CoilButtonTrack<double>._(
    .single,
    debugLabel: 'CoilButton.weight',
  );
}

/// A button.
///
/// [child] is the label. [leading] and [trailing] take any widget and are
/// styled through [IconTheme]: icon size, the label color, and a weight that
/// rises on hover. Pressing shrinks the fill by 1 px per side.
///
/// While [loading], a spinner takes the leading slot (the icon of an
/// icon-only button, or the whole content when there is no leading slot) and
/// presses are ignored. The width stays locked and the button keeps full
/// strength. The animated parts are [CoilButtonTrack]s; override them with
/// [motions].
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
    this.motions,
    this.style,
    this.semanticLabel,
    this.loadingIndicator,
    this.loadingLabel,
  }) : icon = null;

  /// Creates a square, icon-only button. [semanticLabel] names it for
  /// assistive technology.
  const CoilButton.icon({
    required this.onPressed,
    required Widget this.icon,
    required String this.semanticLabel,
    this.loadingIndicator,
    this.loadingLabel,
    super.key,
    this.variant = CoilButtonVariant.primary,
    this.size,
    this.loading = false,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
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

  /// Per-track motions for this instance, keyed by [CoilButtonTrack]s:
  /// `motions: {.collapse: const .snappySpring()}`. They win over the
  /// theme's [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilButtonTrack<Object>, Motion>? motions;

  /// Overrides for this button's look, on top of the theme's
  /// [CoilButtonStyle] and the defaults.
  final CoilButtonStyle? style;

  /// Overrides the label for assistive technology.
  final String? semanticLabel;

  /// What assistive technology announces as the button's value while
  /// [loading] (for example "Loading", in the app's language).
  final String? loadingLabel;

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

  /// Whether the tracks have played once: the first build starts them at
  /// the resting look instead of animating in from nothing.
  bool _started = false;

  Motion _motionFor(
    CoilButtonTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

  bool get _enabled => widget.onPressed != null && !widget.loading;

  _ButtonLook _look(CoilButtonStyle style, Set<WidgetState> raw) {
    final hovered = raw.contains(WidgetState.hovered) && _enabled;
    final pressed = raw.contains(WidgetState.pressed) && _enabled;
    final states = {
      if (hovered) WidgetState.hovered,
      if (pressed) WidgetState.pressed,
      if (widget.selected) WidgetState.selected,
      if (widget.onPressed == null) WidgetState.disabled,
    };
    return _ButtonLook(
      fill: style.fill!.resolve(states)!,
      label: style.foreground!.resolve(states)!,
      spread: pressed ? 0 : 1,
      iconWeight: hovered ? CoilIconWeight.emphasis : CoilIconWeight.rest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final iconOnly = widget.icon != null;
    final style = CoilButtonStyle.fallback(
      theme,
      sizes,
      widget.variant,
    ).merge(CoilTheme.styleOf<CoilButtonStyle>(context)).merge(widget.style);
    final iconSize = style.iconSize!;

    return Semantics(
      container: true,
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      value: widget.loading ? widget.loadingLabel : null,
      child: CoilInteraction(
        onPressed: _enabled ? widget.onPressed : null,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        statesController: widget.statesController,
        minHitTarget: sizes.minHitTarget,
        builder: (context, states, _) {
          final look = _look(style, states);
          final first = !_started;
          _started = true;
          final pressing = states.contains(WidgetState.pressed);
          final radius = style.radius!;
          final disabled = widget.onPressed == null && !widget.loading;

          return Opacity(
            opacity: disabled ? 0.5 : 1,
            child: CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: BorderRadius.circular(radius),
              child: TrackBuilder(
                animations: [
                  CoilButtonTrack.fill([
                    .to(
                      look.fill,
                      motion: _motionFor(
                        CoilButtonTrack.fill,
                        _motion.fade,
                        spatial: false,
                      ),
                    ),
                  ], from: first ? look.fill : null),
                  CoilButtonTrack.label([
                    .to(
                      look.label,
                      motion: _motionFor(
                        CoilButtonTrack.label,
                        _motion.fade,
                        spatial: false,
                      ),
                    ),
                  ], from: first ? look.label : null),
                  CoilButtonTrack.collapse([
                    .to(
                      look.spread,
                      motion: _motionFor(
                        CoilButtonTrack.collapse,
                        pressing ? _motion.quick : _motion.standard,
                      ),
                    ),
                  ], from: first ? look.spread : null),
                  CoilButtonTrack.weight([
                    .to(
                      look.iconWeight,
                      motion: _motionFor(
                        CoilButtonTrack.weight,
                        _motion.fade,
                        spatial: false,
                      ),
                    ),
                  ], from: first ? look.iconWeight : null),
                ],
                builder: (context, value, _) {
                  final labelColor = value(CoilButtonTrack.label);
                  return CustomPaint(
                    painter: _ButtonSurfacePainter(
                      fill: value(CoilButtonTrack.fill),
                      spread: value(CoilButtonTrack.collapse).clamp(0.0, 1.0),
                      radius: radius,
                      border: style.border!.a == 0 ? null : style.border,
                    ),
                    child: IconTheme(
                      data: IconThemeData(
                        size: iconSize,
                        applyTextScaling: true,
                        color: labelColor,
                        weight: value(CoilButtonTrack.weight),
                      ),
                      child: DefaultTextStyle(
                        style: style.textStyle!.copyWith(color: labelColor),
                        maxLines: 1,
                        softWrap: false,
                        child: iconOnly
                            ? _iconContent(sizes, style)
                            : _labelContent(sizes, style),
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

  /// The swap between idle content and the spinner: the blur-fade on
  /// `quick`, out on `quickExit`.
  Widget _swap(Widget child) => MotionSwitcher(
    motion: _motion.quick,
    exitMotion: _motion.quickExit,
    transitionBuilder: CoilBlurFade.transition(blur: 2, scale: 0.9),
    debugLabel: 'CoilButton.loading',
    child: child,
  );

  Widget _spinner() => KeyedSubtree(
    key: const ValueKey('spinner'),
    child: Builder(
      builder: (context) => SizedBox.square(
        // Like the icons beside it, the slot grows with the text.
        dimension: CoilIconSize.of(context),
        child: widget.loadingIndicator ?? const _CoilSpinner(),
      ),
    ),
  );

  Widget _iconContent(CoilMetrics sizes, CoilButtonStyle style) {
    final box = style.minHeight!;
    return SizedBox.square(
      dimension: box,
      child: Center(
        child: _swap(
          widget.loading
              ? _spinner()
              : KeyedSubtree(key: const ValueKey('idle'), child: widget.icon!),
        ),
      ),
    );
  }

  Widget _labelContent(CoilMetrics sizes, CoilButtonStyle style) {
    final leading = widget.leading;
    final trailing = widget.trailing;
    Widget row(Widget? leadingSlot) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: sizes.buttonGap,
      children: [
        if (leadingSlot != null) leadingSlot,
        widget.child!,
        if (trailing != null) trailing,
      ],
    );

    Widget content;
    if (leading != null) {
      // The spinner takes the leading slot; the label stays put.
      content = row(
        _swap(
          widget.loading
              ? _spinner()
              : KeyedSubtree(key: const ValueKey('idle'), child: leading),
        ),
      );
    } else if (widget.loading) {
      // No slot to take: the spinner replaces the content, which stays
      // laid out (unseen) so the width doesn't change.
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: ExcludeSemantics(child: row(null))),
          _swap(_spinner()),
        ],
      );
    } else {
      content = Stack(
        alignment: Alignment.center,
        children: [
          _swap(
            KeyedSubtree(
              key: const ValueKey('idle'),
              child: row(null),
            ),
          ),
        ],
      );
    }
    // A minimum height plus symmetric padding: the label's line box sits
    // centered, and the button grows with the text scale.
    final padY = sizes.controlPaddingY(sizes.body);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.minHeight!),
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

/// The loading spinner: an arc turning one eased lap per second. It fills
/// the icon-sized box it is given. Reduced motion stops the turn.
class _CoilSpinner extends StatelessWidget {
  const _CoilSpinner();

  static final _turn = Track<double>(.single, initial: 0);

  static const _lap = CurvedMotion(
    Duration(seconds: 1),
    Cubic(0.65, 0, 0.35, 1),
  );

  @override
  Widget build(BuildContext context) {
    final color =
        DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    final painter = CustomPaint(painter: _SpinnerPainter(color));
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return painter;
    return TrackBuilder(
      loop: LoopMode.loop,
      animations: [
        _turn([const .to(1, motion: _lap)], from: 0),
      ],
      builder: (context, value, child) =>
          Transform.rotate(angle: value(_turn) * 2 * math.pi, child: child),
      child: painter,
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
