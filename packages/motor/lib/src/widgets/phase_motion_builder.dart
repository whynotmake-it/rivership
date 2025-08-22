import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/phase_controller.dart';
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
/// final phases = MapPhaseSequence(
///   phaseMap: {
///     ButtonState.idle: ButtonProperties(width: 100, height: 40),
///     ButtonState.pressed: ButtonProperties(width: 95, height: 38),
///     ButtonState.loading: ButtonProperties(width: 40, height: 40),
///   },
/// );
///
/// PhaseMotionBuilder<ButtonProperties, ButtonState>(
///   sequence: phases,
///   motion: CupertinoMotion.bouncy(),
///   trigger: buttonTapCount,
///   builder: (context, properties, phase, child) {
///     return Container(
///       width: properties.width,
///       height: properties.height,
///       child: _buildButtonContent(phase),
///     );
///   },
/// )
/// ```
/// {@endtemplate}
class PhaseMotionBuilder<T extends Object, P> extends StatefulWidget {
  /// {@macro PhaseMotionBuilder}
  const PhaseMotionBuilder({
    required this.sequence,
    required this.converter,
    required this.builder,
    this.restartTrigger,
    this.onPhaseChanged,
    this.playing = true,
    this.loopMode = PhaseLoopMode.loop,
    this.child,
    super.key,
  });

  /// The sequence of phases and their corresponding property values.
  final PhaseSequence<T, P> sequence;

  /// Converter for interpolating between property values of type [T].
  final MotionConverter<T> converter;

  /// The builder function that creates the widget tree.
  final PhaseWidgetBuilder<T, P> builder;

  /// A trigger value that causes the phase sequence to restart.
  ///
  /// When this value changes, the animation will reset to the first phase
  /// and begin the sequence again. This is useful for user interactions
  /// like button taps or state changes.
  final Object? restartTrigger;

  /// Called when the current phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// Whether the sequence should currently be playing.
  final bool playing;

  /// The manner in which the phase animation should loop.
  ///
  /// Defaults to [PhaseLoopMode.loop].
  final PhaseLoopMode loopMode;

  /// An optional child widget to pass to the [builder].
  ///
  /// This is useful for optimization when part of the widget tree
  /// doesn't need to change during the animation.
  final Widget? child;

  @override
  State<PhaseMotionBuilder<T, P>> createState() =>
      _PhaseMotionBuilderState<T, P>();
}

class _PhaseMotionBuilderState<T extends Object, P>
    extends State<PhaseMotionBuilder<T, P>> with TickerProviderStateMixin {
  late PhaseController<T, P> _controller;
  Object? _lastTrigger;

  @override
  void initState() {
    super.initState();
    _createController();
    _lastTrigger = widget.restartTrigger;

    if (widget.playing) {
      _controller.start();
    }
  }

  @override
  void didUpdateWidget(PhaseMotionBuilder<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate controller if converter changed
    if (widget.converter != oldWidget.converter) {
      _controller.dispose();
      _createController();
      if (widget.playing) {
        _controller.start();
      }
      return;
    }

    // Update controller sequence if it changed
    if (widget.sequence != oldWidget.sequence) {
      _controller.sequence = widget.sequence;
    }

    // Check if trigger changed
    if (widget.restartTrigger != _lastTrigger) {
      _lastTrigger = widget.restartTrigger;
      _controller.reset();
      if (widget.playing) {
        _controller.start();
      }
    }

    if (widget.loopMode != oldWidget.loopMode) {
      _controller.loopMode = widget.loopMode;
    }

    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _controller.start();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _createController() {
    _controller = PhaseController<T, P>(
      sequence: widget.sequence,
      converter: widget.converter,
      vsync: this,
      onPhaseChanged: widget.onPhaseChanged,
      loopMode: widget.loopMode,
    );
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        // Trigger rebuild with new interpolated values
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _controller.value,
      _controller.currentPhase,
      widget.child,
    );
  }
}

/// A simplified version of [PhaseMotionBuilder] for single-value animations.
///
/// This widget is useful when you want to animate a single property through
/// multiple phases, similar to SwiftUI's PhaseAnimator with simple values.
class SinglePhaseMotionBuilder<P extends num> extends StatefulWidget {
  /// Creates a [SinglePhaseMotionBuilder] that animates through double values.
  const SinglePhaseMotionBuilder({
    required this.phases,
    required this.builder,
    required this.motion,
    this.trigger,
    this.onPhaseChanged,
    this.playing = true,
    this.loopMode = PhaseLoopMode.loop,
    this.child,
    super.key,
  });

  /// The sequence of phases to animate through.
  ///
  /// Each phase represents a target value for the animation.
  final List<P> phases;

  /// The builder function that creates the widget tree.
  final Widget Function(
    BuildContext context,
    double value,
    Widget? child,
  ) builder;

  /// The motion to use for phase transitions.
  final Motion motion;

  /// A trigger value that restarts the phase sequence.
  final Object? trigger;

  /// Called when the current phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// Whether the animation is currently playing.
  final bool playing;

  /// Whether the animation should loop.
  final PhaseLoopMode loopMode;

  /// An optional child widget to pass to the [builder].
  final Widget? child;

  @override
  State<SinglePhaseMotionBuilder<P>> createState() =>
      _SinglePhaseMotionBuilderState<P>();
}

class _SinglePhaseMotionBuilderState<P extends num>
    extends State<SinglePhaseMotionBuilder<P>> {
  late PhaseSequence<double, P> _sequence;

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
    // For numeric phases, use the phase value directly
    if (P == double || P == int) {
      _sequence = ValuePhaseSequence<double>(
        motion: (_) => widget.motion,
        values: widget.phases.map((p) => (p as num).toDouble()).toList(),
      ) as PhaseSequence<double, P>;
    } else {
      // For non-numeric phases, use phase index as the animated value
      _sequence = MapPhaseSequence<double, P>(
        motion: (_) => widget.motion,
        phaseMap: {
          for (final phase in widget.phases)
            phase: widget.phases.indexOf(phase).toDouble(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhaseMotionBuilder<double, P>(
      sequence: _sequence,
      converter: const SingleMotionConverter(),
      restartTrigger: widget.trigger,
      onPhaseChanged: widget.onPhaseChanged,
      playing: widget.playing,
      loopMode: widget.loopMode,
      builder: (context, value, _, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
