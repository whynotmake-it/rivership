import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One pressable item of a choice group.
///
/// Wraps `CoilInteraction` with what every item shares: the disabled
/// opacity and, on touch, a fill that shows while a finger presses (a
/// hovering pointer already shows the group's highlight). Build the item's
/// content in [builder] from the interaction states.
class CoilChoiceItem extends StatelessWidget {
  /// Creates an item.
  const CoilChoiceItem({
    required this.onPressed,
    required this.focusNode,
    required this.statesController,
    required this.pressFill,
    required this.radius,
    required this.pressMotion,
    required this.releaseMotion,
    required this.builder,
    super.key,
    this.size,
  });

  /// Called on tap, Enter or Space. Null disables the item.
  final VoidCallback? onPressed;

  /// The item's focus node, from the group.
  final FocusNode focusNode;

  /// The item's states, from the group.
  final WidgetStatesController statesController;

  /// The fill a finger shows while pressing.
  final Color pressFill;

  /// The corner radius of the press fill.
  final double radius;

  /// The motion of the press fill appearing.
  final Motion pressMotion;

  /// The motion of the press fill leaving.
  final Motion releaseMotion;

  /// Builds the content.
  final ValueWidgetBuilder<Set<WidgetState>> builder;

  /// Pins the item to one size step. Null follows `CoilAdaptiveScope`.
  final CoilSize? size;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: size);
    return Opacity(
      opacity: onPressed == null ? metrics.disabledRowOpacity : 1,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        statesController: statesController,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final pressing =
              states.contains(WidgetState.pressed) &&
              !states.contains(WidgetState.hovered);
          return MotionBuilder<Color>(
            value: pressing ? pressFill : pressFill.withValues(alpha: 0),
            converter: MotionConverter.colorRgb,
            motion: pressing ? pressMotion : releaseMotion,
            debugLabel: 'CoilChoiceItem press',
            builder: (context, fill, child) => DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: child,
            ),
            child: builder(context, states, null),
          );
        },
      ),
    );
  }
}
