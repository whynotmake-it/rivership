import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The bordered trigger of the pickers in this folder: leading glyph,
/// label, chevron.
class CoilSelectTrigger extends StatelessWidget {
  /// Creates the trigger.
  const CoilSelectTrigger({
    required this.metrics,
    required this.label,
    required this.states,
    super.key,
    this.icon,
    this.indicator,
    this.style,
  });

  /// The size step.
  final CoilMetrics metrics;

  /// The resolved look; null computes it from the theme.
  final CoilSelectStyle? style;

  /// The label.
  final Widget label;

  /// The interaction states: hovered, pressed, focused (keyboard),
  /// disabled, selected (open).
  final Set<WidgetState> states;

  /// A leading glyph.
  final Widget? icon;

  /// Replaces the chevron.
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final style =
        this.style ??
        CoilSelectStyle.fallback(
          theme,
          metrics,
        ).merge(CoilTheme.styleOf<CoilSelectStyle>(context));
    final motion = CoilTheme.motionOf(context);
    final open = states.contains(WidgetState.selected);
    final hovered = states.contains(WidgetState.hovered) && !open;
    final pressed = states.contains(WidgetState.pressed);
    final focusRing = states.contains(WidgetState.focused) && !open;
    final enabled = !states.contains(WidgetState.disabled);
    final radius = BorderRadius.circular(style.radius!);
    return Opacity(
      opacity: enabled ? 1 : metrics.disabledOpacity,
      child: CoilFocusRing(
        visible: focusRing,
        borderRadius: radius,
        child: MotionBuilder<Color>(
          value: style.triggerFill!.resolve(states)!,
          converter: MotionConverter.colorRgb,
          motion: pressed || hovered ? motion.fade : motion.fadeExit,
          debugLabel: 'CoilSelect trigger fill',
          builder: (context, fill, child) => DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(color: style.triggerBorder!),
              ),
            ),
            child: child,
          ),
          child: ConstrainedBox(
            // A minimum height and symmetric padding, never a fixed height:
            // the trigger grows with larger text.
            constraints: BoxConstraints(
              minWidth: metrics.triggerMinWidth,
              minHeight: metrics.controlHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.controlPaddingX,
                vertical: metrics.controlPaddingY(metrics.body),
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  applyTextScaling: true,
                  color: style.indicator!.resolve(states),
                ),
                child: DefaultTextStyle(
                  style: style.textStyle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon case final icon?) ...[
                        icon,
                        SizedBox(width: metrics.gap),
                      ],
                      Flexible(fit: FlexFit.tight, child: label),
                      SizedBox(width: metrics.gap),
                      indicator ?? const _Chevron(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The default trigger glyph, drawn in the [IconTheme]'s size and color.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _ChevronPainter(icons.color ?? const Color(0xFF000000)),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(6 * s, 9 * s)
        ..lineTo(12 * s, 15 * s)
        ..lineTo(18 * s, 9 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
