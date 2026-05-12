import 'dart:async';

import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const _interval = Duration(milliseconds: 33);

TickerRate _rateFromInterval(Duration? interval) {
  return interval == null
      ? const TickerRate.vsync()
      : TickerRate.interval(interval);
}

void main() {
  group('SingleFixedTickerProviderStateMixin', () {
    testWidgets('createTicker returns a FixedTicker with null interval '
        'by default', (tester) async {
      Ticker? ticker;
      await tester.pumpWidget(
        _SingleTickerTestWidget(
          onTicker: (t) => ticker = t,
        ),
      );

      expect(ticker, isA<FixedTicker>());
      expect((ticker! as FixedTicker).interval, isNull);
    });

    testWidgets('createTicker returns a FixedTicker with custom interval', (
      tester,
    ) async {
      Ticker? ticker;
      await tester.pumpWidget(
        _CustomIntervalSingleTickerWidget(
          interval: const Duration(milliseconds: 100),
          onTicker: (t) => ticker = t,
        ),
      );

      expect(ticker, isA<FixedTicker>());
      expect(
        (ticker! as FixedTicker).interval,
        const Duration(milliseconds: 100),
      );
    });

    testWidgets('throws on second createTicker call', (tester) async {
      FlutterError? error;
      await tester.pumpWidget(
        _SingleTickerTestWidget(
          createSecondTicker: true,
          onError: (e) => error = e,
        ),
      );

      expect(error, isNotNull);
      expect(
        error!.message,
        contains(
          'SingleFixedTickerProviderStateMixin.createTicker '
          'was called twice',
        ),
      );
    });

    testWidgets('TickerMode disables/enables correctly', (tester) async {
      late AnimationController controller;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeWrapper(
          tickerModeEnabled: tickerModeEnabled,
          child: _SingleTickerAnimationWidget(
            interval: _interval,
            onInit: (c) => controller = c..forward(),
            duration: const Duration(milliseconds: 330),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));
      final valueBeforePause = controller.value;
      expect(valueBeforePause, greaterThan(0.0));

      // Disable TickerMode
      tickerModeEnabled.value = false;
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 330));
      // Should not have progressed while muted
      expect(controller.value, valueBeforePause);

      // Re-enable TickerMode
      tickerModeEnabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
      // Elapsed includes muted time, so should jump ahead
      expect(controller.value, greaterThan(valueBeforePause));
    });

    testWidgets('dispose asserts ticker not active', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _SingleTickerAnimationWidget(
          interval: _interval,
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 3300),
        ),
      );

      await tester.pump(const Duration(milliseconds: 33));
      expect(controller.isAnimating, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('updateTickerRate applies new interval', (tester) async {
      late _UpdateIntervalSingleTickerWidgetState state;
      await tester.pumpWidget(
        _UpdateIntervalSingleTickerWidget(
          initialInterval: _interval,
          onState: (s) => state = s,
        ),
      );

      unawaited(state.controller.forward());
      await tester.pump(const Duration(milliseconds: 33));
      expect(state.controller.isAnimating, isTrue);

      // Switch to a different interval
      state.setInterval(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.controller.value, greaterThan(0));

      state.controller.stop();
    });

    testWidgets('updateTickerRate can switch to null (normal mode)', (
      tester,
    ) async {
      late _UpdateIntervalSingleTickerWidgetState state;
      await tester.pumpWidget(
        _UpdateIntervalSingleTickerWidget(
          initialInterval: _interval,
          onState: (s) => state = s,
        ),
      );

      unawaited(state.controller.forward());
      await tester.pump(const Duration(milliseconds: 33));

      state.setInterval(null);
      expect(FixedTicker.hasActiveTimers, isFalse);
      expect(state.controller.isAnimating, isTrue);

      state.controller.stop();
    });
  });

  group('FixedTickerProviderStateMixin', () {
    testWidgets('multiple tickers allowed', (tester) async {
      final tickers = <Ticker>[];
      await tester.pumpWidget(
        _MultiTickerTestWidget(
          tickerCount: 3,
          onTickers: tickers.addAll,
        ),
      );

      expect(tickers, hasLength(3));
      for (final ticker in tickers) {
        expect(ticker, isA<FixedTicker>());
      }
    });

    testWidgets('tickers have null interval by default', (tester) async {
      final tickers = <Ticker>[];
      await tester.pumpWidget(
        _MultiTickerTestWidget(
          tickerCount: 1,
          onTickers: tickers.addAll,
        ),
      );

      expect((tickers.first as FixedTicker).interval, isNull);
    });

    testWidgets('TickerMode disables/enables all tickers', (tester) async {
      late AnimationController c1;
      late AnimationController c2;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeWrapper(
          tickerModeEnabled: tickerModeEnabled,
          child: _MultiControllerAnimationWidget(
            interval: _interval,
            onInit: (ctrl1, ctrl2) {
              c1 = ctrl1..forward();
              c2 = ctrl2..forward();
            },
            duration1: const Duration(milliseconds: 330),
            duration2: const Duration(milliseconds: 660),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));
      final v1Before = c1.value;
      final v2Before = c2.value;

      tickerModeEnabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 330));

      expect(c1.value, v1Before);
      expect(c2.value, v2Before);
    });

    testWidgets('custom interval via override', (tester) async {
      final tickers = <Ticker>[];
      await tester.pumpWidget(
        _CustomIntervalMultiTickerWidget(
          interval: const Duration(milliseconds: 50),
          tickerCount: 2,
          onTickers: tickers.addAll,
        ),
      );

      for (final ticker in tickers) {
        expect(
          (ticker as FixedTicker).interval,
          const Duration(milliseconds: 50),
        );
      }
    });

    testWidgets('dispose cleans up all tickers', (tester) async {
      await tester.pumpWidget(
        _MultiControllerAnimationWidget(
          interval: _interval,
          onInit: (ctrl1, ctrl2) {
            ctrl1.forward();
            ctrl2.forward();
          },
          duration1: const Duration(milliseconds: 330),
          duration2: const Duration(milliseconds: 660),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));
      // Remove from tree - should dispose cleanly
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('activate() re-subscribes to TickerMode notifier', (
      tester,
    ) async {
      late AnimationController controller;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeWrapper(
          tickerModeEnabled: tickerModeEnabled,
          child: _SingleTickerAnimationWidget(
            key: const GlobalObjectKey('test-widget'),
            interval: _interval,
            onInit: (c) => controller = c..forward(),
            duration: const Duration(milliseconds: 1000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));
      expect(controller.value, greaterThan(0.0));

      tickerModeEnabled.value = false;
      await tester.pump();
      final frozenValue = controller.value;
      await tester.pump(const Duration(milliseconds: 330));
      expect(controller.value, frozenValue);

      controller.stop();
    });

    testWidgets('updateTickerRate applies to all tickers', (tester) async {
      late _UpdateIntervalMultiTickerWidgetState state;
      await tester.pumpWidget(
        _UpdateIntervalMultiTickerWidget(
          initialInterval: _interval,
          onState: (s) => state = s,
        ),
      );

      unawaited(state.c1.forward());
      unawaited(state.c2.forward());
      await tester.pump(const Duration(milliseconds: 33));

      state.setInterval(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.c1.value, greaterThan(0));
      expect(state.c2.value, greaterThan(0));

      state.c1.stop();
      state.c2.stop();
    });
  });

  group('TickerRateScope + SingleFixedTickerProviderStateMixin', () {
    testWidgets('reads interval from TickerRateScope by default', (
      tester,
    ) async {
      Ticker? ticker;
      await tester.pumpWidget(
        TickerRateScope(
          rate: TickerRate.fps(30),
          child: _ScopeAwareSingleTickerWidget(
            onTicker: (t) => ticker = t,
          ),
        ),
      );

      expect(ticker, isA<FixedTicker>());
      expect(
        (ticker! as FixedTicker).interval!.inMicroseconds,
        closeTo(33333, 1),
      );
    });

    testWidgets('changing TickerRateScope rate auto-syncs the ticker', (
      tester,
    ) async {
      late _TickerRateScopeWrapperState scopeState;
      Ticker? ticker;
      await tester.pumpWidget(
        _TickerRateScopeWrapper(
          initialRate: TickerRate.fps(30),
          onState: (s) => scopeState = s,
          child: _ScopeAwareSingleTickerWidget(
            onTicker: (t) => ticker = t,
          ),
        ),
      );

      expect(
        (ticker! as FixedTicker).interval!.inMicroseconds,
        closeTo(33333, 1),
      );

      scopeState.setRate(TickerRate.fps(10));
      await tester.pump();

      expect(
        (ticker! as FixedTicker).interval!.inMicroseconds,
        closeTo(100000, 1),
      );
    });

    testWidgets('changing scope to vsync sets interval to null', (
      tester,
    ) async {
      late _TickerRateScopeWrapperState scopeState;
      Ticker? ticker;
      await tester.pumpWidget(
        _TickerRateScopeWrapper(
          initialRate: TickerRate.fps(30),
          onState: (s) => scopeState = s,
          child: _ScopeAwareSingleTickerWidget(
            onTicker: (t) => ticker = t,
          ),
        ),
      );

      expect((ticker! as FixedTicker).interval, isNotNull);

      scopeState.setRate(const TickerRate.vsync());
      await tester.pump();

      expect((ticker! as FixedTicker).interval, isNull);
    });

    testWidgets('overriding tickerRate takes precedence over scope', (
      tester,
    ) async {
      Ticker? ticker;
      await tester.pumpWidget(
        TickerRateScope(
          rate: TickerRate.fps(30),
          child: _ScopeOverrideSingleTickerWidget(
            interval: const Duration(milliseconds: 100),
            onTicker: (t) => ticker = t,
          ),
        ),
      );

      expect(ticker, isA<FixedTicker>());
      expect(
        (ticker! as FixedTicker).interval,
        const Duration(milliseconds: 100),
      );
    });

    testWidgets('no scope defaults to null interval (vsync)', (tester) async {
      Ticker? ticker;
      await tester.pumpWidget(
        _ScopeAwareSingleTickerWidget(
          onTicker: (t) => ticker = t,
        ),
      );

      expect(ticker, isA<FixedTicker>());
      expect((ticker! as FixedTicker).interval, isNull);
    });
  });

  group('TickerRateScope + FixedTickerProviderStateMixin', () {
    testWidgets('reads interval from TickerRateScope by default', (
      tester,
    ) async {
      final tickers = <Ticker>[];
      await tester.pumpWidget(
        TickerRateScope(
          rate: TickerRate.fps(30),
          child: _ScopeAwareMultiTickerWidget(
            onTickers: tickers.addAll,
          ),
        ),
      );

      for (final ticker in tickers) {
        expect(ticker, isA<FixedTicker>());
        expect(
          (ticker as FixedTicker).interval!.inMicroseconds,
          closeTo(33333, 1),
        );
      }
    });

    testWidgets('changing TickerRateScope rate auto-syncs all tickers', (
      tester,
    ) async {
      late _TickerRateScopeWrapperState scopeState;
      final tickers = <Ticker>[];
      await tester.pumpWidget(
        _TickerRateScopeWrapper(
          initialRate: TickerRate.fps(30),
          onState: (s) => scopeState = s,
          child: _ScopeAwareMultiTickerWidget(
            onTickers: tickers.addAll,
          ),
        ),
      );

      for (final ticker in tickers) {
        expect(
          (ticker as FixedTicker).interval!.inMicroseconds,
          closeTo(33333, 1),
        );
      }

      scopeState.setRate(TickerRate.fps(10));
      await tester.pump();

      for (final ticker in tickers) {
        expect(
          (ticker as FixedTicker).interval!.inMicroseconds,
          closeTo(100000, 1),
        );
      }
    });

    testWidgets('no scope defaults to null interval (vsync)', (tester) async {
      final tickers = <Ticker>[];
      await tester.pumpWidget(
        _ScopeAwareMultiTickerWidget(
          onTickers: tickers.addAll,
        ),
      );

      for (final ticker in tickers) {
        expect(ticker, isA<FixedTicker>());
        expect((ticker as FixedTicker).interval, isNull);
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _SingleTickerTestWidget extends StatefulWidget {
  const _SingleTickerTestWidget({
    this.onTicker,
    this.createSecondTicker = false,
    this.onError,
  });

  final void Function(Ticker)? onTicker;
  final bool createSecondTicker;
  final void Function(FlutterError)? onError;

  @override
  State<_SingleTickerTestWidget> createState() =>
      _SingleTickerTestWidgetState();
}

class _SingleTickerTestWidgetState extends State<_SingleTickerTestWidget>
    with SingleFixedTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    final ticker = createTicker((_) {});
    widget.onTicker?.call(ticker);
    if (widget.createSecondTicker) {
      try {
        createTicker((_) {});
        // ignore: avoid_catching_errors
      } on FlutterError catch (e) {
        widget.onError?.call(e);
      }
    }
    ticker.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _SingleTickerAnimationWidget extends StatefulWidget {
  const _SingleTickerAnimationWidget({
    required this.onInit,
    required this.duration,
    this.interval,
    super.key,
  });

  final void Function(AnimationController) onInit;
  final Duration duration;
  final Duration? interval;

  @override
  State<_SingleTickerAnimationWidget> createState() =>
      _SingleTickerAnimationWidgetState();
}

class _SingleTickerAnimationWidgetState
    extends State<_SingleTickerAnimationWidget>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  TickerRate get tickerRate => _rateFromInterval(widget.interval);

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
  Widget build(BuildContext context) => const SizedBox();
}

class _MultiTickerTestWidget extends StatefulWidget {
  const _MultiTickerTestWidget({
    required this.tickerCount,
    this.onTickers,
  });

  final int tickerCount;
  final void Function(List<Ticker>)? onTickers;

  @override
  State<_MultiTickerTestWidget> createState() => _MultiTickerTestWidgetState();
}

class _MultiTickerTestWidgetState extends State<_MultiTickerTestWidget>
    with FixedTickerProviderStateMixin {
  final _tickers = <Ticker>[];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.tickerCount; i++) {
      _tickers.add(createTicker((_) {}));
    }
    widget.onTickers?.call(_tickers);
  }

  @override
  void dispose() {
    for (final ticker in _tickers) {
      ticker.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _CustomIntervalSingleTickerWidget extends StatefulWidget {
  const _CustomIntervalSingleTickerWidget({
    required this.interval,
    this.onTicker,
  });

  final Duration interval;
  final void Function(Ticker)? onTicker;

  @override
  State<_CustomIntervalSingleTickerWidget> createState() =>
      _CustomIntervalSingleTickerWidgetState();
}

class _CustomIntervalSingleTickerWidgetState
    extends State<_CustomIntervalSingleTickerWidget>
    with SingleFixedTickerProviderStateMixin {
  @override
  TickerRate get tickerRate => TickerRate.interval(widget.interval);

  @override
  void initState() {
    super.initState();
    final ticker = createTicker((_) {});
    widget.onTicker?.call(ticker);
    ticker.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _CustomIntervalMultiTickerWidget extends StatefulWidget {
  const _CustomIntervalMultiTickerWidget({
    required this.interval,
    required this.tickerCount,
    this.onTickers,
  });

  final Duration interval;
  final int tickerCount;
  final void Function(List<Ticker>)? onTickers;

  @override
  State<_CustomIntervalMultiTickerWidget> createState() =>
      _CustomIntervalMultiTickerWidgetState();
}

class _CustomIntervalMultiTickerWidgetState
    extends State<_CustomIntervalMultiTickerWidget>
    with FixedTickerProviderStateMixin {
  final _tickers = <Ticker>[];

  @override
  TickerRate get tickerRate => TickerRate.interval(widget.interval);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.tickerCount; i++) {
      _tickers.add(createTicker((_) {}));
    }
    widget.onTickers?.call(_tickers);
  }

  @override
  void dispose() {
    for (final ticker in _tickers) {
      ticker.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _MultiControllerAnimationWidget extends StatefulWidget {
  const _MultiControllerAnimationWidget({
    required this.onInit,
    required this.duration1,
    required this.duration2,
    this.interval,
  });

  final void Function(AnimationController, AnimationController) onInit;
  final Duration duration1;
  final Duration duration2;
  final Duration? interval;

  @override
  State<_MultiControllerAnimationWidget> createState() =>
      _MultiControllerAnimationWidgetState();
}

class _MultiControllerAnimationWidgetState
    extends State<_MultiControllerAnimationWidget>
    with FixedTickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;

  @override
  TickerRate get tickerRate => _rateFromInterval(widget.interval);

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: widget.duration1);
    _c2 = AnimationController(vsync: this, duration: widget.duration2);
    widget.onInit(_c1, _c2);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _TickerModeWrapper extends StatelessWidget {
  const _TickerModeWrapper({
    required this.tickerModeEnabled,
    required this.child,
  });

  final ValueNotifier<bool> tickerModeEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: tickerModeEnabled,
      builder: (context, enabled, _) {
        return TickerMode(enabled: enabled, child: child);
      },
    );
  }
}

class _UpdateIntervalSingleTickerWidget extends StatefulWidget {
  const _UpdateIntervalSingleTickerWidget({
    required this.initialInterval,
    required this.onState,
  });

  final Duration? initialInterval;
  final void Function(_UpdateIntervalSingleTickerWidgetState) onState;

  @override
  State<_UpdateIntervalSingleTickerWidget> createState() =>
      _UpdateIntervalSingleTickerWidgetState();
}

class _UpdateIntervalSingleTickerWidgetState
    extends State<_UpdateIntervalSingleTickerWidget>
    with SingleFixedTickerProviderStateMixin {
  late final AnimationController controller;
  Duration? _currentInterval;

  @override
  TickerRate get tickerRate => _rateFromInterval(_currentInterval);

  void setInterval(Duration? interval) {
    setState(() => _currentInterval = interval);
    updateTickerRate();
  }

  @override
  void initState() {
    super.initState();
    _currentInterval = widget.initialInterval;
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    widget.onState(this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _UpdateIntervalMultiTickerWidget extends StatefulWidget {
  const _UpdateIntervalMultiTickerWidget({
    required this.initialInterval,
    required this.onState,
  });

  final Duration? initialInterval;
  final void Function(_UpdateIntervalMultiTickerWidgetState) onState;

  @override
  State<_UpdateIntervalMultiTickerWidget> createState() =>
      _UpdateIntervalMultiTickerWidgetState();
}

class _UpdateIntervalMultiTickerWidgetState
    extends State<_UpdateIntervalMultiTickerWidget>
    with FixedTickerProviderStateMixin {
  late final AnimationController c1;
  late final AnimationController c2;
  Duration? _currentInterval;

  @override
  TickerRate get tickerRate => _rateFromInterval(_currentInterval);

  void setInterval(Duration? interval) {
    setState(() => _currentInterval = interval);
    updateTickerRate();
  }

  @override
  void initState() {
    super.initState();
    _currentInterval = widget.initialInterval;
    c1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    c2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    widget.onState(this);
  }

  @override
  void dispose() {
    c1.dispose();
    c2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// ---------------------------------------------------------------------------
// TickerRateScope test helpers
// ---------------------------------------------------------------------------

class _TickerRateScopeWrapper extends StatefulWidget {
  const _TickerRateScopeWrapper({
    required this.initialRate,
    required this.child,
    this.onState,
  });

  final TickerRate initialRate;
  final Widget child;
  final void Function(_TickerRateScopeWrapperState)? onState;

  @override
  State<_TickerRateScopeWrapper> createState() =>
      _TickerRateScopeWrapperState();
}

class _TickerRateScopeWrapperState extends State<_TickerRateScopeWrapper> {
  late TickerRate _rate;

  void setRate(TickerRate rate) {
    setState(() => _rate = rate);
  }

  @override
  void initState() {
    super.initState();
    _rate = widget.initialRate;
    widget.onState?.call(this);
  }

  @override
  Widget build(BuildContext context) {
    return TickerRateScope(rate: _rate, child: widget.child);
  }
}

class _ScopeAwareSingleTickerWidget extends StatefulWidget {
  const _ScopeAwareSingleTickerWidget({
    this.onTicker,
  });

  final void Function(Ticker)? onTicker;

  @override
  State<_ScopeAwareSingleTickerWidget> createState() =>
      _ScopeAwareSingleTickerWidgetState();
}

class _ScopeAwareSingleTickerWidgetState
    extends State<_ScopeAwareSingleTickerWidget>
    with SingleFixedTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {});
    widget.onTicker?.call(_ticker);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _ScopeOverrideSingleTickerWidget extends StatefulWidget {
  const _ScopeOverrideSingleTickerWidget({
    required this.interval,
    this.onTicker,
  });

  final Duration? interval;
  final void Function(Ticker)? onTicker;

  @override
  State<_ScopeOverrideSingleTickerWidget> createState() =>
      _ScopeOverrideSingleTickerWidgetState();
}

class _ScopeOverrideSingleTickerWidgetState
    extends State<_ScopeOverrideSingleTickerWidget>
    with SingleFixedTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  TickerRate get tickerRate => _rateFromInterval(widget.interval);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {});
    widget.onTicker?.call(_ticker);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _ScopeAwareMultiTickerWidget extends StatefulWidget {
  const _ScopeAwareMultiTickerWidget({
    this.onTickers,
  });

  final void Function(List<Ticker>)? onTickers;

  @override
  State<_ScopeAwareMultiTickerWidget> createState() =>
      _ScopeAwareMultiTickerWidgetState();
}

class _ScopeAwareMultiTickerWidgetState
    extends State<_ScopeAwareMultiTickerWidget>
    with FixedTickerProviderStateMixin {
  final _tickers = <Ticker>[];

  @override
  void initState() {
    super.initState();
    _tickers
      ..add(createTicker((_) {}))
      ..add(createTicker((_) {}));
    widget.onTickers?.call(_tickers);
  }

  @override
  void dispose() {
    for (final ticker in _tickers) {
      ticker.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
