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
/// momentum. Every idle is a few tracks of one motor [TrackController],
/// [idleTracks]: what it does, and how much it shows, faded in and out
/// with the states that have it. They are layered on top as a
/// [DotSceneModifier].
///
/// The dots and the idles tick with the `vsync` it is given, which must be
/// able to create two tickers. Use motor's `FixedTickerProviderStateMixin`
/// to run the whole character at a lower frame rate under a
/// `TickerRateScope`, like `DotCharacterView` does.
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
  }) : _character = character,
       _state = initialState ?? character.initial,
       _random = math.Random(seed) {
    final state = character.state(_state);
    idleTracks = TrackController(
      vsync: vsync,
      velocityTracking: const VelocityTracking.off(),
      debugLabel: 'idles',
    )..addListener(notifyListeners);
    animator =
        DotAnimator<DotScene>(
            vsync: vsync,
            initial: state.animation.frames.first.state,
          )
          ..onSequenceEnd = _onSequenceEnd
          ..addListener(notifyListeners);
    _playState();
  }

  final math.Random _random;

  /// Plays every idle, each as a few tracks.
  late final TrackController idleTracks;

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
        if (_disposed || runner.weight > 0) return;
        _idles.remove(runner);
        runner.stop();
      });
    }
    for (final idle in idles) {
      if (_idles.any((runner) => runner.idle == idle)) continue;
      final runner = _IdleRunner.of(idle, idleTracks, _random, this);
      _idles.add(runner);
      runner
        ..start(_lookTarget)
        ..fadeTo(1);
    }
  }

  @override
  void modifyLayers(Float32List layers, int count) {
    for (final runner in _idles) {
      final weight = runner.weight;
      if (weight <= 0) continue;
      runner.apply(layers, count, weight);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _idles.clear();
    idleTracks.dispose();
    animator.dispose();
    super.dispose();
  }
}

const _stride = DotScene.stride;

/// A random duration around [interval], between half and one and a half
/// of it.
Duration _around(math.Random random, Duration interval) =>
    interval * (0.5 + random.nextDouble());

/// Keeps one [DotIdle] going with tracks of a shared [TrackController].
abstract class _IdleRunner {
  _IdleRunner(this.idle, this.tracks, this.owner);

  factory _IdleRunner.of(
    DotIdle idle,
    TrackController tracks,
    math.Random random,
    DotCharacterController owner,
  ) => switch (idle) {
    BreatheIdle() => _WaveRunner(idle, tracks, owner, idle.period),
    BobIdle() => _WaveRunner(idle, tracks, owner, idle.period),
    BlinkIdle() => _BlinkRunner(idle, tracks, owner, random),
    LookAroundIdle() => _LookRunner(idle, tracks, owner, random),
  };

  static const _fade = CupertinoMotion(duration: Duration(milliseconds: 450));

  final DotIdle idle;
  final TrackController tracks;
  final DotCharacterController owner;

  /// How much the idle shows, faded in and out with its states.
  final _weight = Track<double>(MotionConverter.single, initial: 0);

  /// The tracks that move the idle.
  List<Track> get moving;

  double get weight => tracks.value(_weight);

  /// Whether chained steps should go on.
  bool get alive => !owner._disposed && owner._idles.contains(this);

  MotionFuture fadeTo(double target) => tracks.animate([
    _weight([TrackStep.to(target, motion: _fade)]),
  ]);

  void start(Offset? lookTarget);

  void apply(Float32List layers, int count, double weight);

  void stop() => tracks.stop(tracks: [_weight, ...moving], canceled: true);
}

/// Swings between -1 and 1 like a sine for [BreatheIdle] and [BobIdle].
class _WaveRunner extends _IdleRunner {
  _WaveRunner(super.idle, super.tracks, super.owner, this.period);

  final Duration period;
  final _wave = Track<double>(MotionConverter.single, initial: 0);

  @override
  List<Track> get moving => [_wave];

  @override
  void start(Offset? lookTarget) {
    // A quarter swing up from the middle, then half swings down and back
    // up, ending where the loop starts.
    final half = CurvedMotion(period ~/ 2, Curves.easeInOutSine);
    tracks
        .animate([
          _wave([
            TrackStep.to(
              1,
              motion: CurvedMotion(period ~/ 4, Curves.easeOutSine),
            ),
          ]),
        ])
        .then((_) {
          if (!alive) return;
          tracks.animate([
            _wave([
              TrackStep.to(-1, motion: half),
              TrackStep.to(1, motion: half),
            ]),
          ], loop: LoopMode.seamless);
        });
  }

  @override
  void apply(Float32List layers, int count, double weight) {
    final swing = tracks.value(_wave) * weight;
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
}

/// Shuts a layer now and then, sometimes twice.
class _BlinkRunner extends _IdleRunner {
  _BlinkRunner(super.idle, super.tracks, super.owner, this.random);

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
  final _shut = Track<double>(MotionConverter.single, initial: 0);

  BlinkIdle get _idle => idle as BlinkIdle;

  @override
  List<Track> get moving => [_shut];

  @override
  void start(Offset? lookTarget) => _next();

  List<TrackStep<double>> get _blink => const [
    TrackStep.to(1, motion: _close),
    TrackStep.to(0, motion: _open),
  ];

  void _next() {
    if (!alive) return;
    final twice = random.nextDouble() < 0.2;
    tracks
        .animate([
          _shut([
            TrackStep.hold(_around(random, _idle.interval)),
            ..._blink,
            if (twice) ...[
              const TrackStep.hold(Duration(milliseconds: 80)),
              ..._blink,
            ],
          ]),
        ])
        .then((_) => _next());
  }

  void blinkNow() => tracks.animate([_shut(_blink)]).then((_) => _next());

  @override
  void apply(Float32List layers, int count, double weight) {
    final layer = _idle.layer;
    if (layer >= count) return;
    final shut = tracks.value(_shut);
    layers[layer * _stride + 4] *= 1 - (1 - _idle.closed) * shut * weight;
  }
}

/// Moves layers to a new spot now and then, or where they are told to look.
class _LookRunner extends _IdleRunner {
  _LookRunner(super.idle, super.tracks, super.owner, this.random);

  final math.Random random;
  final _gaze = Track<Offset>(MotionConverter.offset, initial: Offset.zero);

  LookAroundIdle get _idle => idle as LookAroundIdle;

  @override
  List<Track> get moving => [_gaze];

  @override
  void start(Offset? lookTarget) => lookAt(lookTarget);

  void lookAt(Offset? direction) {
    if (direction == null) {
      _wander();
      return;
    }
    final range = _idle.range;
    tracks.animate([
      _gaze([
        TrackStep.to(
          Offset(
            direction.dx.clamp(-1, 1) * range.dx,
            direction.dy.clamp(-1, 1) * range.dy,
          ),
          motion: _idle.motion,
        ),
      ]),
    ]);
  }

  void _wander() {
    if (!alive) return;
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
    tracks
        .animate([
          _gaze([
            TrackStep.hold(_around(random, _idle.interval)),
            TrackStep.to(spot, motion: _idle.motion),
          ]),
        ])
        .then((_) => _wander());
  }

  @override
  void apply(Float32List layers, int count, double weight) {
    final offset = tracks.value(_gaze) * weight;
    for (final layer in _idle.layers) {
      if (layer >= count) continue;
      layers[layer * _stride + 2] += offset.dx;
      layers[layer * _stride + 3] += offset.dy;
    }
  }
}
