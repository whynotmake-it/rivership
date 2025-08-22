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
    this.motion,
    this.motionPerPhase,
    this.trigger,
    this.onPhaseChanged,
    this.autoStart = true,
    this.child,
    super.key,
  }) : assert(
          motion != null || motionPerPhase != null,
          'Either motion or motionPerPhase must be provided',
        );

  /// The sequence of phases and their corresponding property values.
  final PhaseSequence<T, P> sequence;

  /// Converter for interpolating between property values of type [T].
  final MotionConverter<T> converter;

  /// The builder function that creates the widget tree.
  final PhaseWidgetBuilder<T, P> builder;

  /// The default motion to use for all phase transitions.
  ///
  /// If [motionPerPhase] is provided, this is ignored.
  final Motion? motion;

  /// Custom motions for each phase transition.
  ///
  /// The list should contain one motion for each phase in the sequence.
  /// If provided, this overrides [motion].
  final List<Motion>? motionPerPhase;

  /// A trigger value that causes the phase sequence to restart.
  ///
  /// When this value changes, the animation will reset to the first phase
  /// and begin the sequence again. This is useful for user interactions
  /// like button taps or state changes.
  final Object? trigger;

  /// Called when the current phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// Whether to automatically start the phase sequence.
  ///
  /// If true and the sequence has [PhaseSequence.autoLoop] enabled,
  /// the animation will begin immediately. If false, you must call
  /// [PhaseController.start] manually.
  final bool autoStart;

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
    _lastTrigger = widget.trigger;

    if (widget.autoStart) {
      _controller.start();
    }
  }

  @override
  void didUpdateWidget(PhaseMotionBuilder<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if trigger changed
    if (widget.trigger != _lastTrigger) {
      _lastTrigger = widget.trigger;
      _controller.reset();
      if (widget.autoStart) {
        _controller.start();
      }
      return;
    }

    // Recreate controller if sequence, motion, or converter changed
    if (widget.sequence != oldWidget.sequence ||
        widget.motion != oldWidget.motion ||
        widget.motionPerPhase != oldWidget.motionPerPhase ||
        widget.converter != oldWidget.converter) {
      _controller.dispose();
      _createController();
      if (widget.autoStart) {
        _controller.start();
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
      motion: widget.motion,
      motionPerPhase: widget.motionPerPhase,
      onPhaseChanged: widget.onPhaseChanged,
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
class SinglePhaseMotionBuilder<P> extends StatefulWidget {
  /// Creates a [SinglePhaseMotionBuilder] that animates through double values.
  const SinglePhaseMotionBuilder({
    required this.phases,
    required this.builder,
    this.motion,
    this.motionPerPhase,
    this.trigger,
    this.onPhaseChanged,
    this.autoStart = true,
    this.child,
    super.key,
  }) : assert(
          motion != null || motionPerPhase != null,
          'Either motion or motionPerPhase must be provided',
        );

  /// The sequence of phases to animate through.
  ///
  /// Each phase represents a target value for the animation.
  final List<P> phases;

  /// The builder function that creates the widget tree.
  ///
  /// For phases that are directly numeric (like double), [value] will be
  /// the interpolated numeric value. For other phase types, [value] will
  /// be the phase index as a double.
  final Widget Function(
    BuildContext context,
    double value,
    P phase,
    Widget? child,
  ) builder;

  /// The motion to use for phase transitions.
  final Motion? motion;

  /// Custom motions for each phase transition.
  final List<Motion>? motionPerPhase;

  /// A trigger value that restarts the phase sequence.
  final Object? trigger;

  /// Called when the current phase changes.
  final void Function(P phase)? onPhaseChanged;

  /// Whether to automatically start the phase sequence.
  final bool autoStart;

  /// An optional child widget to pass to the [builder].
  final Widget? child;

  @override
  State<SinglePhaseMotionBuilder<P>> createState() =>
      _SinglePhaseMotionBuilderState<P>();
}

class _SinglePhaseMotionBuilderState<P>
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
        values: widget.phases.map((p) => (p as num).toDouble()).toList(),
        autoLoop: true,
      ) as PhaseSequence<double, P>;
    } else {
      // For non-numeric phases, use phase index as the animated value
      _sequence = MapPhaseSequence<double, P>(
        phaseMap: {
          for (final phase in widget.phases)
            phase: widget.phases.indexOf(phase).toDouble(),
        },
        autoLoop: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhaseMotionBuilder<double, P>(
      sequence: _sequence,
      converter: const SingleMotionConverter(),
      motion: widget.motion,
      motionPerPhase: widget.motionPerPhase,
      trigger: widget.trigger,
      onPhaseChanged: widget.onPhaseChanged,
      autoStart: widget.autoStart,
      builder: (context, value, phase, child) {
        return widget.builder(context, value, phase, child);
      },
      child: widget.child,
    );
  }
}
