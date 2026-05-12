import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TickerRate', () {
    test('vsync() creates VsyncTickerRate with null interval', () {
      const rate = TickerRate.vsync();
      expect(rate, isA<VsyncTickerRate>());
      expect(rate.interval, isNull);
    });

    test('interval() creates FixedTickerRate with correct interval', () {
      const duration = Duration(milliseconds: 33);
      const rate = TickerRate.interval(duration);
      expect(rate, isA<FixedTickerRate>());
      expect(rate.interval, duration);
    });

    test('fps(30) creates FixedTickerRate with ~33333 microsecond interval',
        () {
      final rate = TickerRate.fps(30);
      expect(rate, isA<FixedTickerRate>());
      expect(rate.interval!.inMicroseconds, closeTo(33333, 1));
    });

    test('fps(60) creates FixedTickerRate with ~16667 microsecond interval',
        () {
      final rate = TickerRate.fps(60);
      expect(rate, isA<FixedTickerRate>());
      expect(rate.interval!.inMicroseconds, closeTo(16667, 1));
    });
  });

  group('VsyncTickerRate', () {
    test('all instances are equal', () {
      const a = VsyncTickerRate();
      const b = VsyncTickerRate();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('is not equal to FixedTickerRate', () {
      const vsync = VsyncTickerRate();
      const fixed = FixedTickerRate(Duration(milliseconds: 33));
      expect(vsync, isNot(equals(fixed)));
    });
  });

  group('FixedTickerRate', () {
    test('same interval instances are equal', () {
      const a = FixedTickerRate(Duration(milliseconds: 33));
      const b = FixedTickerRate(Duration(milliseconds: 33));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different interval instances are not equal', () {
      const a = FixedTickerRate(Duration(milliseconds: 33));
      const b = FixedTickerRate(Duration(milliseconds: 100));
      expect(a, isNot(equals(b)));
    });

    test('is not equal to VsyncTickerRate', () {
      const fixed = FixedTickerRate(Duration(milliseconds: 33));
      const vsync = VsyncTickerRate();
      expect(fixed, isNot(equals(vsync)));
    });
  });

  group('pattern matching', () {
    test('switch expression matches VsyncTickerRate', () {
      const rate = TickerRate.vsync();
      final result = switch (rate) {
        VsyncTickerRate() => 'vsync',
        FixedTickerRate(:final interval) => 'fixed:$interval',
      };
      expect(result, 'vsync');
    });

    test('switch expression matches FixedTickerRate with interval', () {
      const rate = TickerRate.interval(Duration(milliseconds: 50));
      final result = switch (rate) {
        VsyncTickerRate() => 'vsync',
        FixedTickerRate(:final interval) => 'fixed:$interval',
      };
      expect(result, 'fixed:0:00:00.050000');
    });
  });
}
