import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/playback/playback_clock.dart';

void main() {
  const ms = Duration(milliseconds: 1);

  group('PlaybackClock', () {
    test('follows the ticker at rate 1', () {
      final clock = PlaybackClock()..tickerStarted();

      expect(clock.tick(ms * 250), ms * 250);
      expect(clock.now, ms * 250);
    });

    test('continues where it stopped when the ticker restarts', () {
      final clock = PlaybackClock()
        ..tickerStarted()
        ..tick(ms * 300)
        ..tickerStarted();

      expect(clock.tick(Duration.zero), ms * 300);
      expect(clock.tick(ms * 100), ms * 400);
      expect(clock.sinceTickerStart, ms * 100);
    });

    test('changing the rate keeps the position and scales what follows', () {
      final clock = PlaybackClock()
        ..tickerStarted()
        ..tick(ms * 200)
        ..rate = 0.5;

      expect(clock.now, ms * 200);
      expect(clock.tick(ms * 400), ms * 300);
    });

    test('seeking moves the position and continues from it', () {
      final clock = PlaybackClock()
        ..tickerStarted()
        ..tick(ms * 500)
        ..seek(ms * 200);

      expect(clock.now, ms * 200);
      expect(clock.tick(ms * 600), ms * 300);
    });

    test('seeking keeps the time since the ticker started', () {
      final clock = PlaybackClock()
        ..tickerStarted()
        ..tick(ms * 500)
        ..seek(ms * 200);

      expect(clock.sinceTickerStart, ms * 500);
      clock.tick(ms * 600);
      expect(clock.sinceTickerStart, ms * 600);
    });
  });
}
