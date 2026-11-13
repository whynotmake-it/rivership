import 'package:fluid_functionalism/src/foundation/color_mix.dart';
import 'package:fluid_functionalism/src/foundation/fluid_colors.dart';
import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart';
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/foundation/fluid_typography.dart';
import 'package:fluid_functionalism/src/primitives/fluid_focus_ring.dart';
import 'package:fluid_functionalism/src/primitives/fluid_pressable.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A switch with an optional label (`registry/radix/switch.tsx`).
///
/// The whole row is the hit target. The thumb becomes a pill on hover,
/// squashes while pressed, and can be dragged: releasing past the midpoint
/// toggles. Its geometry rides [FluidMotion.moderate]; colors fade on
/// [FluidMotion.color].
class FluidSwitch extends StatefulWidget {
  /// Creates a switch.
  const FluidSwitch({
    required this.value,
    required this.onChanged,
    super.key,
    this.label,
    this.density,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.semanticLabel,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// A label after the track. Muted while off.
  final Widget? label;

  /// Pins the switch to one size step. Null follows [FluidSizeScope].
  final FluidDensity? density;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;

  @override
  State<FluidSwitch> createState() => _FluidSwitchState();
}

class _FluidSwitchState extends State<FluidSwitch> {
  /// The thumb's left edge while dragging, or null.
  double? _dragX;
  double _dragOrigin = 0;
  bool _dragged = false;
  double _dragDx = 0;

  bool get _enabled => widget.onChanged != null;

  Rect _thumbRect(
    FluidSwitchMetrics m, {
    required bool hovered,
    required bool pressed,
  }) {
    final inset = m.thumbInset;
    final width =
        m.thumbSize +
        (pressed
            ? m.pressExtend
            : hovered
            ? m.pillExtend
            : 0);
    final height = pressed ? m.thumbSize - m.pressShrink : m.thumbSize;
    final top = inset + (pressed ? m.pressShrink / 2 : 0);
    final travel = m.trackWidth - m.thumbSize - inset * 2;
    final left = widget.value ? inset + travel - (width - m.thumbSize) : inset;
    return Rect.fromLTWH(_dragX ?? left, top, width, height);
  }

  (double, double) _dragRange(FluidSwitchMetrics m) => (
    m.thumbInset,
    m.trackWidth - m.thumbInset - (m.thumbSize + m.pressExtend),
  );

  void _onDragStart(FluidSwitchMetrics m) {
    if (!_enabled) return;
    final (min, max) = _dragRange(m);
    _dragOrigin = widget.value ? max : min;
    setState(() => _dragX = _dragOrigin);
  }

  void _onDragUpdate(FluidSwitchMetrics m, double dx) {
    if (_dragX == null) return;
    final (min, max) = _dragRange(m);
    _dragged = true;
    setState(() => _dragX = (_dragOrigin + dx).clamp(min, max));
  }

  void _onDragEnd(FluidSwitchMetrics m) {
    final x = _dragX;
    if (x == null) return;
    final (min, max) = _dragRange(m);
    setState(() => _dragX = null);
    final on = x > (min + max) / 2;
    if (on != widget.value) widget.onChanged?.call(on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final colors = theme.colors;
    final sizes = FluidTheme.sizesOf(context, density: widget.density);
    final m = sizes.switchMetrics;
    final label = widget.label;

    final pressable = FluidPressable(
      onPressed: _enabled
          ? () {
              if (_dragged) return;
              widget.onChanged?.call(!widget.value);
            }
          : null,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      statesController: widget.statesController,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed) || _dragX != null;
        final thumb = _thumbRect(m, hovered: hovered, pressed: pressed);
        final track = _trackColor(colors, hovered: hovered);
        final radius = BorderRadius.circular(
          theme.shape == FluidShape.sharp ? 0 : m.trackHeight / 2,
        );

        final trackWidget = FluidFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          offset: 2,
          child: MotionBuilder<Color>(
            value: track,
            motion: FluidMotion.color,
            converter: MotionConverter.colorRgb,
            builder: (context, trackColor, _) => Container(
              width: m.trackWidth,
              height: m.trackHeight,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: radius,
              ),
              child: MotionBuilder<Rect>(
                value: thumb,
                // Follow the finger exactly while dragging; spring
                // from wherever it was let go.
                active: _dragX == null,
                motion: FluidMotion.travel(context, FluidMotion.moderate),
                converter: MotionConverter.rect,
                builder: (context, rect, _) => Stack(
                  children: [
                    Positioned.fromRect(
                      rect: rect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: theme.shape == FluidShape.sharp
                              ? BorderRadius.zero
                              : BorderRadius.circular(m.thumbSize),
                          // Tailwind `shadow-sm`.
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              offset: Offset(0, 1),
                              blurRadius: 3,
                            ),
                            BoxShadow(
                              color: Color(0x1A000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        Widget content = trackWidget;
        if (label != null) {
          content = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizes.controlPaddingX,
              vertical: sizes.switchRowPaddingY,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: sizes.gap,
              children: [
                trackWidget,
                MotionBuilder<Color>(
                  value: widget.value
                      ? colors.foreground
                      : colors.mutedForeground,
                  motion: FluidMotion.color,
                  converter: MotionConverter.colorRgb,
                  builder: (context, color, child) => DefaultTextStyle(
                    style: FluidTypography.style(sizes.body, color: color),
                    child: child!,
                  ),
                  child: label,
                ),
              ],
            ),
          );
        }
        return Opacity(
          opacity: _enabled ? 1 : 0.5,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: sizes.minHitTarget,
              minWidth: sizes.minHitTarget,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        );
      },
    );

    return Semantics(
      container: true,
      toggled: widget.value,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        // Dragging is a pointer nicety; it is not a scroll action.
        excludeFromSemantics: true,
        onHorizontalDragStart: (_) {
          _dragDx = 0;
          _dragged = false;
          _onDragStart(m);
        },
        onHorizontalDragUpdate: (details) {
          _dragDx += details.delta.dx;
          _onDragUpdate(m, _dragDx);
        },
        onHorizontalDragEnd: (_) => _onDragEnd(m),
        onHorizontalDragCancel: () => setState(() => _dragX = null),
        child: pressable,
      ),
    );
  }

  Color _trackColor(FluidColors c, {required bool hovered}) {
    if (widget.value) {
      return hovered
          ? FluidColorMix.oklab(c.fluidAccent, const Color(0xFF000000), 0.92)
          : c.fluidAccent;
    }
    return hovered ? FluidColorMix.oklab(c.accent, c.overlay, 0.9) : c.accent;
  }
}
