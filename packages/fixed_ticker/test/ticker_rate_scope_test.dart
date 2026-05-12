import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TickerRateScope', () {
    testWidgets('maybeOf returns null when no scope exists',
        (tester) async {
      TickerRate? result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = TickerRateScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(result, isNull);
    });

    testWidgets('of returns TickerRate.vsync() when no scope exists',
        (tester) async {
      late TickerRate result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = TickerRateScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(result, isA<VsyncTickerRate>());
      expect(result, equals(const TickerRate.vsync()));
    });

    testWidgets('maybeOf returns the rate from nearest scope',
        (tester) async {
      TickerRate? result;
      final rate = TickerRate.fps(30);
      await tester.pumpWidget(
        TickerRateScope(
          rate: rate,
          child: Builder(
            builder: (context) {
              result = TickerRateScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, equals(rate));
    });

    testWidgets('of returns the rate from nearest scope',
        (tester) async {
      late TickerRate result;
      final rate = TickerRate.fps(30);
      await tester.pumpWidget(
        TickerRateScope(
          rate: rate,
          child: Builder(
            builder: (context) {
              result = TickerRateScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, equals(rate));
    });

    testWidgets('nested scopes: inner scope wins', (tester) async {
      late TickerRate result;
      final outerRate = TickerRate.fps(30);
      final innerRate = TickerRate.fps(10);
      await tester.pumpWidget(
        TickerRateScope(
          rate: outerRate,
          child: TickerRateScope(
            rate: innerRate,
            child: Builder(
              builder: (context) {
                result = TickerRateScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(result, equals(innerRate));
      expect(result, isNot(equals(outerRate)));
    });

    test('updateShouldNotify returns true when rate changes', () {
      final widget1 = TickerRateScope(
        rate: TickerRate.fps(30),
        child: const SizedBox(),
      );
      final widget2 = TickerRateScope(
        rate: TickerRate.fps(60),
        child: const SizedBox(),
      );
      expect(widget2.updateShouldNotify(widget1), isTrue);
    });

    test('updateShouldNotify returns false when rate is the same', () {
      final widget1 = TickerRateScope(
        rate: TickerRate.fps(30),
        child: const SizedBox(),
      );
      final widget2 = TickerRateScope(
        rate: TickerRate.fps(30),
        child: const SizedBox(),
      );
      expect(widget2.updateShouldNotify(widget1), isFalse);
    });
  });
}
