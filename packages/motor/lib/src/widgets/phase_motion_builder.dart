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
/// You can control the current phase by passing a [current] value. When
/// this changes, the animation will automatically transition to the new phase
/// while respecting the [playing] setting.
///
/// Example usage:
/// ```dart
/// enum ButtonState { idle, pressed, loading }
///
/// final phases = MapPhaseSequence(
///   phaseMap: {
///     ButtonState.idle: const Offset(100, 40),
///     ButtonState.pressed: const Offset(95, 38),
///     ButtonState.loading: const Offset(40, 40),
///   },
///   motion: (_) => const CupertinoMotion.bouncy(),
/// );
///
/// PhaseMotionBuilder(
///   sequence: phases,
///   converter: const OffsetMotionConverter(),
///   currentPhase: currentButtonState,
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
    this.current,
    this.restartTrigger,
    this.onPhaseChanged,
    this.playing = true,
    this.child,
    super.key,
  });

  /// The sequence of phases and their corresponding property values.
  final PhaseSequence<P, T> sequence;

  /// Converter for interpolating between property values of type [T].
  final MotionConverter<T> converter;

  /// The builder function that creates the widget tree.
  final PhaseWidgetBuilder<T, P> builder;

  /// The current phase to display.
  ///
  /// When this value changes, the animation will automatically transition
  /// to the specified phase. If null, defaults to the first phase of the
  /// sequence. The animation will continue playing or looping based on
  /// the [playing] setting after transitioning.
  final P? current;

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

  /// An optional child widget to pass to the [builder].
  ///
  /// This is useful for optimization when part of the widget tree
  /// doesn't need to change during the animation.
  final Widget? child;

  @override
  State<PhaseMotionBuilder<P, T>> createState() =>
      _PhaseMotionBuilderState<P, T>();
}

class _PhaseMotionBuilderState<P, T extends Object>
    extends State<PhaseMotionBuilder<P, T>> with TickerProviderStateMixin {
  late PhaseController<P, T> _controller;
  Object? _lastTrigger;
  P? _lastCurrentPhase;

  @override
  void initState() {
    super.initState();
    _createController();

    _lastTrigger = widget.restartTrigger;
    _lastCurrentPhase = widget.current;

    if (widget.current case final phase?) {
      _controller.jumpToPhase(phase);
    }

    if (widget.playing) {
      _controller.start();
    }
  }

  @override
  void didUpdateWidget(PhaseMotionBuilder<P, T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller sequence if it changed
    if (widget.sequence != oldWidget.sequence) {
      _controller.sequence = widget.sequence;

      if (widget.playing && !_controller.isAnimating) {
        _controller.start();
      }
    } else if (widget.current != _lastCurrentPhase) {
      _lastCurrentPhase = widget.current;

      if (widget.current case final phase?) {
        _controller.goToPhase(phase);
      }

      // Continue playing if it was already playing
      if (widget.playing && !_controller.isAnimating) {
        _controller.start();
      }
      return;
    } else if (widget.restartTrigger != _lastTrigger) {
      _lastTrigger = widget.restartTrigger;
      _controller.reset();

      if (widget.playing) {
        _controller.start();
        return;
      }
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
    _controller = PhaseController(
      sequence: widget.sequence,
      converter: widget.converter,
      vsync: this,
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

/// {@template SinglePhaseMotionBuilder}
/// A simplified version of [PhaseMotionBuilder] for single-value animations.
///
/// This widget is useful when you want to animate a single property through
/// multiple phases, similar to SwiftUI's PhaseAnimator with simple values.
/// The phases themselves are the values being animated.
///
/// You can control the current phase by passing a [current] value. When
/// this changes, the animation will automatically transition to the new phase
/// while respecting the [playing] and [loopMode] settings.
///
/// Example usage:
/// ```dart
/// SinglePhaseMotionBuilder<double>(
///   phases: [0.0, 1.0, 0.5],
///   motion: const CupertinoMotion.smooth(),
///   currentPhase: currentValue,
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
    this.current,
    this.restartTrigger,
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

  /// The current phase to display.
  ///
  /// When this value changes, the animation will automatically transition
  /// to the specified phase. If null, defaults to the first phase of the
  /// sequence. The animation will continue playing or looping based on
  /// the [playing] and [loopMode] settings after transitioning.
  final P? current;

  /// A trigger value that restarts the phase sequence.
  final Object? restartTrigger;

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
      current: widget.current,
      restartTrigger: widget.restartTrigger,
      onPhaseChanged: widget.onPhaseChanged,
      playing: widget.playing,
      builder: (context, value, _, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
