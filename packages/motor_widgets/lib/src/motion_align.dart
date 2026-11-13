import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/implicit_tracks.dart';

final _alignment = Track<Alignment>(
  MotionConverter.alignment,
  debugLabel: 'alignment',
);
final _widthFactor = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'widthFactor',
);
final _heightFactor = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'heightFactor',
);

/// Animated version of [Align] that springs to a new [alignment],
/// [widthFactor] or [heightFactor] whenever they change.
///
/// The Motor version of [AnimatedAlign]. Each property has its own track, so
/// changing one keeps the others' motion. A [widthFactor] or [heightFactor]
/// that goes from null to a value starts there, as in [AnimatedAlign].
///
/// An [AlignmentDirectional] is resolved against the ambient
/// [Directionality] before it is animated.
class MotionAlign extends StatelessWidget {
  /// Creates a [MotionAlign].
  const MotionAlign({
    required this.alignment,
    required this.motion,
    this.child,
    this.heightFactor,
    this.widthFactor,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  }) : assert(
         widthFactor == null || widthFactor >= 0.0,
         'widthFactor must be non-negative',
       ),
       assert(
         heightFactor == null || heightFactor >= 0.0,
         'heightFactor must be non-negative',
       );

  /// How to align the child. See [Align.alignment].
  final AlignmentGeometry alignment;

  /// The widget below this widget in the tree.
  final Widget? child;

  /// If non-null, sets its height to the child's height multiplied by this
  /// factor. See [Align.heightFactor].
  final double? heightFactor;

  /// If non-null, sets its width to the child's width multiplied by this
  /// factor. See [Align.widthFactor].
  final double? widthFactor;

  /// The motion to animate with.
  final Motion motion;

  /// Called every time the animation settles.
  final VoidCallback? onEnd;

  /// How often the animation ticks, for example `tickerRate: .fps(30)`.
  ///
  /// Overrides the nearest [TickerRateScope]. Without either, it ticks every
  /// frame.
  final TickerRate? tickerRate;

  /// A name for the controller, shown by inspection tools such as
  /// `motor_devtools`.
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    return ImplicitTrackBuilder(
      motion: motion,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionAlign',
      tracks: [
        _alignment.implicit(
          alignment.resolve(Directionality.maybeOf(context)),
        ),
        _widthFactor.implicit(widthFactor),
        _heightFactor.implicit(heightFactor),
      ],
      builder: (context, value, child) => Align(
        alignment: value(_alignment)!,
        widthFactor: value(_widthFactor),
        heightFactor: value(_heightFactor),
        child: child,
      ),
      child: child,
    );
  }
}
