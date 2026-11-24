import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
/// The dots are driven by one [DotAnimator], so every change of state starts
/// from wherever the dots are, with their momentum. Idles are layered on top
/// as a [DotSceneModifier] and fade in and out with the states that have
/// them.
///
/// `DotCharacterView` creates one for you. Create your own to call
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
  }) : _character = character,
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
    _ticker = vsync.createTicker(_tick);
    _playState();
  }

  /// Drives the dots. Its listeners hear about every frame.
  late final DotAnimator<DotScene> animator;
  late final Ticker _ticker;
  final math.Random _random;

  DotCharacter _character;

  /// The character this controller runs.
  DotCharacter get character => _character;
  set character(DotCharacter value) {
    if (value == _character) return;
    _character = value;
    if (!value.states.containsKey(_state)) _state = value.initial;
    _playState();
  }

  String _state;
  bool _inTransition = false;

  /// The state the character is in, or on its way to.
  String get state => _state;

  /// Whether the character is passing through a transition.
  bool get isInTransition => _inTransition;

  /// Called whenever [state] changes.
  ValueChanged<String>? onStateChanged;

  final List<_IdleRunner> _idles = [];
  Offset? _lookTarget;
  double _lastTick = 0;
  double _clock = 0;

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
      if (idle is _LookRunner) idle.retarget(_clock, _lookTarget, _random);
    }
    _ensureTicking();
  }

  /// Blinks the layers of every [DotIdle.blink] now.
  void blink() {
    for (final idle in _idles) {
      if (idle is _BlinkRunner) idle.start(_clock);
    }
    _ensureTicking();
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
    for (final runner in _idles) {
      runner.targetWeight = idles.contains(runner.idle) ? 1 : 0;
    }
    for (final idle in idles) {
      if (_idles.any((runner) => runner.idle == idle)) continue;
      _idles.add(_IdleRunner.of(idle, _clock, _random, _lookTarget));
    }
    _ensureTicking();
  }

  void _ensureTicking() {
    if (_idles.isEmpty || _ticker.isActive) return;
    _lastTick = 0;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final dt = math.max<double>(0, now - _lastTick);
    _lastTick = now;
    _clock += dt;
    // Idles fade over about a quarter second.
    final fade = 1 - math.exp(-dt / 0.12);
    for (final runner in _idles) {
      runner
        ..weight += (runner.targetWeight - runner.weight) * fade
        ..tick(_clock, _random, _lookTarget);
    }
    _idles.removeWhere((r) => r.targetWeight == 0 && r.weight < 0.002);
    if (_idles.isEmpty) _ticker.stop();
    notifyListeners();
  }

  @override
  void modifyLayers(Float32List layers, int count) {
    for (final runner in _idles) {
      if (runner.weight <= 0) continue;
      runner.apply(layers, count, _clock);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    animator.dispose();
    super.dispose();
  }
}

const _stride = DotScene.stride;

double _seconds(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

/// A random duration around [interval], between half and one and a half
/// of it.
double _around(math.Random random, Duration interval) =>
    _seconds(interval) * (0.5 + random.nextDouble());

/// Keeps one [DotIdle] going.
abstract class _IdleRunner {
  _IdleRunner(this.idle);

  factory _IdleRunner.of(
    DotIdle idle,
    double now,
    math.Random random,
    Offset? lookTarget,
  ) => switch (idle) {
    BreatheIdle() => _BreatheRunner(idle, now),
    BobIdle() => _BobRunner(idle, now),
    BlinkIdle() => _BlinkRunner(idle, now, random),
    LookAroundIdle() => _LookRunner(idle, now, random, lookTarget),
  };

  final DotIdle idle;
  double weight = 0;
  double targetWeight = 1;

  void tick(double now, math.Random random, Offset? lookTarget) {}

  void apply(Float32List layers, int count, double now);
}

class _BreatheRunner extends _IdleRunner {
  _BreatheRunner(BreatheIdle super.idle, this.start);

  final double start;

  @override
  void apply(Float32List layers, int count, double now) {
    final idle = this.idle as BreatheIdle;
    final phase = (now - start) / _seconds(idle.period) * 2 * math.pi;
    final grow = 1 + idle.amount * weight * math.sin(phase);
    for (final layer in idle.layers) {
      if (layer >= count) continue;
      layers[layer * _stride + 5] *= grow;
    }
  }
}

class _BobRunner extends _IdleRunner {
  _BobRunner(BobIdle super.idle, this.start);

  final double start;

  @override
  void apply(Float32List layers, int count, double now) {
    final idle = this.idle as BobIdle;
    final phase = (now - start) / _seconds(idle.period) * 2 * math.pi;
    final dy = -idle.amount * weight * math.sin(phase);
    for (var layer = 0; layer < count; layer++) {
      if (idle.layers case final only? when !only.contains(layer)) continue;
      layers[layer * _stride + 3] += dy;
    }
  }
}

class _BlinkRunner extends _IdleRunner {
  _BlinkRunner(BlinkIdle super.idle, double now, math.Random random)
    : _next = now + _around(random, idle.interval);

  static const _close = 0.07;
  static const _open = 0.13;

  double _next;
  double? _started;
  bool _twice = false;

  void start(double now) {
    _started = now;
    _twice = false;
  }

  @override
  void tick(double now, math.Random random, Offset? lookTarget) {
    final started = _started;
    if (started != null && now - started > _close + _open) {
      if (_twice) {
        _twice = false;
        _started = now + 0.08;
      } else {
        _started = null;
      }
    }
    if (_started == null && now >= _next) {
      _started = now;
      _twice = random.nextDouble() < 0.2;
      _next = now + _around(random, (idle as BlinkIdle).interval);
    }
  }

  @override
  void apply(Float32List layers, int count, double now) {
    final idle = this.idle as BlinkIdle;
    final started = _started;
    if (started == null || idle.layer >= count) return;
    final t = now - started;
    if (t < 0) return;
    final shut = t < _close
        ? Curves.easeIn.transform(t / _close)
        : 1 - Curves.easeOut.transform(((t - _close) / _open).clamp(0, 1));
    final squash = 1 - (1 - idle.closed) * shut * weight;
    layers[idle.layer * _stride + 4] *= squash;
  }
}

class _LookRunner extends _IdleRunner {
  _LookRunner(
    LookAroundIdle idle,
    double now,
    math.Random random,
    Offset? lookTarget,
  ) : super(idle) {
    _x = _Spring(idle.motion);
    _y = _Spring(idle.motion);
    retarget(now, lookTarget, random);
  }

  late final _Spring _x;
  late final _Spring _y;
  double _next = 0;

  void retarget(double now, Offset? lookTarget, math.Random random) {
    final idle = this.idle as LookAroundIdle;
    final Offset target;
    if (lookTarget != null) {
      target = Offset(
        lookTarget.dx.clamp(-1, 1) * idle.range.dx,
        lookTarget.dy.clamp(-1, 1) * idle.range.dy,
      );
    } else if (random.nextDouble() < 0.3) {
      target = Offset.zero;
    } else {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = 0.5 + random.nextDouble() * 0.5;
      target = Offset(
        math.cos(angle) * distance * idle.range.dx,
        math.sin(angle) * distance * idle.range.dy,
      );
    }
    _x.moveTo(target.dx, now);
    _y.moveTo(target.dy, now);
    _next = now + _around(random, idle.interval);
  }

  @override
  void tick(double now, math.Random random, Offset? lookTarget) {
    if (lookTarget == null && now >= _next) retarget(now, null, random);
  }

  @override
  void apply(Float32List layers, int count, double now) {
    final idle = this.idle as LookAroundIdle;
    final dx = _x.at(now) * weight;
    final dy = _y.at(now) * weight;
    for (final layer in idle.layers) {
      if (layer >= count) continue;
      layers[layer * _stride + 2] += dx;
      layers[layer * _stride + 3] += dy;
    }
  }
}

/// A value that follows its target with a motor [Motion], keeping its
/// velocity when the target changes.
class _Spring {
  _Spring(this.motion);

  final Motion motion;
  Simulation? _simulation;
  double _start = 0;
  double _value = 0;

  double at(double now) {
    final simulation = _simulation;
    if (simulation == null) return _value;
    return simulation.x(math.max(0, now - _start));
  }

  void moveTo(double target, double now) {
    final simulation = _simulation;
    final t = math.max<double>(0, now - _start);
    final value = simulation?.x(t) ?? _value;
    final velocity = simulation?.dx(t) ?? 0;
    _value = value;
    _start = now;
    _simulation = motion.createSimulation(
      start: value,
      end: target,
      velocity: velocity,
    );
  }
}
