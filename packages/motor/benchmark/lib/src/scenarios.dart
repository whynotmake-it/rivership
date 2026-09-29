import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// Value counts for the 1D scaling scenarios.
const valueCounts = [1, 10, 50, 250, 1000];

// Steady-state motions stay in flight for the whole measured window (under
// 6 s at the default config); start and retarget use realistic ones.
const _steadyDuration = Duration(seconds: 60);
const _curve = Curves.easeInOut;
const _steadyCurve = CurvedMotion(_steadyDuration, _curve);
const _shortCurve = CurvedMotion(Duration(milliseconds: 300), _curve);
const _steadySpring = CupertinoMotion(
  duration: Duration(seconds: 20),
  bounce: 0.3,
);
const _shortSpring = CupertinoMotion.bouncy();

/// Every scenario, in report order.
List<BenchScenario> allScenarios() => [
      for (final n in valueCounts)
        BenchScenario(
          id: 'curve_1d_x$n',
          group: 'Curve 1D',
          values: n,
          motorSetup: '1 TrackController, $n track${n == 1 ? '' : 's'}',
          flutterSetup: '$n AC + CurvedAnimation',
          motor: (vsync, {required steady}) => _MotorSide<double>(
            vsync,
            count: n,
            converter: const SingleMotionConverter(),
            motion: steady ? _steadyCurve : _shortCurve,
            low: 0,
            high: 1,
            fold: _foldDouble,
          ),
          flutter: (vsync, {required steady}) =>
              _CurveControllers(vsync, count: n, steady: steady),
        ),
      for (final n in valueCounts)
        BenchScenario(
          id: 'spring_1d_x$n',
          group: 'Spring 1D',
          values: n,
          motorSetup: '1 TrackController, $n track${n == 1 ? '' : 's'}',
          flutterSetup: '$n AC + SpringSimulation',
          retargets: true,
          motor: (vsync, {required steady}) => _MotorSide<double>(
            vsync,
            count: n,
            converter: const SingleMotionConverter(),
            motion: steady ? _steadySpring : _shortSpring,
            low: 0,
            high: 1,
            fold: _foldDouble,
          ),
          flutter: (vsync, {required steady}) => _SpringControllers<double>(
            vsync,
            count: n,
            steady: steady,
            low: const [0],
            high: const [1],
            compose: (v) => v[0],
            fold: _foldDouble,
          ),
        ),
      ..._multiDimensional<Offset>(
        name: 'Offset',
        converter: const OffsetMotionConverter(),
        low: Offset.zero,
        high: const Offset(120, 80),
        tween: Tween<Offset>.new,
        tweenName: 'Tween<Offset>',
        compose: (v) => Offset(v[0], v[1]),
        fold: (o) => o.dx + o.dy,
      ),
      ..._multiDimensional<Rect>(
        name: 'Rect',
        converter: const RectMotionConverter(),
        low: const Rect.fromLTRB(0, 0, 10, 10),
        high: const Rect.fromLTRB(40, 60, 240, 180),
        tween: RectTween.new,
        tweenName: 'RectTween',
        compose: (v) => Rect.fromLTRB(v[0], v[1], v[2], v[3]),
        fold: (r) => r.left + r.top + r.right + r.bottom,
      ),
      ..._multiDimensional<Color>(
        name: 'Color',
        converter: const ColorRgbMotionConverter(),
        low: const Color(0xFF000000),
        high: const Color(0x80FFC020),
        tween: ColorTween.new,
        tweenName: 'ColorTween',
        compose: (v) => Color.from(
          red: v[0].clamp(0, 1),
          green: v[1].clamp(0, 1),
          blue: v[2].clamp(0, 1),
          alpha: v[3].clamp(0, 1),
        ),
        fold: (c) => c.r + c.g + c.b + c.a,
      ),
      for (final tracked in [true, false]) ...[
        for (final n in _gestureCounts)
          _gesture<double>(
            tracked: tracked,
            name: '1D',
            count: n,
            converter: const SingleMotionConverter(),
            valueAt: (p) => p,
            dims: 1,
            fold: _foldDouble,
          ),
        for (final n in _gestureCounts)
          _gesture<Offset>(
            tracked: tracked,
            name: 'Offset',
            count: n,
            converter: const OffsetMotionConverter(),
            valueAt: (p) => Offset(p, p / 2),
            dims: 2,
            fold: (o) => o.dx + o.dy,
          ),
      ],
    ];

const _gestureCounts = [1, 250];

/// Values following a drag via `set` every frame, then flinging with the
/// tracked velocity, against `AnimationController.value =` plus one
/// [VelocityTracker] per value (or no tracker, when [tracked] is false).
///
/// A value at pointer position `p` is `valueAt(p)`; the Flutter side's
/// dimension `d` of it is `p` for `d == 0` and `p / 2` otherwise.
BenchScenario _gesture<T extends Object>({
  required bool tracked,
  required String name,
  required int count,
  required MotionConverter<T> converter,
  required T Function(double position) valueAt,
  required int dims,
  required double Function(T value) fold,
}) {
  final tracking = tracked ? 'on' : 'off';
  return BenchScenario(
    id: 'drag_${tracked ? 'tracked' : 'untracked'}_${name.toLowerCase()}_x$count',
    group: 'Drag $name, tracking $tracking',
    values: count,
    gesture: true,
    motorSetup: '1 TrackController, $count track${count == 1 ? '' : 's'}, '
        'velocityTracking $tracking',
    flutterSetup: '${count * dims} AC'
        '${tracked ? ' + $count VelocityTracker' : ''}',
    motor: (vsync, {required steady}) => _MotorGestureSide<T>(
      vsync,
      count: count,
      tracked: tracked,
      converter: converter,
      valueAt: valueAt,
      fold: fold,
    ),
    flutter: (vsync, {required steady}) => _FlutterGestureSide(
      vsync,
      count: count,
      tracked: tracked,
      dims: dims,
    ),
  );
}

/// [count] tracks on one [TrackController], set from a drag. Track `k`
/// follows the pointer offset by `k`.
class _MotorGestureSide<T extends Object> extends GestureSide {
  _MotorGestureSide(
    TickerProvider vsync, {
    required int count,
    required bool tracked,
    required MotionConverter<T> converter,
    required this.valueAt,
    required this.fold,
  })  : _tracks = List.generate(
          count,
          (_) => Track<T>(converter, motion: _shortSpring),
        ),
        _controller = TrackController(
          vsync: vsync,
          velocityTracking: tracked
              ? const VelocityTracking.on()
              : const VelocityTracking.off(),
        );

  final T Function(double position) valueAt;
  final double Function(T value) fold;
  final List<Track<T>> _tracks;
  final TrackController _controller;

  @override
  void sample(double position, Duration time) {
    _controller.set([
      for (var k = 0; k < _tracks.length; k++)
        _tracks[k].value(valueAt(position + k)),
    ]);
  }

  @override
  void fling(double target) {
    _controller.animate([
      for (var k = 0; k < _tracks.length; k++)
        _tracks[k]([TrackStep.to(valueAt(target + k))]),
    ]);
  }

  @override
  double read() {
    var sum = 0.0;
    for (final track in _tracks) {
      sum += fold(_controller.value(track));
    }
    return sum;
  }

  @override
  bool get isAnimating => _controller.isAnimating;

  @override
  void stop() => _controller.stop();

  @override
  void dispose() => _controller.dispose();
}

/// [count] values of [dims] unbounded `AnimationController`s each, set from
/// a drag, with one [VelocityTracker] per value when tracked.
class _FlutterGestureSide extends GestureSide {
  _FlutterGestureSide(
    TickerProvider vsync, {
    required int count,
    required bool tracked,
    required int dims,
  })  : _spring = _shortSpring.description,
        _values = List.generate(
          count,
          (_) => List.generate(
            dims,
            (_) => AnimationController.unbounded(vsync: vsync),
            growable: false,
          ),
          growable: false,
        ),
        _trackers = tracked
            ? List.generate(
                count,
                (_) => VelocityTracker.withKind(PointerDeviceKind.touch),
                growable: false,
              )
            : null;

  final SpringDescription _spring;
  final List<List<AnimationController>> _values;
  final List<VelocityTracker>? _trackers;

  static double _dimension(int d, double position) =>
      d == 0 ? position : position / 2;

  @override
  void sample(double position, Duration time) {
    for (var k = 0; k < _values.length; k++) {
      final dims = _values[k];
      final p = position + k;
      for (var d = 0; d < dims.length; d++) {
        dims[d].value = _dimension(d, p);
      }
      _trackers?[k].addPosition(
        time,
        Offset(dims[0].value, dims.length > 1 ? dims[1].value : 0),
      );
    }
  }

  @override
  void fling(double target) {
    for (var k = 0; k < _values.length; k++) {
      final dims = _values[k];
      final velocity =
          _trackers?[k].getVelocity().pixelsPerSecond ?? Offset.zero;
      for (var d = 0; d < dims.length; d++) {
        final c = dims[d];
        c.animateWith(
          SpringSimulation(
            _spring,
            c.value,
            _dimension(d, target + k),
            d == 0 ? velocity.dx : velocity.dy,
            snapToEnd: true,
          ),
        );
      }
    }
  }

  @override
  double read() {
    var sum = 0.0;
    for (final dims in _values) {
      for (final c in dims) {
        sum += c.value;
      }
    }
    return sum;
  }

  @override
  bool get isAnimating => _values.any((dims) => dims.any((c) => c.isAnimating));

  @override
  void stop() {
    for (final dims in _values) {
      for (final c in dims) {
        c.stop();
      }
    }
  }

  @override
  void dispose() {
    for (final dims in _values) {
      for (final c in dims) {
        c.dispose();
      }
    }
  }
}

/// Filters [allScenarios] by comma-separated ids or `_`-separated id
/// prefixes: `spring` and `spring_1d` match `spring_1d_x10`, `spring_1d_x1`
/// matches only itself.
List<BenchScenario> scenariosMatching(String? filter) {
  final all = allScenarios();
  final prefixes = [
    for (final part in (filter ?? '').split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
  if (prefixes.isEmpty) return all;
  return [
    for (final scenario in all)
      if (prefixes.any(
        (p) => scenario.id == p || scenario.id.startsWith('${p}_'),
      ))
        scenario,
  ];
}

double _foldDouble(double v) => v;

/// One multi-dimensional track against its Flutter equivalents.
///
/// A curve shares one timing across dimensions, so its honest equivalent is
/// one controller driving a tween. A spring that must be retargetable while
/// keeping each dimension's velocity needs one simulation per dimension, so
/// its equivalent is one `AnimationController` per dimension.
List<BenchScenario> _multiDimensional<T extends Object>({
  required String name,
  required MotionConverter<T> converter,
  required T low,
  required T high,
  required Tween<T?> Function({T? begin, T? end}) tween,
  required String tweenName,
  required T Function(List<double> values) compose,
  required double Function(T value) fold,
}) {
  final dims = converter.normalize(low).length;
  return [
    BenchScenario(
      id: 'curve_${name.toLowerCase()}',
      group: 'Curve $name (${dims}D)',
      values: 1,
      motorSetup: '1 track',
      flutterSetup: '1 AC + CurvedAnimation + $tweenName',
      motor: (vsync, {required steady}) => _MotorSide<T>(
        vsync,
        count: 1,
        converter: converter,
        motion: steady ? _steadyCurve : _shortCurve,
        low: low,
        high: high,
        fold: fold,
      ),
      flutter: (vsync, {required steady}) => _TweenController<T>(
        vsync,
        steady: steady,
        tween: tween(begin: low, end: high),
        low: low,
        high: high,
        fold: fold,
      ),
    ),
    BenchScenario(
      id: 'spring_${name.toLowerCase()}',
      group: 'Spring $name (${dims}D)',
      values: 1,
      motorSetup: '1 track',
      flutterSetup: '$dims AC (one per dimension)',
      retargets: true,
      motor: (vsync, {required steady}) => _MotorSide<T>(
        vsync,
        count: 1,
        converter: converter,
        motion: steady ? _steadySpring : _shortSpring,
        low: low,
        high: high,
        fold: fold,
      ),
      flutter: (vsync, {required steady}) => _SpringControllers<T>(
        vsync,
        count: 1,
        steady: steady,
        low: converter.normalize(low),
        high: converter.normalize(high),
        compose: compose,
        fold: fold,
      ),
    ),
  ];
}

/// [count] tracks of type [T] on one [TrackController].
class _MotorSide<T extends Object> implements BenchSide {
  _MotorSide(
    TickerProvider vsync, {
    required int count,
    required MotionConverter<T> converter,
    required Motion motion,
    required this.low,
    required this.high,
    required this.fold,
  })  : _tracks = List.generate(
          count,
          (_) => Track<T>(converter, initial: low, motion: motion),
        ),
        _controller = TrackController(
          vsync: vsync,
          velocityTracking: const VelocityTracking.off(),
        );

  final T low;
  final T high;
  final double Function(T value) fold;
  final List<Track<T>> _tracks;
  final TrackController _controller;

  @override
  void start({required bool forward}) {
    final target = forward ? high : low;
    _controller.animate([
      for (final track in _tracks) track([TrackStep.to(target)]),
    ]);
  }

  @override
  double read() {
    var sum = 0.0;
    for (final track in _tracks) {
      sum += fold(_controller.value(track));
    }
    return sum;
  }

  @override
  bool get isAnimating => _controller.isAnimating;

  @override
  void stop() => _controller.stop();

  @override
  void dispose() => _controller.dispose();
}

/// [count] `AnimationController`s, each read through a [CurvedAnimation].
class _CurveControllers implements BenchSide {
  _CurveControllers(
    TickerProvider vsync, {
    required int count,
    required bool steady,
  }) : _controllers = List.generate(
          count,
          (_) => AnimationController(
            vsync: vsync,
            duration: steady ? _steadyDuration : _shortCurve.duration,
          ),
        ) {
    _curved = [
      for (final c in _controllers) CurvedAnimation(parent: c, curve: _curve),
    ];
  }

  final List<AnimationController> _controllers;
  late final List<CurvedAnimation> _curved;

  @override
  void start({required bool forward}) {
    for (final c in _controllers) {
      forward ? c.forward() : c.reverse();
    }
  }

  @override
  double read() {
    var sum = 0.0;
    for (final a in _curved) {
      sum += a.value;
    }
    return sum;
  }

  @override
  bool get isAnimating => _controllers.any((c) => c.isAnimating);

  @override
  void stop() {
    for (final c in _controllers) {
      c.stop();
    }
  }

  @override
  void dispose() {
    for (final a in _curved) {
      a.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
  }
}

/// One `AnimationController` driving a [CurvedAnimation] and a tween.
///
/// Starting re-aims the tween from the current value, as a retargetable
/// tween-based widget would.
class _TweenController<T extends Object> implements BenchSide {
  _TweenController(
    TickerProvider vsync, {
    required bool steady,
    required Tween<T?> tween,
    required this.low,
    required this.high,
    required this.fold,
  })  : _tween = tween,
        _controller = AnimationController(
          vsync: vsync,
          duration: steady ? _steadyDuration : _shortCurve.duration,
        ) {
    _curved = CurvedAnimation(parent: _controller, curve: _curve);
    _animation = _tween.animate(_curved);
  }

  final T low;
  final T high;
  final double Function(T value) fold;
  final Tween<T?> _tween;
  final AnimationController _controller;
  late final CurvedAnimation _curved;
  late final Animation<T?> _animation;

  @override
  void start({required bool forward}) {
    _tween
      ..begin = _animation.value
      ..end = forward ? high : low;
    _controller.forward(from: 0);
  }

  @override
  double read() => fold(_animation.value!);

  @override
  bool get isAnimating => _controller.isAnimating;

  @override
  void stop() => _controller.stop();

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
  }
}

/// [count] values of [T], each driven by one unbounded
/// `AnimationController` per dimension running a [SpringSimulation].
class _SpringControllers<T> implements BenchSide {
  _SpringControllers(
    TickerProvider vsync, {
    required int count,
    required bool steady,
    required this.low,
    required this.high,
    required this.compose,
    required this.fold,
  })  : _spring = (steady ? _steadySpring : _shortSpring).description,
        _values = List.generate(
          count,
          (_) => List.generate(
            low.length,
            (d) => AnimationController.unbounded(vsync: vsync, value: low[d]),
            growable: false,
          ),
          growable: false,
        );

  final List<double> low;
  final List<double> high;
  final T Function(List<double> values) compose;
  final double Function(T value) fold;
  final SpringDescription _spring;
  final List<List<AnimationController>> _values;

  // Reused per read, as a converter's buffer would be.
  late final List<double> _scratch = List.filled(low.length, 0);

  @override
  void start({required bool forward}) {
    final target = forward ? high : low;
    for (final dims in _values) {
      for (var d = 0; d < dims.length; d++) {
        final c = dims[d];
        c.animateWith(
          SpringSimulation(
            _spring,
            c.value,
            target[d],
            c.velocity,
            snapToEnd: true,
          ),
        );
      }
    }
  }

  @override
  double read() {
    var sum = 0.0;
    for (final dims in _values) {
      for (var d = 0; d < dims.length; d++) {
        _scratch[d] = dims[d].value;
      }
      sum += fold(compose(_scratch));
    }
    return sum;
  }

  @override
  bool get isAnimating => _values.any((dims) => dims.any((c) => c.isAnimating));

  @override
  void stop() {
    for (final dims in _values) {
      for (final c in dims) {
        c.stop();
      }
    }
  }

  @override
  void dispose() {
    for (final dims in _values) {
      for (final c in dims) {
        c.dispose();
      }
    }
  }
}
