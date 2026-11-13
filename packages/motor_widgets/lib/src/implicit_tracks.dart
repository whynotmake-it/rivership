import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

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

  TrackAnimation<T>? _animation(Motion motion, {required Object? appearedAt}) {
    final value = this.value;
    if (value == null) return null;
    return track(
      [TrackStep.to(value, motion: motion)],
      from: appearedAt == value ? value : null,
    );
  }
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
/// A property that goes from null to a value starts at that value instead of
/// animating from zero, like Flutter's implicit animations, which also don't
/// animate a property that was unset. One that goes back to null drops its
/// track.
class ImplicitTrackBuilder extends StatefulWidget {
  /// Creates an [ImplicitTrackBuilder].
  const ImplicitTrackBuilder({
    required this.tracks,
    required this.motion,
    required this.builder,
    this.onEnd,
    this.child,
    this.debugLabel,
    this.tickerRate,
    super.key,
  });

  /// The properties to animate. Each track may appear once.
  final List<ImplicitTrack<Object>> tracks;

  /// The motion every property follows.
  final Motion motion;

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
  State<ImplicitTrackBuilder> createState() => _ImplicitTrackBuilderState();
}

class _ImplicitTrackBuilderState extends State<ImplicitTrackBuilder> {
  /// The value each property had when it appeared, until it changes.
  ///
  /// The animation of such a property starts `from` that value, so a property
  /// that was just set jumps there instead of animating from nothing.
  final _appearedAt = <Track<Object>, Object>{};

  @override
  void initState() {
    super.initState();
    for (final ImplicitTrack(:track, :value) in widget.tracks) {
      if (value != null) _appearedAt[track] = value;
    }
  }

  @override
  void didUpdateWidget(ImplicitTrackBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tracks = {for (final property in widget.tracks) property.track};
    _appearedAt.removeWhere((track, _) => !tracks.contains(track));
    final oldValues = {
      for (final ImplicitTrack(:track, :value) in oldWidget.tracks)
        track: value,
    };
    for (final ImplicitTrack(:track, :value) in widget.tracks) {
      if (value == null) {
        _appearedAt.remove(track);
      } else if (oldValues[track] == null) {
        _appearedAt[track] = value;
      } else if (_appearedAt[track] != value) {
        _appearedAt.remove(track);
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (!status.isAnimating) widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final present = <Track<Object>>{};
    final animations = <TrackAnimation>[
      for (final property in widget.tracks)
        if (property._animation(
              widget.motion,
              appearedAt: _appearedAt[property.track],
            )
            case final animation?)
          animation,
    ];
    for (final animation in animations) {
      present.add(animation.track);
    }
    return TrackBuilder(
      animations: animations,
      debugLabel: widget.debugLabel,
      tickerRate: widget.tickerRate,
      onAnimationStatusChanged: widget.onEnd == null ? null : _onStatus,
      builder: (context, value, child) => widget.builder(
        context,
        <T extends Object>(Track<T> track) =>
            present.contains(track) ? value(track) : null,
        child,
      ),
      child: widget.child,
    );
  }
}
