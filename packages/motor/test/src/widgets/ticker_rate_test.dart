import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:fixed_ticker/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

const _motion = Motion.linear(Duration(seconds: 1));
const _frame = Duration(milliseconds: 16);
const _childKey = Key('child');
final _track = Track<double>(const SingleMotionConverter(), initial: 0);

enum _Phase { a, b }

/// Builds a widget that animates for about a second and calls `onBuild`
/// each time its builder runs.
typedef _Primitive = Widget Function({
  required VoidCallback onBuild,
  TickerRate? tickerRate,
});

final _primitives = <String, _Primitive>{
  'MotionBuilder': ({required onBuild, tickerRate}) => SingleMotionBuilder(
        from: 0,
        value: 1,
        motion: _motion,
        tickerRate: tickerRate,
        builder: (context, value, child) {
          onBuild();
          return const SizedBox();
        },
      ),
  'VelocityMotionBuilder': ({required onBuild, tickerRate}) =>
      SingleVelocityMotionBuilder(
        from: 0,
        value: 1,
        motion: _motion,
        tickerRate: tickerRate,
        builder: (context, value, velocity, child) {
          onBuild();
          return const SizedBox();
        },
      ),
  'MotionPadding': ({required onBuild, tickerRate}) => _PaddingAnimation(
        onBuild: onBuild,
        tickerRate: tickerRate,
      ),
  'TrackBuilder': ({required onBuild, tickerRate}) => TrackBuilder(
        animations: [_track.to(1, motion: _motion)],
        tickerRate: tickerRate,
        builder: (context, value, child) {
          onBuild();
          return const SizedBox();
        },
      ),
  'PhaseTrackBuilder': ({required onBuild, tickerRate}) =>
      PhaseTrackBuilder<_Phase>(
        timeline: TrackPhaseTimeline({
          _Phase.a: [_track.to(0, motion: _motion)],
          _Phase.b: [_track.to(1, motion: _motion)],
        }),
        playing: true,
        tickerRate: tickerRate,
        builder: (context, value, phase, child) {
          onBuild();
          return const SizedBox();
        },
      ),
  'SequenceMotionBuilder': ({required onBuild, tickerRate}) =>
      // ignore: deprecated_member_use_from_same_package
      SequenceMotionBuilder<_Phase, double>(
        sequence: const MotionSequence.states(
          {_Phase.a: 0, _Phase.b: 1},
          motion: _motion,
        ),
        converter: const SingleMotionConverter(),
        tickerRate: tickerRate,
        builder: (context, value, phase, child) {
          onBuild();
          return const SizedBox();
        },
      ),
};

void main() {
  /// Counts builder calls over half a second of 16 ms frames.
  Future<int> countBuilds(
    WidgetTester tester,
    _Primitive primitive, {
    TickerRate? tickerRate,
    TickerRate? scope,
  }) async {
    var builds = 0;
    final child = primitive(onBuild: () => builds++, tickerRate: tickerRate);
    await tester.pumpWidget(
      scope == null ? child : TickerRateScope(rate: scope, child: child),
    );
    await tester.pump(_frame);
    builds = 0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(_frame);
    }
    await tester.pumpWidget(const SizedBox());
    return builds;
  }

  for (final MapEntry(key: name, value: primitive) in _primitives.entries) {
    group(name, () {
      testWidgets('ticks every frame by default', (tester) async {
        expect(await countBuilds(tester, primitive), 30);
        expect(FixedTicker.hasActiveTimers, isFalse);
      });

      testWidgets('ticks at tickerRate', (tester) async {
        final builds = await countBuilds(
          tester,
          primitive,
          tickerRate: TickerRate.fps(10),
        );
        expect(builds, inInclusiveRange(4, 6));
      });

      testWidgets('ticks at the TickerRateScope rate', (tester) async {
        final builds = await countBuilds(
          tester,
          primitive,
          scope: TickerRate.fps(10),
        );
        expect(builds, inInclusiveRange(4, 6));
      });

      testWidgets('tickerRate overrides the scope', (tester) async {
        expect(
          await countBuilds(
            tester,
            primitive,
            tickerRate: const TickerRate.vsync(),
            scope: TickerRate.fps(10),
          ),
          30,
        );
        expect(
          await countBuilds(
            tester,
            primitive,
            tickerRate: TickerRate.fps(10),
            scope: const TickerRate.vsync(),
          ),
          inInclusiveRange(4, 6),
        );
      });
    });
  }

  group('MotionDraggable', () {
    Future<bool> returnsOnFixedTicker(
      WidgetTester tester, {
      TickerRate? tickerRate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: MotionDraggable<String>(
              data: 'data',
              motion: const CupertinoMotion.smooth(),
              tickerRate: tickerRate,
              child: const ColoredBox(
                key: _childKey,
                color: Color(0xFF000000),
                child: SizedBox.square(dimension: 10),
              ),
            ),
          ),
        ),
      );
      final gesture =
          await tester.startGesture(tester.getCenter(find.byKey(_childKey)));
      await gesture.moveBy(const Offset(50, 50));
      await tester.pump();
      await gesture.up();
      await tester.pump(_frame);
      await tester.pump(_frame);
      final fixed = FixedTicker.hasActiveTimers;
      expect(fixed || tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettleFixedTickers();
      return fixed;
    }

    testWidgets('returns on a vsync ticker by default', (tester) async {
      expect(await returnsOnFixedTicker(tester), isFalse);
    });

    testWidgets('returns at tickerRate', (tester) async {
      expect(
        await returnsOnFixedTicker(tester, tickerRate: TickerRate.fps(10)),
        isTrue,
      );
    });
  });

  testWidgets('switching rates keeps the animation running', (tester) async {
    final values = <double>[];
    Widget build(TickerRate? rate) => SingleMotionBuilder(
          from: 0,
          value: 1,
          motion: _motion,
          tickerRate: rate,
          builder: (context, value, child) {
            values.add(value);
            return const SizedBox();
          },
        );

    await tester.pumpWidget(build(null));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(build(TickerRate.fps(10)));
    expect(FixedTicker.hasActiveTimers, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(build(TickerRate.fps(20)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(build(null));
    expect(FixedTicker.hasActiveTimers, isFalse);
    await tester.pumpAndSettle();

    expect(values, orderedEquals([...values]..sort()));
    expect(values.last, 1);
  });

  testWidgets('TickerMode mutes fixed-rate tickers', (tester) async {
    var builds = 0;
    Widget build({required bool enabled}) => TickerMode(
          enabled: enabled,
          child: SingleMotionBuilder(
            from: 0,
            value: 1,
            motion: _motion,
            tickerRate: TickerRate.fps(10),
            builder: (context, value, child) {
              builds++;
              return const SizedBox();
            },
          ),
        );

    await tester.pumpWidget(build(enabled: false));
    builds = 0;
    await tester.pump(const Duration(milliseconds: 300));
    expect(builds, 0);

    await tester.pumpWidget(build(enabled: true));
    builds = 0;
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(builds, isPositive);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live values at a fixed rate match scrubbing and inspection', (
    tester,
  ) async {
    final observer = _Observer();
    final subscription = MotorInspectionRegistry.attach(observer);
    addTearDown(subscription.dispose);

    await tester.pumpWidget(
      TickerRateScope(
        rate: TickerRate.fps(10),
        child: TrackBuilder(
          animations: [_track.to(100, motion: _motion)],
          builder: (context, value, child) => const SizedBox(),
        ),
      ),
    );
    for (var i = 0; i < 25; i++) {
      await tester.pump(_frame);
    }

    final controller = observer.controllers.single;
    final snapshot = controller.inspectPlayback();
    expect(snapshot.tracks.single.track, _track);
    final position = snapshot.position;
    expect(position, greaterThan(Duration.zero));
    final live = controller.value<double>(_track);
    expect(live, closeTo(position.inMicroseconds / 10000, 1e-9));

    controller
      ..pause()
      ..scrubTo(Duration.zero)
      ..scrubTo(position);
    expect(controller.value<double>(_track), live);

    controller.resume();
    await tester.pumpAndSettleFixedTickers();
    expect(controller.value<double>(_track), 100);
    await tester.pumpWidget(const SizedBox());
  });
}

class _PaddingAnimation extends StatefulWidget {
  const _PaddingAnimation({required this.onBuild, this.tickerRate});

  final VoidCallback onBuild;
  final TickerRate? tickerRate;

  @override
  State<_PaddingAnimation> createState() => _PaddingAnimationState();
}

class _PaddingAnimationState extends State<_PaddingAnimation> {
  var _padding = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _padding = const EdgeInsets.all(100));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MotionPadding(
      motion: _motion,
      padding: _padding,
      tickerRate: widget.tickerRate,
      child: _BuildCounter(onBuild: widget.onBuild),
    );
  }
}

class _BuildCounter extends SingleChildRenderObjectWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBuildCounter(onBuild);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBuildCounter renderObject,
  ) =>
      renderObject.onLayout = onBuild;
}

class _RenderBuildCounter extends RenderProxyBox {
  _RenderBuildCounter(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}

class _Observer implements MotorInspectionObserver {
  final controllers = <TrackController>[];

  @override
  void didRegisterController(TrackController controller) =>
      controllers.add(controller);

  @override
  void didUnregisterController(TrackController controller) =>
      controllers.remove(controller);
}
