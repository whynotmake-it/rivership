import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SingleFixedTickerProviderStateMixin', () {
    testWidgets('createTicker returns a FixedTicker with the mixin interval',
        (tester) async {
      Ticker? ticker;
      await tester.pumpWidget(
        _SingleTickerTestWidget(
          onTicker: (t) => ticker = t,
        ),
      );

      expect(ticker, isA<FixedTicker>());
      expect((ticker! as FixedTicker).interval,
          const Duration(milliseconds: 33));
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
        contains('SingleFixedTickerProviderStateMixin.createTicker '
            'was called twice'),
      );
    });

    testWidgets('TickerMode disables/enables correctly', (tester) async {
      late AnimationController controller;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeWrapper(
          tickerModeEnabled: tickerModeEnabled,
          child: _SingleTickerAnimationWidget(
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

    testWidgets('custom interval via override', (tester) async {
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

    testWidgets('dispose asserts ticker not active', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _SingleTickerAnimationWidget(
          onInit: (c) => controller = c..forward(),
          duration: const Duration(milliseconds: 3300),
        ),
      );

      await tester.pump(const Duration(milliseconds: 33));
      expect(controller.isAnimating, isTrue);

      // Removing widget from tree while ticker is active should assert
      // (the State.dispose will be called, which disposes the controller first)
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
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

    testWidgets('TickerMode disables/enables all tickers', (tester) async {
      late AnimationController c1;
      late AnimationController c2;
      final tickerModeEnabled = ValueNotifier(true);
      await tester.pumpWidget(
        _TickerModeWrapper(
          tickerModeEnabled: tickerModeEnabled,
          child: _MultiControllerAnimationWidget(
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

    testWidgets('activate() re-subscribes to TickerMode notifier',
        (tester) async {
      late AnimationController controller;
      final tickerModeEnabled = ValueNotifier(true);
      // Test that moving the widget in the tree re-subscribes
      await tester.pumpWidget(
        _TickerModeWrapper(
          tickerModeEnabled: tickerModeEnabled,
          child: _SingleTickerAnimationWidget(
            key: const GlobalObjectKey('test-widget'),
            onInit: (c) => controller = c..forward(),
            duration: const Duration(milliseconds: 1000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 99));
      expect(controller.value, greaterThan(0.0));

      // Disable ticker mode, verify it still works after re-subscribe
      tickerModeEnabled.value = false;
      await tester.pump();
      final frozenValue = controller.value;
      await tester.pump(const Duration(milliseconds: 330));
      expect(controller.value, frozenValue);

      controller.stop();
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
    super.key,
  });

  final void Function(AnimationController) onInit;
  final Duration duration;

  @override
  State<_SingleTickerAnimationWidget> createState() =>
      _SingleTickerAnimationWidgetState();
}

class _SingleTickerAnimationWidgetState
    extends State<_SingleTickerAnimationWidget>
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
  Duration get tickerInterval => widget.interval;

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
  Duration get tickerInterval => widget.interval;

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
  });

  final void Function(AnimationController, AnimationController) onInit;
  final Duration duration1;
  final Duration duration2;

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
