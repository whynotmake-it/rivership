import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:merging_dots/src/animation/dot_animator.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/character/dot_character.dart';
import 'package:merging_dots/src/character/dot_idle.dart';
import 'package:merging_dots/src/model/dot_scene.dart';
import 'package:merging_dots/src/rendering/render_dots.dart';
import 'package:motor/motor.dart';

/// Runs a [DotCharacter]: plays its states, passes through its transitions
/// and keeps its idles going.
///
/// Everything moves with motor. The dots are driven by one [DotAnimator],
/// so every change of state starts from wherever the dots are, with their
/// momentum. Each idle is a pair of motor controllers, one for what it does
/// and one fading it in and out with the states that have it, layered on
/// top as a [DotSceneModifier].
///
/// All of them tick with the `vsync` it is given, which must be able to
/// create several tickers. Use motor's `FixedTickerProviderStateMixin` to
/// run the whole character at a lower frame rate under a `TickerRateScope`,
/// like `DotCharacterView` does.
///
/// `DotCharacterView` creates a controller for you. Create your own to call
/// [lookAt] or [blink], or to listen to [state].
class DotCharacterController extends ChangeNotifier
    implements DotSceneModifier {
  /// Creates a controller for [character], starting in [initialState] or
  /// the character's initial state.
  ///
  /// [seed] makes the idles' randomness repeatable.
  DotCharacterController({
    required TickerProvider vsync,
    required DotCharacter character,
    String? initialState,
    int? seed,
  }) : _vsync = vsync,
       _character = character,
       _state = initialState ?? character.initial,
       _random = math.Random(seed) {
    final state = character.state(_state);
    animator =
        DotAnimator<DotScene>(
            vsync: vsync,
            initial: state.animation.frames.first.state,
          )
          ..onSequenceEnd = _onSequenceEnd
          ..addListener(notifyListeners);
    _playState();
  }

  final TickerProvider _vsync;
  final math.Random _random;

  /// Drives the dots. Its listeners hear about every frame.
  late final DotAnimator<DotScene> animator;

  DotCharacter _character;

  /// The character this controller runs.
  ///
  /// Setting another one moves the dots to its pose for the current state,
  /// for example from one body shape to another.
  DotCharacter get character => _character;
  set character(DotCharacter value) {
    if (value == _character) return;
    _character = value;
    if (!value.states.containsKey(_state)) _state = value.initial;
    _playState();
  }

  String _state;
  bool _inTransition = false;
  bool _disposed = false;

  /// The state the character is in, or on its way to.
  String get state => _state;

  /// Whether the character is passing through a transition.
  bool get isInTransition => _inTransition;

  /// Called whenever [state] changes.
  ValueChanged<String>? onStateChanged;

  final List<_IdleRunner> _idles = [];
  Offset? _lookTarget;

  /// Moves to the state called [name], through a transition if the
  /// character has one.
  ///
  /// Interrupting a transition or a state's animation is fine: the dots
  /// carry on from where they are.
  void goTo(String name) {
    _character.state(name);
    if (name == _state && !_inTransition) return;
    final from = _state;
    _state = name;
    onStateChanged?.call(name);
    final transition = _character.transition(from, name);
    if (transition == null || transition.via.isEmpty) {
      _playState();
      return;
    }
    _inTransition = true;
    _syncIdles(const []);
    animator.play(
      DotSequence(
        transition.via,
        motion: transition.motion,
        loop: LoopMode.none,
      ),
    );
  }

  /// Points the eyes, the layers of every [DotIdle.lookAround], toward
  /// [direction]: `(-1, -1)` is the top left of their range, `(1, 1)` the
  /// bottom right. Pass null to let them wander again.
  void lookAt(Offset? direction) {
    _lookTarget = direction;
    for (final idle in _idles) {
      if (idle is _LookRunner) idle.lookAt(direction);
    }
  }

  /// Blinks the layers of every [DotIdle.blink] now.
  void blink() {
    for (final idle in _idles) {
      if (idle is _BlinkRunner) idle.blinkNow();
    }
  }

  void _playState() {
    _inTransition = false;
    final state = _character.state(_state);
    _syncIdles(state.idles);
    animator.play(state.animation);
  }

  void _onSequenceEnd() {
    if (_inTransition) {
      _playState();
      return;
    }
    final next = _character.state(_state).next;
    if (next != null) goTo(next);
  }

  /// Fades out idles that the new state doesn't have and starts the ones
  /// it adds.
  void _syncIdles(List<DotIdle> idles) {
    for (final runner in [..._idles]) {
      if (idles.contains(runner.idle)) {
        runner.fadeTo(1);
        continue;
      }
      runner.fadeTo(0).then((_) {
        if (_disposed || runner.weight.value > 0) return;
        _idles.remove(runner);
        runner
          ..removeListener(notifyListeners)
          ..dispose();
      });
    }
    for (final idle in idles) {
      if (_idles.any((runner) => runner.idle == idle)) continue;
      final runner = _IdleRunner.of(idle, _vsync, _random)
        ..addListener(notifyListeners)
        ..start(_lookTarget);
      _idles.add(runner);
      runner.fadeTo(1);
    }
  }

  @override
  void modifyLayers(Float32List layers, int count) {
    for (final runner in _idles) {
      final weight = runner.weight.value;
      if (weight <= 0) continue;
      runner.apply(layers, count, weight);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final runner in _idles) {
      runner.dispose();
    }
    _idles.clear();
    animator.dispose();
    super.dispose();
  }
}

const _stride = DotScene.stride;

/// A random duration around [interval], between half and one and a half
/// of it.
Duration _around(math.Random random, Duration interval) =>
    interval * (0.5 + random.nextDouble());

/// Keeps one [DotIdle] going with motor controllers.
abstract class _IdleRunner {
  _IdleRunner(this.idle, TickerProvider vsync)
    : weight = SingleMotionController(
        motion: const CupertinoMotion(duration: Duration(milliseconds: 450)),
        vsync: vsync,
      );

  factory _IdleRunner.of(
    DotIdle idle,
    TickerProvider vsync,
    math.Random random,
  ) => switch (idle) {
    BreatheIdle() => _WaveRunner(idle, vsync, idle.period),
    BobIdle() => _WaveRunner(idle, vsync, idle.period),
    BlinkIdle() => _BlinkRunner(idle, vsync, random),
    LookAroundIdle() => _LookRunner(idle, vsync, random),
  };

  final DotIdle idle;

  /// How much the idle shows, faded in and out with its states.
  final SingleMotionController weight;

  /// The controllers that move the idle.
  List<Listenable> get controllers;

  late final Listenable _all = Listenable.merge([weight, ...controllers]);

  void addListener(VoidCallback listener) => _all.addListener(listener);

  void removeListener(VoidCallback listener) => _all.removeListener(listener);

  MotionFuture fadeTo(double target) => weight.animateTo(target);

  void start(Offset? lookTarget);

  void apply(Float32List layers, int count, double weight);

  @mustCallSuper
  void dispose() => weight.dispose();
}

/// Swings between -1 and 1 like a sine for [BreatheIdle] and [BobIdle].
class _WaveRunner extends _IdleRunner {
  _WaveRunner(super.idle, super.vsync, this.period)
    : wave = SingleMotionController(
        motion: const CupertinoMotion.smooth(),
        vsync: vsync,
      );

  final Duration period;
  final SingleMotionController wave;

  @override
  List<Listenable> get controllers => [wave];

  @override
  void start(Offset? lookTarget) {
    // A quarter swing up from the middle, then half swings back and forth.
    final half = CurvedMotion(period ~/ 2, Curves.easeInOutSine);
    wave
        .play([
          TrackStep.to(
            1,
            motion: CurvedMotion(period ~/ 4, Curves.easeOutSine),
          ),
        ])
        .then(
          (_) => wave.play([
            TrackStep.to(-1, motion: half),
            TrackStep.to(1, motion: half),
          ], loop: LoopMode.loop),
        );
  }

  @override
  void apply(Float32List layers, int count, double weight) {
    final swing = wave.value * weight;
    switch (idle) {
      case BreatheIdle(layers: final breathing, :final amount):
        for (final layer in breathing) {
          if (layer < count) layers[layer * _stride + 5] *= 1 + amount * swing;
        }
      case BobIdle(layers: final floating, :final amount):
        for (var layer = 0; layer < count; layer++) {
          if (floating != null && !floating.contains(layer)) continue;
          layers[layer * _stride + 3] -= amount * swing;
        }
      default:
    }
  }

  @override
  void dispose() {
    wave.dispose();
    super.dispose();
  }
}

/// Shuts a layer now and then, sometimes twice.
class _BlinkRunner extends _IdleRunner {
  _BlinkRunner(BlinkIdle super.idle, super.vsync, this.random)
    : shut = SingleMotionController(
        motion: const CupertinoMotion.smooth(),
        vsync: vsync,
      );

  static const _close = CurvedMotion(
    Duration(milliseconds: 70),
    Curves.easeIn,
  );
  static const _open = CurvedMotion(
    Duration(milliseconds: 130),
    Curves.easeOut,
  );

  final math.Random random;

  /// 0 when open, 1 when shut.
  final SingleMotionController shut;

  BlinkIdle get _idle => idle as BlinkIdle;

  @override
  List<Listenable> get controllers => [shut];

  @override
  void start(Offset? lookTarget) => _next();

  List<TrackStep<double>> get _blink => const [
    TrackStep.to(1, motion: _close),
    TrackStep.to(0, motion: _open),
  ];

  void _next() {
    final twice = random.nextDouble() < 0.2;
    shut
        .play([
          TrackStep.hold(_around(random, _idle.interval)),
          ..._blink,
          if (twice) ...[
            const TrackStep.hold(Duration(milliseconds: 80)),
            ..._blink,
          ],
        ])
        .then((_) => _next());
  }

  void blinkNow() => shut.play(_blink).then((_) => _next());

  @override
  void apply(Float32List layers, int count, double weight) {
    final layer = _idle.layer;
    if (layer >= count) return;
    layers[layer * _stride + 4] *= 1 - (1 - _idle.closed) * shut.value * weight;
  }

  @override
  void dispose() {
    shut.dispose();
    super.dispose();
  }
}

/// Moves layers to a new spot now and then, or where they are told to look.
class _LookRunner extends _IdleRunner {
  _LookRunner(LookAroundIdle super.idle, super.vsync, this.random)
    : gaze = MotionController<Offset>(
        motion: idle.motion,
        vsync: vsync,
        converter: MotionConverter.offset,
        initialValue: Offset.zero,
      );

  final math.Random random;
  final MotionController<Offset> gaze;

  LookAroundIdle get _idle => idle as LookAroundIdle;

  @override
  List<Listenable> get controllers => [gaze];

  @override
  void start(Offset? lookTarget) => lookAt(lookTarget);

  void lookAt(Offset? direction) {
    if (direction == null) {
      _wander();
      return;
    }
    final range = _idle.range;
    gaze.animateTo(
      Offset(
        direction.dx.clamp(-1, 1) * range.dx,
        direction.dy.clamp(-1, 1) * range.dy,
      ),
    );
  }

  void _wander() {
    final range = _idle.range;
    final Offset spot;
    if (random.nextDouble() < 0.3) {
      spot = Offset.zero;
    } else {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = 0.5 + random.nextDouble() * 0.5;
      spot = Offset(
        math.cos(angle) * distance * range.dx,
        math.sin(angle) * distance * range.dy,
      );
    }
    gaze
        .play([
          TrackStep.hold(_around(random, _idle.interval)),
          TrackStep.to(spot),
        ])
        .then((_) => _wander());
  }

  @override
  void apply(Float32List layers, int count, double weight) {
    final offset = gaze.value * weight;
    for (final layer in _idle.layers) {
      if (layer >= count) continue;
      layers[layer * _stride + 2] += offset.dx;
      layers[layer * _stride + 3] += offset.dy;
    }
  }

  @override
  void dispose() {
    gaze.dispose();
    super.dispose();
  }
}
