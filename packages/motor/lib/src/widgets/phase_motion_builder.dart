import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/phase_sequence.dart';

/// A function that builds a widget based on the current phase and interpolated
/// value.
typedef PhaseWidgetBuilder<T extends Object, P> = Widget Function(
  BuildContext context,
  T value,
  P phase,
  Widget? child,
);

/// {@template PhaseMotionBuilder}
/// A widget that creates phase-based animations using Motor's motion system.
///
/// This widget animates through a sequence of phases, with each phase defining
/// target property values. The transitions between phases use Motor's physics
/// or duration-based motion system for smooth, natural animations.
///
/// Example usage:
/// ```dart
/// enum ButtonState { idle, pressed, loading }
///
/// final phases = PhaseSequence.map({
///   ButtonState.idle: const Offset(100, 40),
///   ButtonState.pressed: const Offset(95, 38),
///   ButtonState.loading: const Offset(40, 40),
/// }, motion: (_) => Springs.bouncy);
///
/// PhaseMotionBuilder(
///   sequence: phases,
///   converter: OffsetMotionConverter(),
///   playing: true, // Enable automatic sequence progression
///   currentPhase: currentButtonState, // Or null for auto-sequence
///   builder: (context, offset, phase, child) {
///     return Container(
///       width: offset.dx,
///       height: offset.dy,
///       child: _buildButtonContent(phase),
///     );
///   },
/// )
/// ```
/// {@endtemplate}
class PhaseMotionBuilder<P, T extends Object> extends StatefulWidget {
  /// {@macro PhaseMotionBuilder}
  const PhaseMotionBuilder({
    required this.sequence,
    required this.converter,
    required this.builder,
    this.motion,
    this.playing = true,
    this.currentPhase,
    this.onPhaseChanged,
    this.child,
    super.key,
  });

  /// The sequence of phases and their corresponding property values.
  final PhaseSequence<P, T> sequence;

  /// Converter for interpolating between property values of type [T].
  final MotionConverter<T> converter;

  /// The builder function that creates the widget tree.
  final PhaseWidgetBuilder<T, P> builder;

  /// The default motion to use when phases don't specify their own motion.
  /// If null, uses the motion defined in the sequence.
  final Motion? motion;

  /// Whether the sequence should currently be playing.
  ///
  /// If true, the sequence will automatically progress through phases.
  /// If false, only manual phase changes via [currentPhase] will animate.
  final bool playing;

  /// The current phase to display.
  ///
  /// When this value changes, the animation will automatically transition
  /// to the specified phase. If null, uses the sequence's initial phase.
  final P? currentPhase;

  /// Called when the current phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// An optional child widget to pass to the [builder].
  final Widget? child;

  @override
  State<PhaseMotionBuilder<P, T>> createState() =>
      _PhaseMotionBuilderState<P, T>();
}

class _PhaseMotionBuilderState<P, T extends Object>
    extends State<PhaseMotionBuilder<P, T>> with TickerProviderStateMixin {
  late PhaseSequenceController<P, T> _controller;

  @override
  void initState() {
    super.initState();

    // Create controller once, like BaseMotionBuilder
    _controller = PhaseSequenceController<P, T>(
      motion: widget.motion ??
          widget.sequence.motionForPhase(widget.sequence.phases.first),
      vsync: this,
      converter: widget.converter,
      initialValue: _getInitialValue(),
    )..addListener(_onControllerUpdate);

    // Start initial animation - this will set the current phase
    _updateAnimation();
  }

  @override
  void didUpdateWidget(PhaseMotionBuilder<P, T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update motion if it changed (like BaseMotionBuilder does)
    final newMotion = widget.motion ??
        widget.sequence.motionForPhase(widget.sequence.phases.first);
    final oldMotion = oldWidget.motion ??
        oldWidget.sequence.motionForPhase(oldWidget.sequence.phases.first);

    if (newMotion != oldMotion) {
      _controller.motion = newMotion;
    }

    // Handle sequence, currentPhase, or playing changes
    if (widget.sequence != oldWidget.sequence ||
        widget.currentPhase != oldWidget.currentPhase ||
        widget.playing != oldWidget.playing) {
      _updateAnimation();
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

    // Playing is true - always play the sequence
    _controller.playSequence(
      widget.sequence,
      atPhase: widget.currentPhase, // Start from specified phase if provided
      onPhaseChanged: widget.onPhaseChanged,
    );
  }

  void _animateToPhase(P phase) {
    final targetValue = widget.sequence.valueForPhase(phase);
    final motion = widget.sequence.motionForPhase(phase);
    _controller.motion = motion;
    _controller.animateTo(targetValue);
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

/// {@template SinglePhaseMotionBuilder}
/// A simplified version of [PhaseMotionBuilder] for single-value animations.
///
/// This widget is useful when you want to animate a single property through
/// multiple phases. The phases themselves are the values being animated.
///
/// Example usage:
/// ```dart
/// SinglePhaseMotionBuilder<double>(
///   phases: [0.0, 1.0, 0.5],
///   motion: Springs.smooth,
///   playing: true, // Enable automatic sequence progression
///   currentPhase: currentValue, // Or null for auto-sequence
///   builder: (context, value, child) {
///     return Opacity(
///       opacity: value,
///       child: child,
///     );
///   },
///   child: const Icon(Icons.star),
/// )
/// ```
/// {@endtemplate}
class SinglePhaseMotionBuilder<P extends num> extends StatefulWidget {
  /// {@macro SinglePhaseMotionBuilder}
  const SinglePhaseMotionBuilder({
    required this.phases,
    required this.builder,
    required this.motion,
    this.playing = true,
    this.currentPhase,
    this.loopMode = PhaseLoopMode.loop,
    this.onPhaseChanged,
    this.child,
    super.key,
  });

  /// The sequence of phases to animate through.
  final List<P> phases;

  /// The builder function that creates the widget tree.
  final Widget Function(
    BuildContext context,
    double value,
    Widget? child,
  ) builder;

  /// The motion to use for phase transitions.
  final Motion motion;

  /// Whether the sequence should currently be playing.
  final bool playing;

  /// The current phase to display.
  final P? currentPhase;

  /// How the animation should loop.
  final PhaseLoopMode loopMode;

  /// Called when the current phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// An optional child widget to pass to the [builder].
  final Widget? child;

  @override
  State<SinglePhaseMotionBuilder<P>> createState() =>
      _SinglePhaseMotionBuilderState<P>();
}

class _SinglePhaseMotionBuilderState<P extends num>
    extends State<SinglePhaseMotionBuilder<P>> {
  late PhaseSequence<P, double> _sequence;

  @override
  void initState() {
    super.initState();
    _createSequence();
  }

  @override
  void didUpdateWidget(SinglePhaseMotionBuilder<P> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phases != oldWidget.phases) {
      _createSequence();
    }
  }

  void _createSequence() {
    _sequence = PhaseSequence.map(
      {for (final p in widget.phases) p: p.toDouble()},
      motion: (_) => widget.motion,
      loopMode: widget.loopMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhaseMotionBuilder(
      sequence: _sequence,
      converter: const SingleMotionConverter(),
      motion: widget.motion,
      playing: widget.playing,
      currentPhase: widget.currentPhase,
      onPhaseChanged: widget.onPhaseChanged,
      builder: (context, value, _, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
