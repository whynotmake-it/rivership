import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_phase_timeline.dart';
import 'package:motor/src/widgets/multi_track_motion_builder.dart';

/// Builds a widget from phase-driven track values.
///
/// Each phase in the [timeline] maps to a list of [TrackAnimation]s that play
/// when that phase is entered. Phases can range from simple single-target
/// animations to complex multi-step choreographies.
///
/// Two modes of operation:
///
/// **Manual control** -- set [currentPhase] to drive phase changes externally:
///
/// ```dart
/// PhaseMotionBuilder<PanelPhase>(
///   currentPhase: _phase,
///   timeline: TrackPhaseTimeline({
///     .compact: [panelSize.to(Size(172, 128)), radius.to(24)],
///     .expanded: [panelSize.to(Size(292, 180)), radius.to(34)],
///   }),
///   builder: (context, value, child) { ... },
/// )
/// ```
///
/// **Auto-advance** -- set [playing] to `true` to progress through phases
/// automatically when each phase's animations settle:
///
/// ```dart
/// PhaseMotionBuilder<PanelPhase>(
///   playing: true,
///   timeline: TrackPhaseTimeline({
///     .compact: [panelSize.to(Size(172, 128))],
///     .expanded: [panelSize.to(Size(292, 180))],
///   }, loop: LoopMode.loop),
///   onPhaseChanged: (phase) => print('Now at $phase'),
///   builder: (context, value, child) { ... },
/// )
/// ```
class PhaseMotionBuilder<P extends Object> extends StatefulWidget {
  /// Creates a phase motion builder.
  const PhaseMotionBuilder({
    required this.timeline,
    required this.builder,
    this.currentPhase,
    this.playing = false,
    this.from,
    this.active = true,
    this.onPhaseChanged,
    this.onAnimationStatusChanged,
    this.child,
    super.key,
  });

  /// The phase timeline containing phase-to-animation mappings.
  final TrackPhaseTimeline<P> timeline;

  /// The phase to display or animate to.
  ///
  /// When changed, plays the full animation list for this phase.
  /// If null, uses the timeline's initial phase.
  final P? currentPhase;

  /// Whether to automatically progress through phases.
  ///
  /// When `true`, plays through all phases in order. The timeline's
  /// [LoopMode] controls what happens at the end.
  final bool playing;

  /// Builder-level initial-value overrides.
  final List<TrackValue>? from;

  /// Whether playback is active.
  final bool active;

  /// Called when the current phase changes (from auto-advance or seek).
  final void Function(P phase)? onPhaseChanged;

  /// Called when the animation status changes.
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// Builds the widget.
  final MultiTrackWidgetBuilder builder;

  /// Optional child passed to [builder].
  final Widget? child;

  @override
  State<PhaseMotionBuilder<P>> createState() => _PhaseMotionBuilderState<P>();
}

class _PhaseMotionBuilderState<P extends Object>
    extends State<PhaseMotionBuilder<P>> with TickerProviderStateMixin {
  late PhaseTrackController<P> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhaseTrackController<P>(
      vsync: this,
      from: widget.from,
    );
    if (widget.onAnimationStatusChanged != null) {
      _controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    _startPlayback();
  }

  @override
  void didUpdateWidget(PhaseMotionBuilder<P> oldWidget) {
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

    final timelineChanged = widget.timeline != oldWidget.timeline;
    final phaseChanged = widget.currentPhase != oldWidget.currentPhase;
    final playingChanged = widget.playing != oldWidget.playing;

    if (timelineChanged || playingChanged) {
      _startPlayback();
    } else if (phaseChanged && widget.currentPhase != null) {
      _controller.goToPhase(widget.currentPhase as P);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startPlayback() {
    if (!widget.active) return;

    final phase = widget.currentPhase ?? widget.timeline.initialPhase;

    if (widget.playing) {
      _controller.playPhases(
        widget.timeline,
        atPhase: phase,
        onPhaseChanged: widget.onPhaseChanged,
      );
    } else {
      _controller.setTimeline(
        widget.timeline,
        onPhaseChanged: widget.onPhaseChanged,
      );
      _controller.goToPhase(phase);
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
}
