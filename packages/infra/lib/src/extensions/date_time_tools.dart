/// Useful helper methods on [DateTime]
extension DateTimeTools on DateTime {
  /// Returns the start of the day, which is 00:00:00.000.000
  DateTime startOfDay() {
    return DateTime(year, month, day);
  }

  /// Returns the end of the day, which is 23:59:59.999.999
  DateTime endOfDay() {
    return DateTime(year, month, day, 23, 59, 59, 999, 999);
  }

  /// Returns the first day of this week, defaults to monday.
  /// >[!warning] [day] is 1-indexed (1 == Monday)
  ///
  /// Time is at 00:00:00.000.000
  DateTime firstDayOfWeek([int day = DateTime.monday]) {
    final daysToSubtractFromMonday = (DateTime.monday - day) % 7;
    return addDaysSameTime(-weekday + 1)
        .addDaysSameTime(-daysToSubtractFromMonday)
        .startOfDay();
  }

  /// Adds days while keeping the same time, even if daylight saving time
  /// is crossed
  DateTime addDaysSameTime(int days) {
    return DateTime(
      year,
      month,
      day + days,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
  }

  /// Returns all the days in between this and [other], including this.
  ///
  /// If [inclusive] is true, [other] is included as well.
  /// Days are returned in chronological order and times are removed
  /// (see [startOfDay])
  Iterable<DateTime> getDaysUntil(
    DateTime other, {
    bool inclusive = false,
  }) sync* {
    var date = startOfDay();
    final endDate = other.startOfDay();
    while (date.isBefore(endDate) || (inclusive && date.isSameDayAs(endDate))) {
      yield date;
      date = date.addDaysSameTime(1);
    }
  }

  /// Returns a new [DateTime] with the time from [time] and the date from this
  DateTime withTimeFrom(DateTime time) {
    return DateTime(
      year,
      month,
      day,
      time.hour,
      time.minute,
      time.second,
      time.millisecond,
      time.microsecond,
    );
  }

  /// Returns this if's on the same day or on a later day than [other],
  /// otherwise [other] is returned.
  DateTime earlierDay(DateTime other) {
    if (other.startOfDay().isBefore(startOfDay())) return other;
    return this;
  }

  /// Returns this if's on the same day or on an earlier day than [other],
  /// otherwise [other] is returned.
  DateTime laterDay(DateTime other) {
    if (other.startOfDay().isAfter(startOfDay())) return other;
    return this;
  }

  /// Returns the number of days until [other].
  ///
  /// If [inclusive] is true, [other] is included in the calculation.
  int daysUntil(DateTime other, {bool inclusive = false}) {
    final diff = other.startOfDay().difference(startOfDay()).inDays;
    return (inclusive ? 1 : 0) * diff.sign + diff;
  }

  /// Returns true if this is on the same day as [other].
  bool isSameDayAs(DateTime other) {
    return other.day == day && other.month == month && other.year == year;
  }

  /// Returns true if this is on the same day as today.
  bool get isToday {
    final now = DateTime.now();
    return isSameDayAs(now);
  }

  /// Returns true if this is between [start] and [end].
  ///
  /// If [inclusive] is true, [start] and [end] are included in the calculation.
  bool isBetween({
    required DateTime start,
    required DateTime end,
    bool inclusive = false,
  }) {
    return isBefore(end) && isAfter(start) ||
        (inclusive && (isAtSameMomentAs(start) || isAtSameMomentAs(end)));
  }

  /// Returns the earlier date between this and [other].
  DateTime min(DateTime other) {
    if (other.isBefore(this)) return other;
    return this;
  }

  /// Returns the later date between this and [other].
  DateTime max(DateTime other) {
    if (other.isAfter(this)) return other;
    return this;
  }
}
