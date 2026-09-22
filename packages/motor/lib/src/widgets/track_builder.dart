import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_timeline.dart';

/// Builds a widget from a multi-track animation.
typedef TrackWidgetBuilder = Widget Function(
  BuildContext context,
  TrackValueReader value,
  Widget? child,
);

/// Declaratively plays multiple [TrackAnimation]s on one ticker.
///
/// Use the default constructor with an inline list of [animations] (mirroring
/// [TrackController.animate]), or [TrackBuilder.timeline] with a reusable
/// [TrackTimeline] (mirroring [TrackController.play]). Each [TrackAnimation]
/// carries its own `from`/`withVelocity`; [loop] (or the timeline's loop)
/// controls repetition.
class TrackBuilder extends StatefulWidget {
  /// Plays an inline list of [animations].
  const TrackBuilder({
    required this.animations,
    required this.builder,
    this.loop = LoopMode.none,
    this.restartTrigger,
    this.active = true,
    this.onStep,
    this.onAnimationStatusChanged,
    this.child,
    super.key,
  }) : timeline = null;

  /// Plays a reusable [timeline].
  const TrackBuilder.timeline(
    this.timeline, {
    required this.builder,
    this.restartTrigger,
    this.active = true,
    this.onStep,
    this.onAnimationStatusChanged,
    this.child,
    super.key,
  })  : animations = null,
        loop = LoopMode.none;

  /// The inline track animations to play (default constructor).
  final List<TrackAnimation>? animations;

  /// The reusable timeline to play ([TrackBuilder.timeline]).
  final TrackTimeline? timeline;

  /// How the inline [animations] should loop.
  ///
  /// Ignored when a [timeline] is used (the timeline owns its loop).
  final LoopMode loop;

  /// Restarts playback from the start when this value changes.
  ///
  /// Jumps every track back to its start value (its `from` override or the
  /// track's initial) and replays from the beginning, rather than animating
  /// from the current values back to the first value.
  final Object? restartTrigger;

  /// Whether playback is active.
  final bool active;

  /// Called when a track enters a step.
  final void Function(Track track, int stepIndex)? onStep;

  /// Called when coarse playback status changes.
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// Builds the widget.
  final TrackWidgetBuilder builder;

  /// Optional child.
  final Widget? child;

  @override
  State<TrackBuilder> createState() => _TrackBuilderState();
}

class _TrackBuilderState extends State<TrackBuilder>
    with TickerProviderStateMixin {
  late final TrackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TrackController(vsync: this);
    if (widget.onAnimationStatusChanged != null) {
      _controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    _updatePlayback();
  }

  @override
  void didUpdateWidget(TrackBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.onAnimationStatusChanged != oldWidget.onAnimationStatusChanged) {
      if (oldWidget.onAnimationStatusChanged != null) {
        _controller.removeStatusListener(oldWidget.onAnimationStatusChanged!);
      }
      if (widget.onAnimationStatusChanged != null) {
        _controller.addStatusListener(widget.onAnimationStatusChanged!);
      }
    }

    if (widget.active != oldWidget.active && !widget.active) {
      _controller.stop(canceled: true);
      return;
    }

    // A restartTrigger change replays from the start (jumping back to the
    // start snapshot first). Other changes keep animating from current values.
    final restartTriggerChanged =
        widget.restartTrigger != oldWidget.restartTrigger;

    if (restartTriggerChanged) {
      _updatePlayback(restart: true);
    } else if (_playbackChanged(oldWidget) ||
        widget.active != oldWidget.active) {
      _updatePlayback();
    }
  }

  /// Whether the actual animation to play changed.
  ///
  /// Timelines compare by value ([TrackTimeline] is `Equatable`); inline
  /// animation lists compare deeply so an equal-but-new list rebuild does not
  /// restart playback.
  bool _playbackChanged(TrackBuilder oldWidget) {
    if (widget.timeline != null || oldWidget.timeline != null) {
      return widget.timeline != oldWidget.timeline;
    }
    return !listEquals(widget.animations, oldWidget.animations) ||
        widget.loop != oldWidget.loop;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      child: widget.child,
      builder: (context, child) {
        return widget.builder(context, _controller.value, child);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updatePlayback({bool restart = false}) {
    if (!widget.active) return;

    if (restart) {
      // Jump every track back to its start value before replaying, so a
      // restartTrigger change starts the animation from the start rather than
      // animating from the current value back to the first value.
      _controller.set(_startValues());
    }

    final timeline = widget.timeline;
    if (timeline != null) {
      _controller.play(timeline, onStep: widget.onStep);
    } else {
      _controller.animate(
        widget.animations!,
        loop: widget.loop,
        onStep: widget.onStep,
      );
    }
  }

  List<TrackValue> _startValues() {
    final timeline = widget.timeline;
    if (timeline != null) return timeline.startValues;
    return [
      for (final animation in widget.animations!)
        animation.track.value(animation.resolveStartValue()),
    ];
  }
}
