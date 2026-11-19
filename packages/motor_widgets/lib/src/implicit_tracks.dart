import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/on_end.dart';

/// A property of an implicitly animated widget: its [track], and the [value]
/// it should settle on, or null while the property is unset.
///
/// Create one with [ImplicitTargetOf.target]: `MyTracks.padding.target(x)`.
@immutable
class ImplicitTarget<T extends Object> {
  /// Pairs [track] with the [value] it should settle on.
  const ImplicitTarget(this.track, this.value);

  /// The track that animates the property.
  final Track<T> track;

  /// The value the property animates to, or null while it is unset.
  final T? value;

  // Generic here, where T is known, so the steps and values are typed.
  TrackAnimation<T> _animation(Motion motion) =>
      track([TrackStep.to(value!, motion: motion)]);

  TrackValue<T> _startValue() => track.value(value!);
}

/// Pairs a track with its target as an [ImplicitTarget] of the track's own
/// type, which a list literal would otherwise widen to `Object`.
extension ImplicitTargetOf<T extends Object> on Track<T> {
  /// This track with the [value] it should settle on, or null while the
  /// property is unset.
  ImplicitTarget<T> target(T? value) => ImplicitTarget<T>(this, value);
}

/// Reads a property's current value in [ImplicitTrackBuilder.builder]: null
/// while the property is unset.
typedef ImplicitTrackReader = T? Function<T extends Object>(Track<T> track);

/// Builds a widget from the current values of the
/// [ImplicitTrackBuilder.targets].
typedef ImplicitTrackWidgetBuilder =
    Widget Function(
      BuildContext context,
      ImplicitTrackReader value,
      Widget? child,
    );

/// The engine of this package's implicitly animated widgets: a
/// [TrackBuilder] for properties that may be null, with the rules of
/// Flutter's `Animated*` widgets.
///
/// Each property is a track and a target ([ImplicitTarget]). As in
/// `ImplicitlyAnimatedWidget`, null means the property is unset, not a value
/// to animate toward:
///
/// - **Unset to set**, also on the first build: the property starts at its
///   target, without animating.
/// - **Set to another value**: it animates there with its motion.
/// - **Set to unset**: it is dropped at once, and [builder] reads null, so
///   the widget builds as if it was never set (no `Padding`, a free edge of
///   a `Positioned`, an `Align` that sizes to its child).
///
/// A new ambient text direction jumps every property to its target, as
/// `AnimatedAlign` does, since directional values are resolved against it
/// before they animate.
///
/// Unlike Flutter's widgets, which share one controller and restart every
/// property's curve when one changes, each property is its own track:
/// changing one leaves the others in flight, and a property retargeted
/// mid-flight keeps its velocity.
///
/// It exists because [TrackBuilder] has no notion of unset: its reader
/// returns a track's last or initial value whether or not it plays, and a
/// value that should appear without animating has to be given twice, as an
/// animation and an initial value. This widget derives both from the
/// targets and reads null for the unset ones.
class ImplicitTrackBuilder extends StatelessWidget {
  /// Creates an [ImplicitTrackBuilder].
  const ImplicitTrackBuilder({
    required this.targets,
    required this.motion,
    required this.builder,
    this.motions,
    this.onEnd,
    this.child,
    this.debugLabel,
    this.tickerRate,
    super.key,
  });

  /// The properties and their targets. Each track may appear once.
  final List<ImplicitTarget<Object>> targets;

  /// The motion every property follows, unless [motions] has its own.
  final Motion motion;

  /// Motions for single tracks, overriding [motion].
  ///
  /// Motions compare by value, so a map literal rebuilt in `build` with the
  /// same motions redirects nothing.
  final Map<Track<Object>, Motion>? motions;

  /// Builds the widget from the current values. A property reads null while
  /// it is unset.
  final ImplicitTrackWidgetBuilder builder;

  /// Called when the properties have settled after a change.
  final VoidCallback? onEnd;

  /// A child passed through to [builder].
  final Widget? child;

  /// A name for the controller, shown by `motor_devtools`.
  final String? debugLabel;

  /// How often the animation ticks.
  final TickerRate? tickerRate;

  @override
  Widget build(BuildContext context) {
    // Only set properties play. Their start value is their target, so one
    // that appears doesn't animate, and TrackBuilder drops one that leaves.
    final set = [
      for (final target in targets)
        if (target.value != null) target,
    ];
    final setTracks = {for (final target in set) target.track};
    return TrackBuilder(
      animations: [
        for (final target in set)
          target._animation(motions?[target.track] ?? motion),
      ],
      initialValues: [for (final target in set) target._startValue()],
      restartTrigger: Directionality.maybeOf(context),
      debugLabel: debugLabel,
      tickerRate: tickerRate,
      onAnimationStatusChanged: onEndListener(onEnd),
      builder: (context, value, child) => builder(
        context,
        <T extends Object>(Track<T> track) =>
            setTracks.contains(track) ? value(track) : null,
        child,
      ),
      child: child,
    );
  }
}
