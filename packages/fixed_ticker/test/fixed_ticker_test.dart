import 'package:fake_async/fake_async.dart';
import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const _interval = Duration(milliseconds: 33);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FixedTicker (fixed-rate mode)', () {
    group('lifecycle', () {
      test('start() begins firing callbacks at the configured interval', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 99));

          expect(elapsed, hasLength(3));
          expect(elapsed[0], const Duration(milliseconds: 33));
          expect(elapsed[1], const Duration(milliseconds: 66));
          expect(elapsed[2], const Duration(milliseconds: 99));

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('stop() cancels the timer and TickerFuture completes', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          );

          final future = ticker.start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed, hasLength(1));

          ticker.stop();
          fake.elapse(const Duration(milliseconds: 100));
          expect(elapsed, hasLength(1));

          expect(future, isA<TickerFuture>());
          ticker.dispose();
        });
      });

      test('start() after stop() resets elapsed to 0', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 66));
          expect(elapsed.last, const Duration(milliseconds: 66));

          ticker.stop();
          elapsed.clear();

          ticker.start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed.last, const Duration(milliseconds: 33));

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('dispose() cancels timer', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed, hasLength(1));

          ticker
            ..stop()
            ..dispose();

          fake.elapse(const Duration(milliseconds: 100));
          expect(elapsed, hasLength(1));
        });
      });

      test('custom interval fires at the specified rate', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: const Duration(milliseconds: 100),
          )..start();
          fake.elapse(const Duration(milliseconds: 300));

          expect(elapsed, hasLength(3));
          expect(elapsed[0], const Duration(milliseconds: 100));
          expect(elapsed[1], const Duration(milliseconds: 200));
          expect(elapsed[2], const Duration(milliseconds: 300));

          ticker
            ..stop()
            ..dispose();
        });
      });
    });

    group('elapsed accuracy / drift', () {
      test('after N ticks, elapsed = N * interval', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 330));

          expect(elapsed, hasLength(10));
          for (var i = 0; i < elapsed.length; i++) {
            expect(
              elapsed[i],
              Duration(milliseconds: (i + 1) * 33),
              reason:
                  'Tick ${i + 1} should have elapsed ${(i + 1) * 33}ms',
            );
          }

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('after 1000+ ticks, no drift accumulation', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 33 * 1500));

          expect(elapsed, hasLength(1500));
          expect(
            elapsed.last,
            const Duration(milliseconds: 33 * 1500),
          );

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('elapsed is monotonically increasing', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 330));

          for (var i = 1; i < elapsed.length; i++) {
            expect(
              elapsed[i],
              greaterThan(elapsed[i - 1]),
              reason: 'Tick $i should be greater than tick ${i - 1}',
            );
          }

          ticker
            ..stop()
            ..dispose();
        });
      });
    });

    group('muting', () {
      test('muted=true cancels the timer (no callbacks fire)', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed, hasLength(1));

          ticker.muted = true;
          fake.elapse(const Duration(milliseconds: 330));
          expect(elapsed, hasLength(1));

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('muted=false restarts the timer', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed, hasLength(1));

          ticker.muted = true;
          fake.elapse(const Duration(milliseconds: 100));

          ticker.muted = false;
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed, hasLength(2));

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('elapsed INCLUDES muted time', () {
        fakeAsync((fake) {
          final elapsed = <Duration>[];
          final ticker = FixedTicker(
            elapsed.add,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(elapsed.last, const Duration(milliseconds: 33));

          ticker.muted = true;
          fake.elapse(const Duration(milliseconds: 200));

          ticker.muted = false;
          fake.elapse(const Duration(milliseconds: 33));

          expect(elapsed.last, const Duration(milliseconds: 266));

          ticker
            ..stop()
            ..dispose();
        });
      });

      test('no callbacks during muted period', () {
        fakeAsync((fake) {
          var callCount = 0;
          final ticker = FixedTicker(
            (_) => callCount++,
            interval: _interval,
          )..start();
          fake.elapse(const Duration(milliseconds: 33));
          expect(callCount, 1);

          ticker.muted = true;
          fake.elapse(const Duration(milliseconds: 330));
          expect(callCount, 1);

          ticker
            ..stop()
            ..dispose();
        });
      });
    });

    group('scheduling state', () {
      test(
        'scheduled is false before start, true during, false after stop',
        () {
          fakeAsync((fake) {
            final ticker = FixedTicker((_) {}, interval: _interval);
            expect(ticker.scheduled, isFalse);

            ticker.start();
            expect(ticker.scheduled, isTrue);

            ticker.stop();
            expect(ticker.scheduled, isFalse);

            ticker.dispose();
          });
        },
      );

      test('isTicking = isActive and not muted', () {
        fakeAsync((fake) {
          final ticker = FixedTicker((_) {}, interval: _interval);
          expect(ticker.isTicking, isFalse);

          ticker.start();
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
      });

      test('hasActiveTimers tracks active instances', () {
        fakeAsync((fake) {
          expect(FixedTicker.hasActiveTimers, isFalse);

          final ticker1 = FixedTicker((_) {}, interval: _interval)
            ..start();
          expect(FixedTicker.hasActiveTimers, isTrue);

          final ticker2 = FixedTicker((_) {}, interval: _interval)
            ..start();
          expect(FixedTicker.hasActiveTimers, isTrue);

          ticker1.stop();
          expect(FixedTicker.hasActiveTimers, isTrue);

          ticker2.stop();
          expect(FixedTicker.hasActiveTimers, isFalse);

          ticker1.dispose();
          ticker2.dispose();
        });
      });
    });

    group('absorbTicker', () {
      test('absorbing a non-started ticker works without error', () {
        fakeAsync((fake) {
          final ticker1 = FixedTicker((_) {}, interval: _interval);
          final ticker2 = FixedTicker((_) {}, interval: _interval)
            ..absorbTicker(ticker1);
          expect(ticker1.isActive, isFalse);

          ticker2.dispose();
        });
      });
    });
  });

  group('FixedTicker (null interval / normal mode)', () {
    test('behaves like a normal Ticker when interval is null', () {
      fakeAsync((fake) {
        final ticker = FixedTicker((_) {});
        expect(ticker.interval, isNull);

        ticker.start();
        expect(ticker.isActive, isTrue);
        expect(FixedTicker.hasActiveTimers, isFalse);

        ticker
          ..stop()
          ..dispose();
      });
    });

    test('scheduled delegates to parent when interval is null', () {
      fakeAsync((fake) {
        final ticker = FixedTicker((_) {});
        expect(ticker.scheduled, isFalse);

        ticker.start();
        expect(ticker.scheduled, isTrue);

        ticker
          ..stop()
          ..dispose();
      });
    });
  });

  group('mutable interval', () {
    test('changing interval restarts the timer', () {
      fakeAsync((fake) {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(
          elapsed.add,
          interval: const Duration(milliseconds: 100),
        )..start();
        fake.elapse(const Duration(milliseconds: 200));
        expect(elapsed, hasLength(2));

        ticker.interval = const Duration(milliseconds: 50);
        elapsed.clear();
        fake.elapse(const Duration(milliseconds: 200));
        expect(elapsed, hasLength(4));

        ticker
          ..stop()
          ..dispose();
      });
    });

    test('no-op when setting the same interval', () {
      fakeAsync((fake) {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(
          elapsed.add,
          interval: _interval,
        )..start();
        fake.elapse(const Duration(milliseconds: 33));
        expect(elapsed, hasLength(1));

        ticker.interval = _interval;
        fake.elapse(const Duration(milliseconds: 33));
        expect(elapsed, hasLength(2));

        ticker
          ..stop()
          ..dispose();
      });
    });

    test('setting interval while not active takes effect on next start',
        () {
      fakeAsync((fake) {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(
          elapsed.add,
          interval: _interval,
        )
          ..interval = const Duration(milliseconds: 100)
          ..start();
        fake.elapse(const Duration(milliseconds: 200));
        expect(elapsed, hasLength(2));
        expect(elapsed[0], const Duration(milliseconds: 100));

        ticker
          ..stop()
          ..dispose();
      });
    });

    test('setting interval to null while active switches to normal mode',
        () {
      fakeAsync((fake) {
        final ticker = FixedTicker(
          (_) {},
          interval: _interval,
        )..start();

        expect(FixedTicker.hasActiveTimers, isTrue);
        ticker.interval = null;
        expect(FixedTicker.hasActiveTimers, isFalse);
        expect(ticker.isActive, isTrue);

        ticker
          ..stop()
          ..dispose();
      });
    });

    test('setting interval from null to Duration starts fixed-rate mode',
        () {
      fakeAsync((fake) {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(elapsed.add)..start();

        expect(FixedTicker.hasActiveTimers, isFalse);
        ticker.interval = const Duration(milliseconds: 50);
        expect(FixedTicker.hasActiveTimers, isTrue);

        fake.elapse(const Duration(milliseconds: 150));
        expect(elapsed, isNotEmpty);

        ticker
          ..stop()
          ..dispose();
      });
    });

    test('setting interval while muted takes effect on unmute', () {
      fakeAsync((fake) {
        final elapsed = <Duration>[];
        final ticker = FixedTicker(
          elapsed.add,
          interval: const Duration(milliseconds: 100),
        )..start();
        fake.elapse(const Duration(milliseconds: 100));
        expect(elapsed, hasLength(1));

        ticker
          ..muted = true
          ..interval = const Duration(milliseconds: 50)
          ..muted = false;
        elapsed.clear();
        fake.elapse(const Duration(milliseconds: 200));
        expect(elapsed, hasLength(4));

        ticker
          ..stop()
          ..dispose();
      });
    });
  });
}
