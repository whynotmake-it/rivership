import 'package:coil/foundation.dart';
import 'package:coil/src/components/radio_group/radio_group.dart';
import 'package:coil/src/components/radio_group/radio_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The circle and dot of a radio, with no interaction of its own.
///
/// Use it inside a row that is already the tap target, as [CoilRadioGroup]
/// does. Only `hovered` in [states] is read. The circle grows with the text
/// scale.
class CoilRadioIndicator extends StatelessWidget {
  /// Creates a radio indicator.
  const CoilRadioIndicator({
    required this.selected,
    required this.states,
    super.key,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// Whether the dot shows.
  final bool selected;

  /// The states the border reacts to.
  final Set<WidgetState> states;

  /// Pins the circle to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Per-track motions; the `border` and `dot` tracks apply here.
  final Map<CoilRadioGroupTrack<Object>, Motion>? motions;

  /// Overrides for this indicator's look, on top of the theme's
  /// [CoilRadioGroupStyle] and the defaults.
  final CoilRadioGroupStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilRadioGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilRadioGroupStyle>(context)).merge(style);
    Motion motionFor(
      CoilRadioGroupTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: motions,
      token: token,
      spatial: spatial,
    );
    final box = MediaQuery.textScalerOf(context).scale(look.size!);
    final border = states.contains(WidgetState.hovered)
        ? look.border!.resolve({WidgetState.hovered})!
        : look.border!.resolve({if (selected) WidgetState.selected})!;
    return MotionBuilder<Color>(
      value: border,
      converter: MotionConverter.colorRgb,
      motion: motionFor(
        CoilRadioGroupTrack.border,
        tokens.fade,
        spatial: false,
      ),
      debugLabel: 'CoilRadioIndicator border',
      builder: (context, color, child) => DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(box / 2),
            side: BorderSide(color: color, width: look.borderWidth!),
          ),
        ),
        child: SizedBox.square(dimension: box, child: child),
      ),
      child: Center(
        child: SingleMotionBuilder(
          value: selected ? 1 : 0,
          motion: motionFor(
            CoilRadioGroupTrack.dot,
            selected ? tokens.quick : tokens.fadeExit,
            spatial: selected,
          ),
          debugLabel: 'CoilRadioIndicator dot',
          builder: (context, progress, _) => Opacity(
            opacity: progress.clamp(0, 1),
            child: Transform.scale(
              scale: look.dotScale! + (1 - look.dotScale!) * progress,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: look.dot,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      box * look.dotRatio! / 2,
                    ),
                  ),
                ),
                child: SizedBox.square(dimension: box * look.dotRatio!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
