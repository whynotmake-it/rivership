import 'dart:async';

import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const _interval = Duration(milliseconds: 33);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FixedTicker (fixed-rate mode)', () {
    testWidgets('start() schedules an initial frame and fixed ticks', (
      tester,
    ) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      expect(elapsed, <Duration>[Duration.zero]);

      elapsed.clear();
      await tester.pump(_interval);
      await tester.pump(_interval);
      await tester.pump(_interval);

      expect(elapsed, <Duration>[
        _interval,
        _interval * 2,
        _interval * 3,
      ]);

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('stop() cancels the timer and TickerFuture completes', (
      tester,
    ) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);

      final future = ticker.start();
      await tester.pump();
      elapsed.clear();

      await tester.pump(_interval);
      expect(elapsed, hasLength(1));

      ticker.stop();
      await tester.pump(const Duration(milliseconds: 100));
      expect(elapsed, hasLength(1));

      expect(future, isA<TickerFuture>());
      ticker.dispose();
    });

    testWidgets('start() after stop() resets elapsed to zero', (tester) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      await tester.pump(_interval * 2);
      expect(elapsed.last, _interval * 2);

      ticker.stop();
      elapsed.clear();

      unawaited(ticker.start());
      await tester.pump();
      expect(elapsed, <Duration>[Duration.zero]);

      await tester.pump(_interval);
      expect(elapsed.last, _interval);

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('dispose() cancels timer', (tester) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      await tester.pump(_interval);
      expect(elapsed, hasLength(2));

      ticker
        ..stop()
        ..dispose();

      await tester.pump(const Duration(milliseconds: 100));
      expect(elapsed, hasLength(2));
    });

    testWidgets('custom interval fires at the specified rate', (tester) async {
      const interval = Duration(milliseconds: 100);
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: interval);
      unawaited(ticker.start());

      await tester.pump();
      elapsed.clear();

      await tester.pump(interval);
      await tester.pump(interval);
      await tester.pump(interval);

      expect(elapsed, <Duration>[
        interval,
        interval * 2,
        interval * 3,
      ]);

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('after interval pumps, elapsed stays on the frame clock', (
      tester,
    ) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      elapsed.clear();

      for (var i = 0; i < 120; i++) {
        await tester.pump(_interval);
      }

      expect(elapsed, hasLength(120));
      expect(elapsed.last, _interval * 120);
      for (var i = 1; i < elapsed.length; i++) {
        expect(elapsed[i], greaterThan(elapsed[i - 1]));
      }

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('muting cancels and restarts the timer', (tester) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      await tester.pump(_interval);
      expect(elapsed, hasLength(2));

      ticker.muted = true;
      await tester.pump(const Duration(milliseconds: 330));
      expect(elapsed, hasLength(2));
      expect(FixedTicker.hasActiveTimers, isFalse);

      ticker.muted = false;
      await tester.pump();
      expect(elapsed.last, const Duration(milliseconds: 363));
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('scheduled reports pending frame callbacks only', (
      tester,
    ) async {
      final ticker = _InspectableFixedTicker((_) {}, interval: _interval);
      expect(ticker.isFrameScheduled, isFalse);

      unawaited(ticker.start());
      expect(ticker.isFrameScheduled, isTrue);
      expect(FixedTicker.hasActiveTimers, isTrue);

      await tester.pump();
      expect(ticker.isFrameScheduled, isFalse);
      expect(ticker.isTicking, isTrue);
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker.stop();
      expect(ticker.isFrameScheduled, isFalse);
      expect(FixedTicker.hasActiveTimers, isFalse);

      ticker.dispose();
    });

    testWidgets('isTicking follows base ticker active and muted state', (
      tester,
    ) async {
      final ticker = FixedTicker((_) {}, interval: _interval);
      expect(ticker.isTicking, isFalse);

      unawaited(ticker.start());
      expect(ticker.isTicking, isTrue);

      ticker.muted = true;
      expect(ticker.isTicking, isFalse);
      expect(ticker.isActive, isTrue);

      ticker.muted = false;
      expect(ticker.isTicking, isTrue);

      ticker.stop();
      expect(ticker.isTicking, isFalse);

      ticker.dispose();
    });

    testWidgets('hasActiveTimers tracks active instances', (tester) async {
      expect(FixedTicker.hasActiveTimers, isFalse);

      final ticker1 = FixedTicker((_) {}, interval: _interval);
      unawaited(ticker1.start());
      expect(FixedTicker.hasActiveTimers, isTrue);

      final ticker2 = FixedTicker((_) {}, interval: _interval);
      unawaited(ticker2.start());
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker1.stop();
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker2.stop();
      expect(FixedTicker.hasActiveTimers, isFalse);

      ticker1.dispose();
      ticker2.dispose();
    });

    testWidgets('manual scheduleTick does not create duplicate timers', (
      tester,
    ) async {
      final ticker = _InspectableFixedTicker((_) {}, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      expect(ticker.isFrameScheduled, isFalse);
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker.callScheduleTick();
      expect(ticker.isFrameScheduled, isTrue);
      expect(FixedTicker.hasActiveTimers, isTrue);

      await tester.pump();
      expect(ticker.isFrameScheduled, isFalse);
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker
        ..stop()
        ..dispose();
      expect(FixedTicker.hasActiveTimers, isFalse);
    });

    testWidgets('absorbing a non-started ticker works without error', (
      tester,
    ) async {
      final ticker1 = FixedTicker((_) {}, interval: _interval);
      final ticker2 = FixedTicker((_) {}, interval: _interval)
        ..absorbTicker(ticker1);
      expect(ticker1.isActive, isFalse);

      ticker2.dispose();
    });

    testWidgets('absorbing a started ticker preserves timer accounting', (
      tester,
    ) async {
      final elapsed = <Duration>[];
      final ticker1 = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker1.start());

      await tester.pump();
      expect(FixedTicker.hasActiveTimers, isTrue);

      final ticker2 = FixedTicker(elapsed.add, interval: _interval)
        ..absorbTicker(ticker1);

      expect(ticker1.isActive, isFalse);
      expect(ticker2.isActive, isTrue);
      expect(FixedTicker.hasActiveTimers, isTrue);

      ticker2
        ..stop()
        ..dispose();
      expect(FixedTicker.hasActiveTimers, isFalse);
    });
  });

  group('shared fixed-rate scheduling', () {
    testWidgets('equal intervals join the same phase', (tester) async {
      const interval = Duration(milliseconds: 50);
      final firstElapsed = <Duration>[];
      final secondElapsed = <Duration>[];
      final first = FixedTicker(firstElapsed.add, interval: interval);
      final second = FixedTicker(secondElapsed.add, interval: interval);

      unawaited(first.start());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));

      unawaited(second.start());
      await tester.pump();
      firstElapsed.clear();
      secondElapsed.clear();

      await tester.pump(const Duration(milliseconds: 25));
      expect(firstElapsed, hasLength(1));
      expect(secondElapsed, hasLength(1));

      first
        ..stop()
        ..dispose();
      second
        ..stop()
        ..dispose();
    });

    testWidgets('multiple intervals meet on shared boundaries', (tester) async {
      const fastInterval = Duration(milliseconds: 50);
      const slowInterval = Duration(milliseconds: 100);
      final fastElapsed = <Duration>[];
      final slowElapsed = <Duration>[];
      final fast = FixedTicker(fastElapsed.add, interval: fastInterval);
      final slow = FixedTicker(slowElapsed.add, interval: slowInterval);

      unawaited(fast.start());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));

      unawaited(slow.start());
      await tester.pump();
      fastElapsed.clear();
      slowElapsed.clear();

      await tester.pump(const Duration(milliseconds: 25));
      expect(fastElapsed, hasLength(1));
      expect(slowElapsed, isEmpty);

      await tester.pump(const Duration(milliseconds: 50));
      expect(fastElapsed, hasLength(2));
      expect(slowElapsed, hasLength(1));

      fast
        ..stop()
        ..dispose();
      slow
        ..stop()
        ..dispose();
    });

    testWidgets('a faster ticker rephases an existing slower group', (
      tester,
    ) async {
      const fastInterval = Duration(milliseconds: 50);
      const slowInterval = Duration(milliseconds: 100);
      final fastElapsed = <Duration>[];
      final slowElapsed = <Duration>[];
      final slow = FixedTicker(slowElapsed.add, interval: slowInterval);
      final fast = FixedTicker(fastElapsed.add, interval: fastInterval);

      unawaited(slow.start());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));

      unawaited(fast.start());
      await tester.pump();
      fastElapsed.clear();
      slowElapsed.clear();

      await tester.pump(const Duration(milliseconds: 50));
      expect(fastElapsed, hasLength(1));
      expect(slowElapsed, isEmpty);

      await tester.pump(const Duration(milliseconds: 50));
      expect(fastElapsed, hasLength(2));
      expect(slowElapsed, hasLength(1));

      fast
        ..stop()
        ..dispose();
      slow
        ..stop()
        ..dispose();
    });

    testWidgets('shared false retains an independent phase', (tester) async {
      const interval = Duration(milliseconds: 50);
      final sharedElapsed = <Duration>[];
      final independentElapsed = <Duration>[];
      final shared = FixedTicker(sharedElapsed.add, interval: interval);
      final independent = FixedTicker(
        independentElapsed.add,
        interval: interval,
        shared: false,
      );

      unawaited(shared.start());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));

      unawaited(independent.start());
      await tester.pump();
      sharedElapsed.clear();
      independentElapsed.clear();

      await tester.pump(const Duration(milliseconds: 25));
      expect(sharedElapsed, hasLength(1));
      expect(independentElapsed, isEmpty);

      await tester.pump(const Duration(milliseconds: 25));
      expect(sharedElapsed, hasLength(1));
      expect(independentElapsed, hasLength(1));

      shared
        ..stop()
        ..dispose();
      independent
        ..stop()
        ..dispose();
    });

    testWidgets('changing shared mode rephases an active ticker', (
      tester,
    ) async {
      const interval = Duration(milliseconds: 50);
      final anchor = FixedTicker((_) {}, interval: interval);
      final elapsed = <Duration>[];
      final ticker = FixedTicker(
        elapsed.add,
        interval: interval,
        shared: false,
      );

      unawaited(anchor.start());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      unawaited(ticker.start());
      await tester.pump();
      elapsed.clear();

      ticker.shared = true;
      await tester.pump();
      elapsed.clear();
      await tester.pump(const Duration(milliseconds: 25));
      expect(elapsed, hasLength(1));

      anchor
        ..stop()
        ..dispose();
      ticker
        ..stop()
        ..dispose();
    });
  });

  group('FixedTicker (null interval / normal mode)', () {
    testWidgets('behaves like a normal Ticker when interval is null', (
      tester,
    ) async {
      final ticker = FixedTicker((_) {});
      expect(ticker.interval, isNull);

      unawaited(ticker.start());
      expect(ticker.isActive, isTrue);
      expect(FixedTicker.hasActiveTimers, isFalse);

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('scheduled delegates to parent when interval is null', (
      tester,
    ) async {
      final ticker = _InspectableFixedTicker((_) {}, interval: null);
      expect(ticker.isFrameScheduled, isFalse);

      unawaited(ticker.start());
      expect(ticker.isFrameScheduled, isTrue);

      ticker
        ..stop()
        ..dispose();
    });
  });

  group('mutable interval', () {
    testWidgets('changing interval restarts the timer', (tester) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(
        elapsed.add,
        interval: const Duration(milliseconds: 100),
      );
      unawaited(ticker.start());

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(elapsed, hasLength(3));

      ticker.interval = const Duration(milliseconds: 50);
      elapsed.clear();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(elapsed, hasLength(4));

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets('no-op when setting the same interval', (tester) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(elapsed.add, interval: _interval);
      unawaited(ticker.start());

      await tester.pump();
      await tester.pump(_interval);
      expect(elapsed, hasLength(2));

      ticker.interval = _interval;
      await tester.pump(_interval);
      expect(elapsed, hasLength(3));

      ticker
        ..stop()
        ..dispose();
    });

    testWidgets(
      'setting interval while not active takes effect on next start',
      (tester) async {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(elapsed.add, interval: _interval)
          ..interval = const Duration(milliseconds: 100);
        unawaited(ticker.start());

        await tester.pump();
        elapsed.clear();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(elapsed, hasLength(2));
        expect(elapsed[0], const Duration(milliseconds: 100));

        ticker
          ..stop()
          ..dispose();
      },
    );

    testWidgets(
      'setting interval to null while active switches to normal mode',
      (tester) async {
        final ticker = FixedTicker(
          (_) {},
          interval: _interval,
        );
        unawaited(ticker.start());

        expect(FixedTicker.hasActiveTimers, isTrue);
        ticker.interval = null;
        expect(FixedTicker.hasActiveTimers, isFalse);
        expect(ticker.isActive, isTrue);

        ticker
          ..stop()
          ..dispose();
      },
    );

    testWidgets(
      'setting interval from null to Duration starts fixed-rate mode',
      (tester) async {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(elapsed.add);
        unawaited(ticker.start());

        expect(FixedTicker.hasActiveTimers, isFalse);
        ticker.interval = const Duration(milliseconds: 50);
        expect(FixedTicker.hasActiveTimers, isTrue);

        await tester.pump(const Duration(milliseconds: 50));
        expect(elapsed, isNotEmpty);

        ticker
          ..stop()
          ..dispose();
      },
    );

    testWidgets('setting interval while muted takes effect on unmute', (
      tester,
    ) async {
      final elapsed = <Duration>[];
      final ticker = FixedTicker(
        elapsed.add,
        interval: const Duration(milliseconds: 100),
      );
      unawaited(ticker.start());

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(elapsed, hasLength(2));

      ticker
        ..muted = true
        ..interval = const Duration(milliseconds: 50)
        ..muted = false;
      elapsed.clear();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(elapsed, hasLength(5));

      ticker
        ..stop()
        ..dispose();
    });
  });
}

class _InspectableFixedTicker extends FixedTicker {
  _InspectableFixedTicker(
    super.onTick, {
    required super.interval,
  });

  void callScheduleTick() => scheduleTick();

  bool get isFrameScheduled => scheduled;
}
