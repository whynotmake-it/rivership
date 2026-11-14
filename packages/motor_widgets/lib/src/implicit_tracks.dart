import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/on_end.dart';

/// One optional property of an implicitly animated widget: a [track] and the
/// [value] it should settle on, or null when the property is unset.
@immutable
class ImplicitTrack<T extends Object> {
  /// Pairs [track] with its target [value].
  const ImplicitTrack(this.track, this.value);

  /// The identity of the property.
  final Track<T> track;

  /// The value the property animates to, or null when it is unset.
  final T? value;

  TrackAnimation<T> _animation(T value, Motion motion) =>
      track([TrackStep.to(value, motion: motion)]);

  TrackValue<T> _initial(T value) => track.value(value);
}

/// Creates [ImplicitTrack]s whose type comes from the track, which a list
/// literal's context would otherwise widen to `Object`.
extension ImplicitTrackOf<T extends Object> on Track<T> {
  /// This track with its target [value], or null when the property is unset.
  ImplicitTrack<T> implicit(T? value) => ImplicitTrack<T>(this, value);
}

/// Reads the current value of an [ImplicitTrack]'s track, or null while the
/// property is unset.
typedef ImplicitTrackReader = T? Function<T extends Object>(Track<T> track);

/// Builds a widget from the current values of [ImplicitTrackBuilder.tracks].
typedef ImplicitTrackWidgetBuilder =
    Widget Function(
      BuildContext context,
      ImplicitTrackReader value,
      Widget? child,
    );

/// Animates a set of optional properties on one [TrackBuilder], one track per
/// property, so changing one never disturbs another that is in flight.
///
/// It only maps the set properties to [TrackBuilder]'s `animations` and
/// `initialValues`, so Motor gives it Flutter's implicit-animation rules:
/// - a property that is set the first time it is seen, at mount or later,
///   starts at its value instead of animating in from zero;
/// - a property that goes back to null drops its track;
/// - a new text direction jumps every property to its value, as
///   `AnimatedAlign` does, rather than sending the child across the box.
class ImplicitTrackBuilder extends StatelessWidget {
  /// Creates an [ImplicitTrackBuilder].
  const ImplicitTrackBuilder({
    required this.tracks,
    required this.motion,
    required this.builder,
    this.motions,
    this.onEnd,
    this.child,
    this.debugLabel,
    this.tickerRate,
    super.key,
  });

  /// The properties to animate. Each track may appear once.
  final List<ImplicitTrack<Object>> tracks;

  /// The motion every property follows, unless [motions] has its own.
  final Motion motion;

  /// Motions for single tracks, overriding [motion].
  ///
  /// Motions compare by value, so a map literal rebuilt in `build` with the
  /// same motions redirects nothing.
  final Map<Track<Object>, Motion>? motions;

  /// Builds the widget from the current values.
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
    final animations = <TrackAnimation>[];
    final initialValues = <TrackValue>[];
    for (final property in tracks) {
      _add(property, animations, initialValues);
    }
    final present = {for (final animation in animations) animation.track};
    return TrackBuilder(
      animations: animations,
      initialValues: initialValues,
      // Properties are resolved against the text direction before they
      // animate, so a new direction restarts: every track jumps to its
      // initial value, which is its target.
      restartTrigger: Directionality.maybeOf(context),
      debugLabel: debugLabel,
      tickerRate: tickerRate,
      onAnimationStatusChanged: onEndListener(onEnd),
      builder: (context, value, child) => builder(
        context,
        <T extends Object>(Track<T> track) =>
            present.contains(track) ? value(track) : null,
        child,
      ),
      child: child,
    );
  }

  void _add<T extends Object>(
    ImplicitTrack<T> property,
    List<TrackAnimation> animations,
    List<TrackValue> initialValues,
  ) {
    final value = property.value;
    if (value == null) return;
    animations.add(
      property._animation(value, motions?[property.track] ?? motion),
    );
    initialValues.add(property._initial(value));
  }
}
