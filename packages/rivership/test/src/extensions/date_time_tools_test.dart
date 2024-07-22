import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:rivership_test/rivership_test.dart';

void main() {
  group('DateTimeTools', () {
    // the following tests are sort of localized. They still work in other
    // timezones but the separation between DST and non-DST only makes sense for
    // some timezones
    final dateDst = DateTime(2020, 12, 2, 18, 5, 2, 42, 1);
    final dateNoDst = DateTime(2020, 6, 2, 10, 5, 2, 42, 1);
    final crossedDst = dateDst.timeZoneOffset != dateNoDst.timeZoneOffset;
    final startOfYear = DateTime(2020);
    final endOfYear = DateTime(2021).subtract(const Duration(microseconds: 1));
    if (crossedDst == false) {
      debugPrint("Date Time tests running in a timezone without DST");
    }

    group("startOfDay", () {
      test("returns start of day for date in daylight saving time", () async {
        final previousDay = DateTime(2020, 12);
        expect(
          dateDst.startOfDay(),
          previousDay.add(const Duration(days: 1)),
        );
      });
      test("returns start of day for date outside of daylight saving time",
          () async {
        final previousDay = DateTime(2020, 6);
        expect(
          dateNoDst.startOfDay(),
          previousDay.add(const Duration(days: 1)),
        );
      });
    });
    group("endOfDay", () {
      test("returns end of day for date in DST", () async {
        final nextDay = DateTime(2020, 12, 3);
        expect(
          dateDst.endOfDay(),
          nextDay.subtract(const Duration(microseconds: 1)),
        );
      });
      test("returns start of day for date outside of DST", () async {
        final nextDay = DateTime(2020, 6, 3);
        expect(
          dateNoDst.endOfDay(),
          nextDay.subtract(const Duration(microseconds: 1)),
        );
      });
    });
    group("addDaysSameTime", () {
      test("zero days is equal", () async {
        expect(dateNoDst.addDaysSameTime(0), dateNoDst);
        expect(dateDst.addDaysSameTime(0), dateDst);
      });

      test("adding days adds 24 hours in DST", () async {
        final added = dateDst.addDaysSameTime(1);
        expect(added.difference(dateDst), const Duration(hours: 24));
      });
      test("adding days keeps time when crossing DST", () async {
        final added = dateDst.addDaysSameTime(6 * 30);
        expect(dateDst.day, isNot(added.day));
        expect(dateDst.hour, added.hour);
        expect(dateDst.minute, added.minute);
        expect(dateDst.second, added.second);
        expect(dateDst.millisecond, added.millisecond);
        expect(dateDst.microsecond, added.microsecond);
      });
      test("subtracting days subtracts 24 hours in DST", () async {
        final subtracted = dateDst.addDaysSameTime(-1);
        expect(
          subtracted.difference(dateDst),
          const Duration(hours: -24),
        );
      });
      test("subtracting days keeps time when crossing DST", () async {
        final added = dateDst.addDaysSameTime(-6 * 30);
        expect(dateDst.day, isNot(added.day));
        expect(dateDst.hour, added.hour);
        expect(dateDst.minute, added.minute);
        expect(dateDst.second, added.second);
        expect(dateDst.millisecond, added.millisecond);
        expect(dateDst.microsecond, added.microsecond);
      });
    });
    group("getDaysUntil", () {
      test("same day is empty", () async {
        final result = dateDst.getDaysUntil(dateDst);
        expect(result, isEmpty);
      });
      test("is empty if end date is before start date", () async {
        final result = dateDst.getDaysUntil(
          dateDst.subtract(const Duration(days: 42)),
        );
        expect(result, isEmpty);
      });
      test("all dates are start of day", () async {
        final year = startOfYear.getDaysUntil(endOfYear, inclusive: true);
        expect(
          year.every(
            (d) =>
                d.hour == 0 &&
                d.minute == 0 &&
                d.second == 0 &&
                d.millisecond == 0 &&
                d.microsecond == 0,
          ),
          isTrue,
        );
      });
      test("default excludes end date", () async {
        final year = startOfYear.getDaysUntil(endOfYear);
        expect(year, isNot(contains(endOfYear)));
      });
      test("inclusive includes end date", () async {
        final year = startOfYear.getDaysUntil(endOfYear, inclusive: true);
        expect(year, contains(endOfYear.startOfDay()));
      });
      test("2020 is 366 days", () async {
        expect(
          startOfYear.getDaysUntil(endOfYear, inclusive: true).length,
          366,
        );
      });
    });
    group("withTimeFrom", () {
      test("doesn't modify if applied to itself", () async {
        expect(dateNoDst.withTimeFrom(dateNoDst), dateNoDst);
      });
      test("applies time accross DST", () async {
        final result = dateNoDst.withTimeFrom(dateDst);
        expect(result.year, dateNoDst.year);
        expect(result.month, dateNoDst.month);
        expect(result.day, dateNoDst.day);
        expect(result.hour, dateDst.hour);
        expect(result.minute, dateDst.minute);
        expect(result.second, dateDst.second);
        expect(result.millisecond, dateDst.millisecond);
        expect(result.microsecond, dateDst.microsecond);
      });
    });
    group("earlierDay", () {
      test("doesn't change if same day", () async {
        final other = dateNoDst.subtract(const Duration(hours: 1));
        expect(dateNoDst.earlierDay(other), dateNoDst);
      });
      test("returns itself if other is later day", () async {
        final other = dateNoDst.add(const Duration(days: 30));
        expect(dateNoDst.earlierDay(other), dateNoDst);
      });
      test("returns other if other is earlier day", () async {
        final other = dateNoDst.subtract(const Duration(days: 30));
        expect(dateNoDst.earlierDay(other), other);
      });
    });
    group("laterDay", () {
      test("doesn't change if same day", () async {
        final other = dateNoDst.add(const Duration(hours: 1));
        expect(dateNoDst.laterDay(other), dateNoDst);
      });
      test("returns itself if other is earlier day", () async {
        final other = dateNoDst.subtract(const Duration(days: 30));
        expect(dateNoDst.laterDay(other), dateNoDst);
      });
      test("returns other if other is later day", () async {
        final other = dateNoDst.add(const Duration(days: 30));
        expect(dateNoDst.laterDay(other), other);
      });
    });
    group("daysUntil", () {
      test("same day is 0 days", () async {
        expect(dateNoDst.daysUntil(dateNoDst), 0);
      });

      test("default excludes end day", () async {
        final start = DateTime(2020);
        final end = DateTime(2020, 1, 31);
        expect(start.daysUntil(end), 30);
      });
      test("inclusive includes end day", () async {
        final start = DateTime(2020);
        final end = DateTime(2020, 1, 31);
        expect(start.daysUntil(end, inclusive: true), 31);
      });
      test("negative if end is earlier", () async {
        final start = DateTime(2020);
        final end = DateTime(2020, 1, 31);
        expect(end.daysUntil(start, inclusive: true), -31);
      });
      test("2020 had 366 days", () async {
        expect(startOfYear.daysUntil(endOfYear, inclusive: true), 366);
      });
    });
    group("isSameDayAs", () {
      test("date is same day as itself", () async {
        expect(dateNoDst.isSameDayAs(dateNoDst), isTrue);
      });
      test("start of day is same day as end of day", () async {
        expect(
          dateNoDst.startOfDay().isSameDayAs(dateNoDst.endOfDay()),
          isTrue,
        );
      });
      test("day is not same day as later day", () async {
        expect(
          dateNoDst.add(const Duration(days: 42)).isSameDayAs(dateNoDst),
          isFalse,
        );
      });
      test("day is not same day as earlier day", () async {
        expect(
          dateNoDst.subtract(const Duration(days: 42)).isSameDayAs(dateNoDst),
          isFalse,
        );
      });
    });
    group("isToday", () {
      test("now is today", () async {
        expect(DateTime.now().isToday, isTrue);
      });
      test("tomorrow is not today", () async {
        expect(DateTime.now().add(const Duration(days: 1)).isToday, isFalse);
      });
      test("yesterday is not today", () async {
        expect(
          DateTime.now().subtract(const Duration(days: 1)).isToday,
          isFalse,
        );
      });
    });
    group("isBetween", () {
      test("date is not between itself", () async {
        expect(dateNoDst.isBetween(start: dateNoDst, end: dateNoDst), isFalse);
      });
      test("date is between itself if inclusive", () async {
        expect(
          dateNoDst.isBetween(
            start: dateNoDst,
            end: dateNoDst,
            inclusive: true,
          ),
          isTrue,
        );
      });
      test("date is between subtraction and addition", () async {
        expect(
          dateNoDst.isBetween(
            start: dateNoDst.subtract(const Duration(microseconds: 1)),
            end: dateNoDst.add(const Duration(microseconds: 1)),
          ),
          isTrue,
        );
      });
      test("date is not between addition and subtraction", () async {
        expect(
          dateNoDst.isBetween(
            start: dateNoDst.add(const Duration(microseconds: 1)),
            end: dateNoDst.subtract(const Duration(microseconds: 1)),
          ),
          isFalse,
        );
      });
      test("default is not inclusive", () async {
        expect(
          dateNoDst.isBetween(
            start: dateNoDst,
            end: dateNoDst.add(const Duration(microseconds: 1)),
          ),
          isFalse,
        );
      });
    });
    group("min", () {
      final later = dateNoDst.add(const Duration(microseconds: 1));
      final earlier = dateNoDst.subtract(const Duration(microseconds: 1));
      test("returns itself if equal", () async {
        expect(dateNoDst.min(dateNoDst), dateNoDst);
      });
      test("returns itself if earlier", () async {
        expect(dateNoDst.min(later), dateNoDst);
      });
      test("returns other if later", () async {
        expect(dateNoDst.min(earlier), earlier);
      });
    });
    group("max", () {
      final later = dateNoDst.add(const Duration(microseconds: 1));
      final earlier = dateNoDst.subtract(const Duration(microseconds: 1));
      test("returns itself if equal", () async {
        expect(dateNoDst.max(dateNoDst), dateNoDst);
      });
      test("returns itself if later", () async {
        expect(dateNoDst.max(earlier), dateNoDst);
      });
      test("returns other if earlier", () async {
        expect(dateNoDst.max(later), later);
      });
    });
  });
}
