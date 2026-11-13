import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/implicit_tracks.dart';

/// The tracks of a [MotionAlign], one per animated property.
///
/// Use them as keys of [MotionAlign.motions] to give a property its own
/// motion:
///
/// ```dart
/// MotionAlign(
///   motion: const .smoothSpring(),
///   motions: {.alignment: const .snappySpring()},
///   …
/// )
/// ```
final class MotionAlignTrack<T extends Object> extends Track<T> {
  MotionAlignTrack._(super.converter, {required String super.debugLabel});

  /// [MotionAlign.alignment], resolved against the ambient [Directionality].
  static final alignment = MotionAlignTrack<Alignment>._(
    MotionConverter.alignment,
    debugLabel: 'MotionAlign.alignment',
  );

  /// [MotionAlign.widthFactor].
  static final widthFactor = MotionAlignTrack<double>._(
    const NonNegativeMotionConverter(),
    debugLabel: 'MotionAlign.widthFactor',
  );

  /// [MotionAlign.heightFactor].
  static final heightFactor = MotionAlignTrack<double>._(
    const NonNegativeMotionConverter(),
    debugLabel: 'MotionAlign.heightFactor',
  );
}

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
    this.motions,
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

  /// The motion every property follows, unless [motions] has its own.
  final Motion motion;

  /// {@macro motor_widgets.motions}
  ///
  /// For example `motions: {.alignment: const .snappySpring()}`.
  final Map<MotionAlignTrack<Object>, Motion>? motions;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    return ImplicitTrackBuilder(
      motion: motion,
      motions: motions,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionAlign',
      tracks: [
        MotionAlignTrack.alignment.implicit(
          alignment.resolve(Directionality.maybeOf(context)),
        ),
        MotionAlignTrack.widthFactor.implicit(widthFactor),
        MotionAlignTrack.heightFactor.implicit(heightFactor),
      ],
      builder: (context, value, child) => Align(
        alignment: value(MotionAlignTrack.alignment)!,
        widthFactor: value(MotionAlignTrack.widthFactor),
        heightFactor: value(MotionAlignTrack.heightFactor),
        child: child,
      ),
      child: child,
    );
  }
}
