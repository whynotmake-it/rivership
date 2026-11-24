import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The fill coil puts over a pressable that has no fill of its own: `hover`
/// under a hovering pointer and `active` while pressed (DESIGN.md §2.2).
///
/// Lay it over the control's content, inside the control's clip.
class StateOverlay extends StatelessWidget {
  const StateOverlay({required this.states, super.key});

  /// The states a `CoilInteraction` reports.
  final Set<WidgetState> states;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final motion = CoilTheme.motionOf(context);
    final pressed = states.contains(WidgetState.pressed);
    final hovered = states.contains(WidgetState.hovered);
    return IgnorePointer(
      child: MotionBuilder<Color>(
        value: pressed
            ? colors.active
            : hovered
            ? colors.hover
            : colors.active.withValues(alpha: 0),
        converter: MotionConverter.colorRgb,
        motion: pressed || hovered ? motion.fade : motion.fadeExit,
        builder: (context, color, _) => ColoredBox(color: color),
      ),
    );
  }
}
