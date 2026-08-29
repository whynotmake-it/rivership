import 'dart:async';

import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shared scheduler adversarial behavior', () {
    testWidgets(
      'joining a faster rate does not postpone an already-running ticker',
      (tester) async {
        const slowInterval = Duration(milliseconds: 100);
        const fastInterval = Duration(milliseconds: 50);
        final slowElapsed = <Duration>[];
        final slow = FixedTicker(slowElapsed.add, interval: slowInterval);
        final fast = FixedTicker((_) {}, interval: fastInterval);
        try {
          unawaited(slow.start());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 75));

          unawaited(fast.start());
          await tester.pump();
          slowElapsed.clear();

          await tester.pump(const Duration(milliseconds: 25));

          expect(
            slowElapsed,
            hasLength(1),
            reason:
                'The slow ticker was already 75ms into its 100ms period. '
                'Joining a harmonic ticker must not stretch that period.',
          );
        } finally {
          _disposeTickers([slow, fast]);
        }
      },
    );

    testWidgets(
      'a common faster rate synchronizes previously separate harmonic groups',
      (tester) async {
        const hundredMilliseconds = Duration(milliseconds: 100);
        const hundredFiftyMilliseconds = Duration(milliseconds: 150);
        const commonInterval = Duration(milliseconds: 50);
        var pumpNumber = 0;
        final hundredMillisecondTicks = <int>[];
        final hundredFiftyMillisecondTicks = <int>[];
        final commonTicks = <int>[];
        final hundred = FixedTicker(
          (_) => hundredMillisecondTicks.add(pumpNumber),
          interval: hundredMilliseconds,
        );
        final hundredFifty = FixedTicker(
          (_) => hundredFiftyMillisecondTicks.add(pumpNumber),
          interval: hundredFiftyMilliseconds,
        );
        final common = FixedTicker(
          (_) => commonTicks.add(pumpNumber),
          interval: commonInterval,
        );
        try {
          unawaited(hundred.start());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 25));
          unawaited(hundredFifty.start());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 25));
          unawaited(common.start());
          await tester.pump();
          hundredMillisecondTicks.clear();
          hundredFiftyMillisecondTicks.clear();
          commonTicks.clear();

          for (pumpNumber = 1; pumpNumber <= 12; pumpNumber++) {
            await tester.pump(const Duration(milliseconds: 25));
          }

          final commonBoundaries = hundredMillisecondTicks
              .toSet()
              .intersection(hundredFiftyMillisecondTicks.toSet())
              .intersection(commonTicks.toSet());
          expect(
            commonBoundaries,
            isNotEmpty,
            reason:
                '50ms is a common divisor of 100ms and 150ms, so all three '
                'rates must share their 300ms boundary. Observed pump numbers: '
                '100ms=$hundredMillisecondTicks, '
                '150ms=$hundredFiftyMillisecondTicks, 50ms=$commonTicks.',
          );
        } finally {
          _disposeTickers([hundred, hundredFifty, common]);
        }
      },
    );

    testWidgets('a late equal-rate ticker joins the next shared boundary', (
      tester,
    ) async {
      const interval = Duration(milliseconds: 80);
      final firstElapsed = <Duration>[];
      final secondElapsed = <Duration>[];
      final first = FixedTicker(firstElapsed.add, interval: interval);
      final second = FixedTicker(secondElapsed.add, interval: interval);
      try {
        unawaited(first.start());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        unawaited(second.start());
        await tester.pump();
        firstElapsed.clear();
        secondElapsed.clear();

        await tester.pump(const Duration(milliseconds: 10));

        expect(firstElapsed, hasLength(1));
        expect(secondElapsed, hasLength(1));
      } finally {
        _disposeTickers([first, second]);
      }
    });

    testWidgets('opting out while active establishes an independent phase', (
      tester,
    ) async {
      const interval = Duration(milliseconds: 60);
      final anchorElapsed = <Duration>[];
      final optedOutElapsed = <Duration>[];
      final anchor = FixedTicker(anchorElapsed.add, interval: interval);
      final optedOut = FixedTicker(optedOutElapsed.add, interval: interval);
      try {
        unawaited(anchor.start());
        unawaited(optedOut.start());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        optedOut.shared = false;
        await tester.pump();
        anchorElapsed.clear();
        optedOutElapsed.clear();

        await tester.pump(const Duration(milliseconds: 30));
        expect(anchorElapsed, hasLength(1));
        expect(optedOutElapsed, isEmpty);

        await tester.pump(const Duration(milliseconds: 30));
        expect(anchorElapsed, hasLength(1));
        expect(optedOutElapsed, hasLength(1));
      } finally {
        _disposeTickers([anchor, optedOut]);
      }
    });

    testWidgets('one subscriber stopping on tick does not suppress its peer', (
      tester,
    ) async {
      const interval = Duration(milliseconds: 40);
      late FixedTicker selfStopping;
      final selfTicks = <Duration>[];
      final peerTicks = <Duration>[];
      selfStopping = FixedTicker(
        (elapsed) {
          selfTicks.add(elapsed);
          if (elapsed > Duration.zero) selfStopping.stop();
        },
        interval: interval,
      );
      final peer = FixedTicker(peerTicks.add, interval: interval);
      try {
        unawaited(selfStopping.start());
        unawaited(peer.start());
        await tester.pump();
        selfTicks.clear();
        peerTicks.clear();

        await tester.pump(interval);

        expect(selfTicks, hasLength(1));
        expect(peerTicks, hasLength(1));
        expect(selfStopping.isActive, isFalse);
        expect(peer.isActive, isTrue);
        expect(FixedTicker.hasActiveTimers, isTrue);

        await tester.pump(interval);
        expect(selfTicks, hasLength(1));
        expect(peerTicks, hasLength(2));
      } finally {
        _disposeTickers([selfStopping, peer]);
      }
    });

    testWidgets('muting and rejoining one ticker does not rephase its peer', (
      tester,
    ) async {
      const interval = Duration(milliseconds: 50);
      final anchorElapsed = <Duration>[];
      final rejoiningElapsed = <Duration>[];
      final anchor = FixedTicker(anchorElapsed.add, interval: interval);
      final rejoining = FixedTicker(rejoiningElapsed.add, interval: interval);
      try {
        unawaited(anchor.start());
        unawaited(rejoining.start());
        await tester.pump();
        await tester.pump(interval);
        rejoining.muted = true;
        anchorElapsed.clear();
        rejoiningElapsed.clear();

        await tester.pump(const Duration(milliseconds: 25));
        rejoining.muted = false;
        await tester.pump();
        rejoiningElapsed.clear();
        await tester.pump(const Duration(milliseconds: 25));

        expect(anchorElapsed, hasLength(1));
        expect(rejoiningElapsed, hasLength(1));
      } finally {
        _disposeTickers([anchor, rejoining]);
      }
    });

    testWidgets('removing the fastest subscriber preserves slower cadence', (
      tester,
    ) async {
      const fastInterval = Duration(milliseconds: 50);
      const slowInterval = Duration(milliseconds: 100);
      final fast = FixedTicker((_) {}, interval: fastInterval);
      final slowElapsed = <Duration>[];
      final slow = FixedTicker(slowElapsed.add, interval: slowInterval);
      try {
        unawaited(fast.start());
        unawaited(slow.start());
        await tester.pump();
        await tester.pump(fastInterval);
        fast.stop();
        slowElapsed.clear();

        await tester.pump(fastInterval);

        expect(slowElapsed, hasLength(1));
        expect(slow.isActive, isTrue);
        expect(FixedTicker.hasActiveTimers, isTrue);
      } finally {
        _disposeTickers([fast, slow]);
      }
    });
  });
}

void _disposeTickers(Iterable<FixedTicker> tickers) {
  for (final ticker in tickers) {
    if (ticker.isActive) ticker.stop();
    ticker.dispose();
  }
}
