import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/button/button_style.dart';
import 'package:coil/src/components/button/button_variant.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The animated parts of a [CoilButton], as Motor tracks. Use them as keys
/// of [CoilButton.motions] or [CoilButtonStyle.motions].
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

  /// How hovered the button's lighting is, 0 to 1, under a plastic theme
  /// (`CoilThemeData.plasticity`). Default motion: `fade`.
  static final light = CoilButtonTrack<double>._(
    .single,
    debugLabel: 'CoilButton.light',
  );

  /// The button's width: a label that changes, a leading or trailing part
  /// (or the spinner) that comes or goes. Default motion: `standard`
  /// growing, `standardExit` shrinking; the content fades on `fade` /
  /// `fadeExit`.
  static final size = CoilButtonTrack<double>._(
    .single,
    debugLabel: 'CoilButton.size',
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
/// While [loading], a spinner takes the leading slot and presses are
/// ignored; the button keeps full strength. A [leading] widget (and an
/// icon-only button's icon) is replaced by the spinner in place, so the
/// size stays. Without a [leading] widget the spinner enters beside the
/// label: the button grows by the spinner and its gap, and the label stays
/// visible.
///
/// The button springs to its new width when its own content changes: a new
/// label, or a leading or trailing part that comes or goes. When the
/// constraints around it change, it relayouts at once. The animated parts
/// are [CoilButtonTrack]s; override them with [motions].
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
  /// style's [CoilButtonStyle.motions] and the tokens.
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
    required this.light,
  });

  final Color fill;
  final Color label;
  final double spread;
  final double iconWeight;
  final double light;
}

class _CoilButtonState extends State<CoilButton> {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  Motion _motionFor(
    CoilButtonTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    styled:
        (CoilTheme.styleOf<CoilButtonStyle>(context)?.merge(widget.style) ??
                widget.style)
            ?.motions,
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
      light: hovered ? 1 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    // In a text field's slot: compact, concentric with the field's corner,
    // and the field takes the taps around it. Explicit size and style win.
    final slot = CoilInputSlotScope.maybeOf(context);
    var sizes = CoilTheme.metricsOf(context, size: widget.size ?? slot?.size);
    // At the slot's size step, as tall as fits the field without growing
    // it: a compact button is as tall as a compact field.
    if (slot != null &&
        sizes.size == slot.size &&
        sizes.controlHeight > slot.maxExtent) {
      sizes = sizes.copyWith(controlHeight: slot.maxExtent);
    }
    final iconOnly = widget.icon != null;
    var style = CoilButtonStyle.fallback(
      theme,
      sizes,
      widget.variant,
    ).merge(CoilTheme.styleOf<CoilButtonStyle>(context));
    if (slot?.radiusFor(style.minHeight!) case final radius?) {
      style = style.merge(CoilButtonStyle(radius: radius));
    }
    style = style.merge(widget.style);
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
        minHitTarget: slot == null ? sizes.minHitTarget : 0,
        builder: (context, states, _) {
          final look = _look(style, states);
          final pressing = states.contains(WidgetState.pressed);
          final radius = style.radius!;
          final disabled = widget.onPressed == null && !widget.loading;

          return Opacity(
            opacity: disabled ? sizes.disabledOpacity : 1,
            child: CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: BorderRadius.circular(radius),
              child: TrackBuilder(
                initialValues: [
                  CoilButtonTrack.fill.value(look.fill),
                  CoilButtonTrack.label.value(look.label),
                  CoilButtonTrack.collapse.value(look.spread),
                  CoilButtonTrack.weight.value(look.iconWeight),
                  CoilButtonTrack.light.value(look.light),
                ],
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
                  ]),
                  CoilButtonTrack.label([
                    .to(
                      look.label,
                      motion: _motionFor(
                        CoilButtonTrack.label,
                        _motion.fade,
                        spatial: false,
                      ),
                    ),
                  ]),
                  CoilButtonTrack.collapse([
                    .to(
                      look.spread,
                      motion: _motionFor(
                        CoilButtonTrack.collapse,
                        pressing ? _motion.quick : _motion.standard,
                      ),
                    ),
                  ]),
                  CoilButtonTrack.light([
                    .to(
                      look.light,
                      motion: _motionFor(
                        CoilButtonTrack.light,
                        _motion.fade,
                        spatial: false,
                      ),
                    ),
                  ]),
                  CoilButtonTrack.weight([
                    .to(
                      look.iconWeight,
                      motion: _motionFor(
                        CoilButtonTrack.weight,
                        _motion.fade,
                        spatial: false,
                      ),
                    ),
                  ]),
                ],
                builder: (context, value, _) {
                  final labelColor = value(CoilButtonTrack.label);
                  final spread = value(
                    CoilButtonTrack.collapse,
                  ).clamp(0.0, 1.0);
                  return CustomPaint(
                    painter: _ButtonSurfacePainter(
                      fill: value(CoilButtonTrack.fill),
                      spread: spread,
                      radius: radius,
                      border: style.border!.a == 0 ? null : style.border,
                      relief: _relief(
                        theme,
                        style,
                        disabled: disabled,
                        hover: value(CoilButtonTrack.light).clamp(0.0, 1.0),
                        press: widget.selected ? 1 : 1 - spread,
                      ),
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
                        // A label too long for the room ends in an
                        // ellipsis, as platform buttons do.
                        overflow: TextOverflow.ellipsis,
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

  /// The lighting under a plastic theme, or null when flat or disabled.
  /// The primary button is a strong fill; tertiary and ghost are quiet
  /// (never lit); the rest are raised.
  CoilRelief? _relief(
    CoilThemeData theme,
    CoilButtonStyle style, {
    required bool disabled,
    required double hover,
    required double press,
  }) {
    return CoilTheme.reliefOf(
      context,
      switch (widget.variant) {
        CoilButtonVariant.primary => CoilReliefRole.filled,
        CoilButtonVariant.tertiary ||
        CoilButtonVariant.ghost => CoilReliefRole.quiet,
        _ => CoilReliefRole.raised,
      },
      override: style.plasticity,
      hover: hover,
      press: press,
      enabled: !disabled,
    );
  }

  /// The swap between idle content and the spinner: the blur-fade on
  /// `quick`, out on `quickExit`.
  Widget _swap(Widget child) => MotionSwitcher(
    motion: _motion.quick,
    exitMotion: _motion.quickExit,
    transitionBuilder: CoilBlurFade.transition(
      blur: CoilBlurFade.defaultBlur / 2,
      scale: 0.9,
    ),
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

  /// A part that comes and goes beside the label: it owns its gap, so the
  /// button grows by the part and its gap together.
  Widget _slot(
    Widget? child, {
    required double gap,
    required CoilPresentSlotGap gapSide,
  }) {
    final tokens = _motion;
    return CoilPresentSlot(
      axis: Axis.horizontal,
      gap: gap,
      gapSide: gapSide,
      motion: widget.motion,
      presenceMotion: _motionFor(CoilButtonTrack.size, tokens.standard),
      presenceExitMotion: _motionFor(
        CoilButtonTrack.size,
        tokens.standardExit,
      ),
      child: child,
    );
  }

  Widget _labelContent(CoilMetrics sizes, CoilButtonStyle style) {
    final leading = widget.leading;
    final trailing = widget.trailing;
    final loading = widget.loading;
    // The leading slot is the leading widget, which the spinner replaces in
    // place; or, without one, the spinner entering beside the label.
    final leadingContent = leading != null
        ? _swap(
            loading
                ? _spinner()
                : KeyedSubtree(key: const ValueKey('idle'), child: leading),
          )
        : (loading ? _spinner() : null);
    // The padding is the one a slotted button has; a missing slot hands
    // back the difference as a spacer, so it grows with the slot.
    final extraX = sizes.buttonPaddingX - sizes.buttonIconPaddingX;
    Widget spacer({required bool present}) => _slot(
      present ? SizedBox(width: extraX) : null,
      gap: 0,
      gapSide: CoilPresentSlotGap.before,
    );
    final label = CoilSizeSwitcher(
      // Start-pinned, so only the trailing edge can be clipped; the row
      // around it stays centered in the button.
      alignment: AlignmentDirectional.centerStart,
      sizeMotion: _motionFor(CoilButtonTrack.size, _motion.standard),
      motion: widget.motion,
      debugLabel: 'CoilButton.label',
      child: widget.child,
    );
    // A minimum height plus symmetric padding: the label's line box sits
    // centered, and the button grows with the text scale.
    final padY = sizes.controlPaddingY(style.textStyle!);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.minHeight!),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: sizes.buttonIconPaddingX,
          end: sizes.buttonIconPaddingX,
          top: padY,
          bottom: padY,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          // The gaps belong to the slots, not to the row.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              spacer(present: leadingContent == null),
              _slot(
                leadingContent,
                gap: sizes.buttonGap,
                gapSide: CoilPresentSlotGap.after,
              ),
              Flexible(child: label),
              _slot(
                trailing,
                gap: sizes.buttonGap,
                gapSide: CoilPresentSlotGap.before,
              ),
              spacer(present: trailing == null),
            ],
          ),
        ),
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
    this.relief,
  });

  final Color fill;
  final double spread;
  final double radius;
  final Color? border;
  final CoilRelief? relief;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    RSuperellipse box(double inset, double r) =>
        RSuperellipse.fromRectAndRadius(
          bounds.deflate(inset),
          Radius.circular(math.max(0, r)),
        );

    final border = this.border;
    final relief = this.relief;
    final outer = box(1 - spread, radius + spread);
    relief?.paintShadows(canvas, outer);
    if (border == null) {
      canvas.drawRSuperellipse(outer, Paint()..color = fill);
      relief?.paint(canvas, outer);
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
    relief?.paint(canvas, outer);
  }

  @override
  bool shouldRepaint(_ButtonSurfacePainter old) =>
      old.fill != fill ||
      old.spread != spread ||
      old.radius != radius ||
      old.border != border ||
      old.relief != relief;
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
    // Two opposing arcs, drawn mid-lap.
    canvas
      ..drawArc(rect, -math.pi / 2, math.pi * 0.55, false, paint)
      ..drawArc(rect, math.pi / 2, math.pi * 0.55, false, paint);
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}
