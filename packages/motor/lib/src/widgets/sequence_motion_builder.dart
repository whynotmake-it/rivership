import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/motion_sequence.dart';

/// A function that builds a widget based on the current phase and interpolated
/// value.
typedef PhaseWidgetBuilder<T extends Object, P> = Widget Function(
  BuildContext context,
  T value,
  P phase,
  Widget? child,
);

/// {@template SequenceMotionBuilder}
/// Animates through a [MotionSequence] with smooth phase transitions.
///
/// Use [playing] to control automatic sequence progression or [currentPhase]
/// for manual control. Supports all sequence types (states, steps, spanning).
///
/// ```dart
/// enum ButtonState { idle, pressed, loading }
///
/// final sequence = MotionSequence.states({
///   ButtonState.idle: Offset(100, 40),
///   ButtonState.pressed: Offset(95, 38),
///   ButtonState.loading: Offset(40, 40),
/// }, motion: Motion.smoothSpring());
///
/// SequenceMotionBuilder(
///   sequence: sequence,
///   converter: MotionConverter.offset,
///   playing: true, // Auto-progress through phases
///   builder: (context, offset, phase, child) => Container(
///     width: offset.dx,
///     height: offset.dy,
///     child: child,
///   ),
/// )
/// ```
/// {@endtemplate}
class SequenceMotionBuilder<P, T extends Object> extends StatefulWidget {
  /// {@macro SequenceMotionBuilder}
  const SequenceMotionBuilder({
    required this.sequence,
    required this.converter,
    required this.builder,
    this.playing = true,
    this.currentPhase,
    this.onPhaseChanged,
    this.child,
    this.restartTrigger,
    super.key,
  });

  /// The sequence of phases and their corresponding property values.
  final MotionSequence<P, T> sequence;

  /// Converter for interpolating between property values of type [T].
  final MotionConverter<T> converter;

  /// The builder function that creates the widget tree.
  final PhaseWidgetBuilder<T, P> builder;

  /// Whether to automatically progress through the sequence.
  ///
  /// If `true`, plays through all phases automatically.
  /// If `false`, only animates when [currentPhase] changes.
  final bool playing;

  /// The phase to display or animate to.
  ///
  /// When changed, animates to this phase. If `null`, uses sequence's
  /// initial phase.
  final P? currentPhase;

  /// Called when the animation transitions to a new phase.
  final void Function(P phase)? onPhaseChanged;

  /// Optional child widget passed to [builder].
  final Widget? child;

  /// Restarts animation when this value changes.
  ///
  /// Useful for triggering replays without rebuilding the widget.
  final Object? restartTrigger;

  @override
  State<SequenceMotionBuilder<P, T>> createState() =>
      _SequenceMotionBuilderState<P, T>();
}

class _SequenceMotionBuilderState<P, T extends Object>
    extends State<SequenceMotionBuilder<P, T>> with TickerProviderStateMixin {
  late SequenceMotionController<P, T> _controller;
  P? _previousPhase;

  @override
  void initState() {
    super.initState();

    // Create controller once, like BaseMotionBuilder
    final initialPhase = widget.currentPhase ?? widget.sequence.initialPhase;
    _controller = SequenceMotionController<P, T>(
      motion: widget.sequence.motionForPhase(
        fromPhase: initialPhase,
        toPhase: initialPhase,
      ),
      vsync: this,
      converter: widget.converter,
      initialValue: _getInitialValue(),
    )..addListener(_onControllerUpdate);

    _previousPhase = initialPhase;

    // Start initial animation - this will set the current phase
    _updateAnimation();
  }

  @override
  void didUpdateWidget(SequenceMotionBuilder<P, T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle different types of changes
    final restartTriggerChanged =
        widget.restartTrigger != oldWidget.restartTrigger;
    final sequenceChanged = widget.sequence != oldWidget.sequence;
    final playingChanged = widget.playing != oldWidget.playing;
    final currentPhaseChanged = widget.currentPhase != oldWidget.currentPhase;

    if (restartTriggerChanged) {
      // Restart trigger changed - jump to phase immediately, then play if
      // needed
      _handleRestartTrigger();
    } else if (sequenceChanged || playingChanged) {
      // Sequence or playing state changed - full animation update
      _updateAnimation();
    } else if (currentPhaseChanged) {
      // Only currentPhase changed - animate to new phase
      _handleCurrentPhaseChange();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    super.dispose();
  }

  T _getInitialValue() {
    final phase = widget.currentPhase;
    if (phase != null) {
      return widget.sequence.valueForPhase(phase);
    }
    return widget.sequence.valueForPhase(widget.sequence.initialPhase);
  }

  void _updateAnimation() {
    if (!widget.playing) {
      // Not playing - stop any active sequence
      _controller.stop();

      // If currentPhase is specified, animate to it
      final phase = widget.currentPhase;
      if (phase != null) {
        _animateToPhase(phase);
      }
      return;
    }

    // Playing is true - restart the sequence from the beginning or current
    // phase
    _controller.playSequence(
      widget.sequence,
      atPhase: widget.currentPhase, // Start from specified phase if provided
      onPhaseChanged: widget.onPhaseChanged,
    );
  }

  void _handleRestartTrigger() {
    // Restart trigger changed - jump immediately to target phase
    final targetPhase = widget.currentPhase ?? widget.sequence.initialPhase;
    final targetValue = widget.sequence.valueForPhase(targetPhase);

    // Jump immediately without animation
    _controller.value = targetValue;
    widget.onPhaseChanged?.call(targetPhase);

    // Only start playing if playing is true
    if (widget.playing) {
      _controller.playSequence(
        widget.sequence,
        atPhase: targetPhase,
        onPhaseChanged: widget.onPhaseChanged,
      );
    }
  }

  void _handleCurrentPhaseChange() {
    final newPhase = widget.currentPhase;
    if (newPhase == null) return;

    if (widget.playing) {
      // If playing, animate to the new phase and continue sequence from there
      _controller.playSequence(
        widget.sequence,
        atPhase: newPhase,
        onPhaseChanged: widget.onPhaseChanged,
      );
    } else {
      // If not playing, just animate to the new phase
      _animateToPhase(newPhase);
    }
  }

  void _animateToPhase(P phase) {
    final targetValue = widget.sequence.valueForPhase(phase);
    final motion = widget.sequence.motionForPhase(
      toPhase: phase,
      fromPhase: _previousPhase as P,
    );
    _controller.motion = motion;
    _controller.animateTo(
      targetValue,
      withVelocity: _controller.velocity, // Preserve current velocity
    );
    _previousPhase = phase;
    widget.onPhaseChanged?.call(phase);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhase = _controller.currentSequencePhase ??
        widget.currentPhase ??
        widget.sequence.initialPhase;

    return widget.builder(
      context,
      _controller.value,
      currentPhase,
      widget.child,
    );
  }
}
