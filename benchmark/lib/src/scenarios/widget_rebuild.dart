import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// Widget rebuild path: looping [TrackBuilder] vs [AnimatedBuilder].
class WidgetRebuildScenario implements BenchScenario {
  const WidgetRebuildScenario();

  static const _duration = Duration(milliseconds: 800);

  @override
  String get id => 'widget_rebuild';

  @override
  String get name => 'Widget rebuild';

  @override
  String get description =>
      'TrackBuilder vs AnimatedBuilder rebuilding Transform + child.';

  @override
  Map<String, Object?> get params => const {'widget': true};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) {
    return runPaired(
      tester: tester,
      config: config,
      scenario: this,
      motorOnce: () => _runMotor(tester, config),
      flutterOnce: () => _runFlutter(tester, config),
    );
  }

  Future<List<SideSample>> _runMotor(
    WidgetTester tester,
    BenchConfig config,
  ) async {
    var sink = 0.0;
    final tickSw = Stopwatch();
    var measuringTicks = false;
    final opacity = Track(
      const SingleMotionConverter(),
      initial: 0.0,
      motion: const CurvedMotion(_duration, Curves.easeInOut),
      debugLabel: 'opacity',
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TrackBuilder(
          animations: [
            opacity([
              const TrackStep.to(1.0),
              const TrackStep.to(0.0),
            ]),
          ],
          loop: LoopMode.loop,
          builder: (context, value, child) {
            final v = value(opacity);
            if (measuringTicks) {
              tickSw.start();
              sink += v;
              tickSw.stop();
            } else {
              sink += v;
            }
            return Transform.translate(
              offset: Offset(v * 100, 0),
              child: child,
            );
          },
          child: const _Leaf(),
        ),
      ),
    );

    for (var i = 0; i < config.warmupFrames; i++) {
      await tester.pump(config.frameStep);
    }

    tickSw
      ..stop()
      ..reset();
    measuringTicks = config.measuresTick;
    final pumpSw = Stopwatch();
    if (config.measuresPump) pumpSw.start();

    for (var i = 0; i < config.measuredFrames; i++) {
      await tester.pump(config.frameStep);
    }

    if (config.measuresPump) pumpSw.stop();
    measuringTicks = false;
    expect(sink.isFinite, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    return [
      if (config.measuresTick)
        SideSample(
          side: 'motor',
          layer: BenchMode.tick,
          elapsed: tickSw.elapsed,
          frames: config.measuredFrames,
          sink: sink,
        ),
      if (config.measuresPump)
        SideSample(
          side: 'motor',
          layer: BenchMode.pump,
          elapsed: pumpSw.elapsed,
          frames: config.measuredFrames,
          sink: sink,
        ),
    ];
  }

  Future<List<SideSample>> _runFlutter(
    WidgetTester tester,
    BenchConfig config,
  ) async {
    var sink = 0.0;
    final tickSw = Stopwatch();
    var measuringTicks = false;
    late final AnimationController controller;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _FlutterAnimHost(
          duration: _duration,
          onTick: (value) {
            if (measuringTicks) {
              tickSw.start();
              sink += value;
              tickSw.stop();
            } else {
              sink += value;
            }
          },
          onCreated: (c) => controller = c,
          child: const _Leaf(),
        ),
      ),
    );
    controller.repeat(reverse: true);

    for (var i = 0; i < config.warmupFrames; i++) {
      await tester.pump(config.frameStep);
    }

    tickSw
      ..stop()
      ..reset();
    measuringTicks = config.measuresTick;
    final pumpSw = Stopwatch();
    if (config.measuresPump) pumpSw.start();

    for (var i = 0; i < config.measuredFrames; i++) {
      await tester.pump(config.frameStep);
    }

    if (config.measuresPump) pumpSw.stop();
    measuringTicks = false;
    expect(sink.isFinite, isTrue);
    expect(controller.isAnimating, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    return [
      if (config.measuresTick)
        SideSample(
          side: 'flutter',
          layer: BenchMode.tick,
          elapsed: tickSw.elapsed,
          frames: config.measuredFrames,
          sink: sink,
        ),
      if (config.measuresPump)
        SideSample(
          side: 'flutter',
          layer: BenchMode.pump,
          elapsed: pumpSw.elapsed,
          frames: config.measuredFrames,
          sink: sink,
        ),
    ];
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: ColoredBox(color: Color(0xFF2244AA)),
    );
  }
}

class _FlutterAnimHost extends StatefulWidget {
  const _FlutterAnimHost({
    required this.duration,
    required this.onTick,
    required this.onCreated,
    required this.child,
  });

  final Duration duration;
  final ValueChanged<double> onTick;
  final ValueChanged<AnimationController> onCreated;
  final Widget child;

  @override
  State<_FlutterAnimHost> createState() => _FlutterAnimHostState();
}

class _FlutterAnimHostState extends State<_FlutterAnimHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    widget.onCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        widget.onTick(_animation.value);
        return Transform.translate(
          offset: Offset(_animation.value * 100, 0),
          child: child,
        );
      },
    );
  }
}
