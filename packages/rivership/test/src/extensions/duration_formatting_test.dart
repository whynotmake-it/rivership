import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('DurationFormatting', () {
    const zero = Duration.zero;
    const oneHourThirtyMinutes = Duration(hours: 1, minutes: 30);
    const multiDay = Duration(
      days: 4,
      hours: 12,
      minutes: 34,
      seconds: 3,
      milliseconds: 2,
      microseconds: 42,
    );

    group('toStringHHMMSS', () {
      test("handles zero case", () async {
        expect(zero.toStringHHMMSS(), "00:00:00");
      });
      test("handles standard duration with leading zeroes", () async {
        expect(oneHourThirtyMinutes.toStringHHMMSS(), "01:30:00");
      });
      test("converts multi day into hours", () async {
        expect(multiDay.toStringHHMMSS(), "${multiDay.inHours}:34:03");
      });
      test("handles negative duration", () async {
        for (final duration in [oneHourThirtyMinutes, multiDay]) {
          expect(
            (duration * -1).toStringHHMMSS(),
            "-${duration.toStringHHMMSS()}",
          );
        }
        expect((zero * -1).toStringHHMMSS(), zero.toStringHHMMSS());
      });
    });

    group('toStringMMSS', () {
      test("handles zero case", () async {
        expect(zero.toStringMMSS(), "00:00");
      });
      test("handles standard duration", () async {
        expect(oneHourThirtyMinutes.toStringMMSS(), "30:00");
      });
      test("ignores everything besides minutes and seconds", () async {
        expect(multiDay.toStringMMSS(), "34:03");
      });
      test("handles negative duration", () async {
        for (final duration in [oneHourThirtyMinutes, multiDay]) {
          expect(
            (duration * -1).toStringMMSS(),
            "-${duration.toStringMMSS()}",
          );
        }
        expect((zero * -1).toStringMMSS(), zero.toStringMMSS());
      });
    });

    group('toStringMSS', () {
      test("handles zero case", () async {
        expect(zero.toStringMSS(), "0:00");
      });
      test("handles standard duration", () async {
        expect(oneHourThirtyMinutes.toStringMSS(), "30:00");
      });
      test("ignores everything besides minutes and seconds", () async {
        expect(multiDay.toStringMSS(), "34:03");
      });
      test("handles negative duration", () async {
        for (final duration in [oneHourThirtyMinutes, multiDay]) {
          expect(
            (duration * -1).toStringMSS(),
            "-${duration.toStringMSS()}",
          );
        }
        expect((zero * -1).toStringMSS(), zero.toStringMSS());
      });
    });
  });
}
