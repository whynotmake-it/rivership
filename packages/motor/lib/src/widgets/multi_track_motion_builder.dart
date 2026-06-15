import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_timeline.dart';

/// Builds a widget from a multi-track animation.
typedef MultiTrackWidgetBuilder = Widget Function(
  BuildContext context,
  TrackValueReader value,
  Widget? child,
);

/// Declaratively plays a [TrackTimeline].
class MultiTrackMotionBuilder extends StatefulWidget {
  /// Creates a multi-track motion builder.
  const MultiTrackMotionBuilder({
    required this.builder,
    this.timeline,
    this.play,
    this.from,
    this.withVelocity,
    this.loop,
    this.restartTrigger,
    this.active = true,
    this.onStep,
    this.onAnimationStatusChanged,
    this.child,
    super.key,
  }) : assert(
          timeline != null || play != null,
          'Either timeline or play must be provided',
        );

  /// The reusable timeline to play.
  final TrackTimeline? timeline;

  /// Convenience inline track animations.
  final List<TrackAnimation>? play;

  /// Builder-level initial overrides.
  final List<TrackValue>? from;

  /// Builder-level initial velocities (each entry's value is a velocity).
  final List<TrackValue>? withVelocity;

  /// Optional loop override.
  final LoopMode? loop;

  /// Restarts playback from the start when this value changes.
  ///
  /// Jumps every track back to its start value (its `from` override or the
  /// track's origin) and replays from the beginning, rather than animating
  /// from the current values back to the first value.
  final Object? restartTrigger;

  /// Whether playback is active.
  final bool active;

  /// Called when a track enters a step.
  final void Function(Track track, int stepIndex)? onStep;

  /// Called when coarse playback status changes.
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// Builds the widget.
  final MultiTrackWidgetBuilder builder;

  /// Optional child.
  final Widget? child;

  @override
  State<MultiTrackMotionBuilder> createState() =>
      _MultiTrackMotionBuilderState();
}

class _MultiTrackMotionBuilderState extends State<MultiTrackMotionBuilder>
    with TickerProviderStateMixin {
  late final TrackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TrackController(
      vsync: this,
      from: widget.from,
    );
    if (widget.onAnimationStatusChanged != null) {
      _controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    _updatePlayback();
  }

  @override
  void didUpdateWidget(MultiTrackMotionBuilder oldWidget) {
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
    // start snapshot first), matching the legacy builder. Other changes keep
    // animating from the current values.
    final restartTriggerChanged =
        widget.restartTrigger != oldWidget.restartTrigger;

    if (restartTriggerChanged) {
      _updatePlayback(restart: true);
    } else if (widget.timeline != oldWidget.timeline ||
        widget.play != oldWidget.play ||
        widget.loop != oldWidget.loop ||
        widget.withVelocity != oldWidget.withVelocity ||
        widget.active != oldWidget.active) {
      _updatePlayback();
    }
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

    final timeline = _effectiveTimeline();
    if (restart) {
      // Jump every track back to its start value before replaying, so a
      // restartTrigger change starts the animation from the start rather than
      // animating from the current value back to the first value.
      _controller.set(timeline.startValues);
    }
    _controller.play(
      timeline,
      onStep: widget.onStep,
    );
  }

  TrackTimeline _effectiveTimeline() {
    final timeline = widget.timeline;
    if (timeline != null) {
      if (widget.from == null &&
          widget.loop == null &&
          widget.withVelocity == null) {
        return timeline;
      }
      return TrackTimeline(
        timeline.animations,
        loop: widget.loop ?? timeline.loop,
        from: widget.from ?? timeline.from,
        withVelocity: widget.withVelocity ?? timeline.withVelocity,
      );
    }

    return TrackTimeline(
      widget.play!,
      loop: widget.loop ?? LoopMode.none,
      from: widget.from ?? const [],
      withVelocity: widget.withVelocity ?? const [],
    );
  }
}
