import 'dart:async';

import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:fixed_ticker/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimationController lifecycle', () {
    testWidgets('forward animation: value progresses from 0.0 to 1.0', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      expect(controller.value, 0.0);

      await tester.pump(const Duration(milliseconds: 165));
      expect(controller.value, closeTo(0.5, 0.05));

      await tester.pumpAndSettleFixedTickers();
      expect(controller.value, 1.0);
    });

    testWidgets('reverse animation: value progresses from 1.0 to 0.0', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) {
            controller = c
              ..value = 1.0
              ..reverse();
          },
          duration: const Duration(milliseconds: 330),
        ),
      );

      expect(controller.value, 1.0);

      await tester.pump(const Duration(milliseconds: 165));
      expect(controller.value, equals(0.5));

      await tester.pumpAndSettleFixedTickers();
      expect(controller.value, 0.0);
    });

    testWidgets('repeat(): animation cycles continuously', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..repeat(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      // After one full cycle
      await tester.pump(const Duration(milliseconds: 330));
      expect(controller.value, equals(0.0));

      // Mid second cycle
      await tester.pump(const Duration(milliseconds: 165));
      expect(controller.value, equals(0.5));

      controller.stop();
    });

    testWidgets('animateTo(): reaches intermediate target and completes', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..animateTo(0.5),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pumpAndSettleFixedTickers();
      expect(controller.value, 0.5);
    });

    testWidgets('stop() mid-animation: freezes at current value', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 165));
      final frozenValue = controller.value;
      controller.stop();

      await tester.pump(const Duration(milliseconds: 330));
      expect(controller.value, frozenValue);
    });
  });

  group('animation value accuracy', () {
    testWidgets('at 50% of duration, value is approximately 0.5 (linear)', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 165));
      expect(controller.value, closeTo(0.5, 0.05));
    });

    testWidgets('at 100% of duration, value is exactly 1.0 (clamped)', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pumpAndSettleFixedTickers();
      expect(controller.value, 1.0);
    });

    testWidgets('with CurvedAnimation: value follows curve correctly', (
      tester,
    ) async {
      late Animation<double> curved;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) {
            c.forward();
            curved = CurvedAnimation(parent: c, curve: Curves.easeIn);
          },
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 165));
      // easeIn should be below linear at midpoint
      expect(curved.value, lessThan(0.5));

      await tester.pumpAndSettleFixedTickers();
      expect(curved.value, 1.0);
    });

    testWidgets('with Tween: interpolates correctly at each tick', (
      tester,
    ) async {
      late Animation<double> tweened;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) {
            c.forward();
            tweened = Tween<double>(begin: 100, end: 200).animate(c);
          },
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 165));
      expect(tweened.value, closeTo(150, 5));

      await tester.pumpAndSettleFixedTickers();
      expect(tweened.value, 200.0);
    });
  });

  group('AnimatedBuilder integration', () {
    testWidgets('widget rebuilds on each tick', (tester) async {
      var buildCount = 0;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => c.forward(),
          duration: const Duration(milliseconds: 330),
          builder: (context, c) {
            buildCount++;
            return Text(
              c.value.toStringAsFixed(2),
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      buildCount = 0;
      await tester.pumpAndSettleFixedTickers();

      // At least some rebuilds occurred (exact count depends on pump interval)
      expect(buildCount, greaterThan(0));
    });

    testWidgets('rendered output reflects animation value', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => c.forward(),
          duration: const Duration(milliseconds: 330),
          builder: (context, c) {
            return Opacity(
              opacity: c.value,
              child: const Text('Hello', textDirection: TextDirection.ltr),
            );
          },
        ),
      );

      await tester.pumpAndSettleFixedTickers();
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });
  });

  group('status listeners', () {
    testWidgets('receives forward, completed, reverse, dismissed', (
      tester,
    ) async {
      late AnimationController controller;
      final statuses = <AnimationStatus>[];
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) {
            controller = c
              ..addStatusListener(statuses.add)
              ..forward();
          },
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pumpAndSettleFixedTickers();
      expect(statuses, contains(AnimationStatus.forward));
      expect(statuses, contains(AnimationStatus.completed));

      statuses.clear();
      unawaited(controller.reverse());
      await tester.pumpAndSettleFixedTickers();
      expect(statuses, contains(AnimationStatus.reverse));
      expect(statuses, contains(AnimationStatus.dismissed));
    });
  });

  group('multiple AnimationControllers', () {
    testWidgets('two controllers run independently', (tester) async {
      late AnimationController c1;
      late AnimationController c2;
      await tester.pumpWidget(
        _MultiControllerTestApp(
          onInit: (ctrl1, ctrl2) {
            c1 = ctrl1..forward();
            c2 = ctrl2..forward();
          },
          duration1: const Duration(milliseconds: 330),
          duration2: const Duration(milliseconds: 660),
        ),
      );

      await tester.pump(const Duration(milliseconds: 330));
      expect(c1.value, 1.0);
      expect(c2.value, closeTo(0.5, 0.05));

      await tester.pumpAndSettleFixedTickers();
      expect(c1.value, 1.0);
      expect(c2.value, 1.0);
    });

    testWidgets('stopping one does not affect the other', (tester) async {
      late AnimationController c1;
      late AnimationController c2;
      await tester.pumpWidget(
        _MultiControllerTestApp(
          onInit: (ctrl1, ctrl2) {
            c1 = ctrl1..forward();
            c2 = ctrl2..forward();
          },
          duration1: const Duration(milliseconds: 330),
          duration2: const Duration(milliseconds: 660),
        ),
      );

      await tester.pump(const Duration(milliseconds: 330));
      expect(c1.value, 1.0);
      c1.stop();

      // c2 should still be running independently
      await tester.pumpAndSettleFixedTickers();
      expect(c2.value, 1.0);
    });
  });

  group('widget disposal', () {
    testWidgets('disposing widget mid-animation: no errors', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => c.forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 165));
      // Remove widget from tree mid-animation
      await tester.pumpWidget(const SizedBox());

      // No errors should have been thrown
      expect(tester.takeException(), isNull);
    });
  });

  group('TickerMode integration', () {
    testWidgets('TickerMode(enabled: false) pauses the animation', (
      tester,
    ) async {
      late AnimationController controller;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeTestApp(
          tickerModeEnabled: tickerModeEnabled,
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));
      final valueBeforePause = controller.value;
      expect(valueBeforePause, greaterThan(0.0));

      tickerModeEnabled.value = false;
      await tester.pump();

      // Should be muted now
      await tester.pump(const Duration(milliseconds: 330));
      expect(controller.value, valueBeforePause);
    });

    testWidgets('re-enabling TickerMode: animation resumes '
        '(elapsed includes paused time)', (tester) async {
      late AnimationController controller;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeTestApp(
          tickerModeEnabled: tickerModeEnabled,
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));

      // Pause for longer than the remaining animation duration
      tickerModeEnabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Re-enable: elapsed includes paused time, so animation completes
      tickerModeEnabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
      expect(controller.value, 1.0);
    });
  });

  group('configurable interval', () {
    testWidgets('custom tickerInterval fires at that rate', (tester) async {
      var tickCount = 0;
      late AnimationController controller;
      await tester.pumpWidget(
        _CustomIntervalTestApp(
          interval: const Duration(milliseconds: 100),
          onInit: (c) => controller = c..forward(),
          onTick: () => tickCount++,
          duration: const Duration(milliseconds: 1000),
        ),
      );

      tickCount = 0;
      await tester.pump(const Duration(milliseconds: 500));
      // 500ms / 100ms = 5 ticks
      expect(tickCount, 5);

      controller.stop();
    });

    testWidgets('animation value at completion is identical regardless of '
        'interval', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _CustomIntervalTestApp(
          interval: const Duration(milliseconds: 100),
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 1000),
        ),
      );

      await tester.pumpAndSettleFixedTickers();
      expect(controller.value, 1.0);
    });
  });

  group('absorbTicker', () {
    testWidgets('absorbing a started ticker transfers the future', (
      tester,
    ) async {
      final elapsed1 = <Duration>[];
      final elapsed2 = <Duration>[];
      final ticker1 = FixedTicker(elapsed1.add)..start().ignore();

      // Pump to fire the frame callback, setting the parent's private
      // _startTime that absorbTicker checks.
      await tester.pump();

      final ticker2 = FixedTicker(elapsed2.add)..absorbTicker(ticker1);

      expect(ticker1.isActive, isFalse);
      expect(ticker2.isActive, isTrue);

      await tester.pump(const Duration(milliseconds: 33));
      expect(elapsed2, isNotEmpty);

      ticker2
        ..stop()
        ..dispose();
    });
  });

  group('pumpAndSettleFixedTickers', () {
    testWidgets('settles a forward animation', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      final count = await tester.pumpAndSettleFixedTickers();
      expect(controller.value, 1.0);
      expect(count, greaterThan(0));
    });

    testWidgets('settles multiple concurrent animations', (tester) async {
      late AnimationController c1;
      late AnimationController c2;
      await tester.pumpWidget(
        _MultiControllerTestApp(
          onInit: (ctrl1, ctrl2) {
            c1 = ctrl1..forward();
            c2 = ctrl2..forward();
          },
          duration1: const Duration(milliseconds: 330),
          duration2: const Duration(milliseconds: 660),
        ),
      );

      await tester.pumpAndSettleFixedTickers();
      expect(c1.value, 1.0);
      expect(c2.value, 1.0);
    });

    testWidgets('times out for repeat() animations', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          onInit: (c) => c.repeat(),
          duration: const Duration(milliseconds: 330),
        ),
      );

      expect(
        () => tester.pumpAndSettleFixedTickers(
          const Duration(milliseconds: 100),
          const Duration(milliseconds: 500),
        ),
        throwsA(isA<FlutterError>()),
      );
    });

    testWidgets('works correctly when no FixedTickers are active', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Text('Hello')),
      );

      final count = await tester.pumpAndSettleFixedTickers();
      expect(count, greaterThan(0));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _TestApp extends StatefulWidget {
  const _TestApp({
    required this.onInit,
    required this.duration,
    this.builder,
  });

  final void Function(AnimationController) onInit;
  final Duration duration;
  final Widget Function(BuildContext, AnimationController)? builder;

  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    widget.onInit(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => widget.builder!(context, _controller),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Text(
        _controller.value.toStringAsFixed(2),
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

class _MultiControllerTestApp extends StatefulWidget {
  const _MultiControllerTestApp({
    required this.onInit,
    required this.duration1,
    required this.duration2,
  });

  final void Function(AnimationController, AnimationController) onInit;
  final Duration duration1;
  final Duration duration2;

  @override
  State<_MultiControllerTestApp> createState() =>
      _MultiControllerTestAppState();
}

class _MultiControllerTestAppState extends State<_MultiControllerTestApp>
    with FixedTickerProviderStateMixin {
  late final AnimationController _controller1;
  late final AnimationController _controller2;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      vsync: this,
      duration: widget.duration1,
    );
    _controller2 = AnimationController(
      vsync: this,
      duration: widget.duration2,
    );
    widget.onInit(_controller1, _controller2);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class _TickerModeTestApp extends StatelessWidget {
  const _TickerModeTestApp({
    required this.tickerModeEnabled,
    required this.onInit,
    required this.duration,
  });

  final ValueNotifier<bool> tickerModeEnabled;
  final void Function(AnimationController) onInit;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: tickerModeEnabled,
      builder: (context, enabled, _) {
        return TickerMode(
          enabled: enabled,
          child: _TestApp(onInit: onInit, duration: duration),
        );
      },
    );
  }
}

class _CustomIntervalTestApp extends StatefulWidget {
  const _CustomIntervalTestApp({
    required this.interval,
    required this.onInit,
    required this.duration,
    this.onTick,
  });

  final Duration interval;
  final void Function(AnimationController) onInit;
  final Duration duration;
  final VoidCallback? onTick;

  @override
  State<_CustomIntervalTestApp> createState() => _CustomIntervalTestAppState();
}

class _CustomIntervalTestAppState extends State<_CustomIntervalTestApp>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Duration get tickerInterval => widget.interval;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.onTick != null) {
      _controller.addListener(widget.onTick!);
    }
    widget.onInit(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
