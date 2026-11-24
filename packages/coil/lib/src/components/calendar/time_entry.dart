/// The parts of a time of day a picker edits.
enum TimeSegment {
  /// The hour: 0 to 23, or 1 to 12 with [period].
  hour,

  /// The minute: 0 to 59.
  minute,

  /// AM or PM, in the 12-hour format.
  period,
}

/// An hour of the day (0 to 23) as the 12-hour clock shows it: 1 to 12.
int hourOn12HourClock(int hour) => hour % 12 == 0 ? 12 : hour % 12;

/// The hour of the day (0 to 23) that [hour] (1 to 12) on the 12-hour clock
/// is in the afternoon ([pm]) or the morning.
int hourFrom12HourClock(int hour, {required bool pm}) =>
    hour % 12 + (pm ? 12 : 0);

/// An hour's text: two digits on the 24-hour clock, "2" on the 12-hour one.
String hourText(int hour, {required bool use24HourFormat}) => use24HourFormat
    ? hour.toString().padLeft(2, '0')
    : hourOn12HourClock(hour).toString();

/// A minute's text: two digits.
String minuteText(int minute) => minute.toString().padLeft(2, '0');

/// The minute [steps] steps of [interval] from [minute], wrapping at the
/// hour without carrying into it.
///
/// A minute between steps lands on the next step in the direction it
/// moves: 14 on a 5-minute step goes up to 15 and down to 10.
int stepMinute(int minute, int steps, {required int interval}) {
  final slots = 60 ~/ interval;
  final base = steps >= 0 ? minute ~/ interval : (minute / interval).ceil();
  return ((base + steps) % slots) * interval;
}

/// [minute] on the nearest step of [interval], never past the last step of
/// the hour.
int snapMinute(int minute, {required int interval}) =>
    ((minute / interval).round() * interval).clamp(0, 60 - interval);

/// What a typed `digit` does to a segment that already has `buffer` typed.
///
/// `value` is what the segment shows (null when it doesn't change yet), and
/// `done` says no digit can follow: the next one starts the next segment.
/// A first digit that can't lead a valid two-digit number (3 to 9 for an
/// hour on the 24-hour clock, 2 to 9 on the 12-hour one, 6 to 9 for a
/// minute) is a whole number at once; a second digit that makes an invalid
/// one starts over.
({String buffer, int? value, bool done}) typeDigit(
  String buffer,
  int digit, {
  required TimeSegment segment,
  required bool use24HourFormat,
}) {
  assert(segment != TimeSegment.period, 'The period takes no digits.');
  final isHour = segment == TimeSegment.hour;
  final firstMax = !isHour
      ? 5
      : use24HourFormat
      ? 2
      : 1;
  final max = !isHour
      ? 59
      : use24HourFormat
      ? 23
      : 12;
  final min = isHour && !use24HourFormat ? 1 : 0;
  if (buffer.length == 1) {
    final number = int.parse(buffer) * 10 + digit;
    if (number >= min && number <= max) {
      return (buffer: '', value: number, done: true);
    }
  }
  if (digit > firstMax) return (buffer: '', value: digit, done: true);
  return (buffer: '$digit', value: digit < min ? null : digit, done: false);
}

/// The time that typing [digits] on a number pad gives, starting from [start]
/// (24-hour): the hour first, then the minute, as iOS's time picker takes them
/// ("1", "4", "3", "0" is 14:30).
///
/// On the 12-hour clock the period of [start] stays.
({int hour, int minute}) timeFromDigits(
  String digits, {
  required ({int hour, int minute}) start,
  required bool use24HourFormat,
}) {
  var hour = start.hour;
  var minute = start.minute;
  var typingHour = true;
  var buffer = '';
  for (final unit in digits.codeUnits) {
    final digit = unit - 0x30;
    if (digit < 0 || digit > 9) continue;
    final entry = typeDigit(
      buffer,
      digit,
      segment: typingHour ? TimeSegment.hour : TimeSegment.minute,
      use24HourFormat: use24HourFormat,
    );
    buffer = entry.buffer;
    if (entry.value case final value?) {
      if (typingHour) {
        hour = use24HourFormat
            ? value
            : hourFrom12HourClock(value, pm: start.hour >= 12);
      } else {
        minute = value;
      }
    }
    if (entry.done) {
      if (!typingHour) break;
      typingHour = false;
      buffer = '';
    }
  }
  return (hour: hour, minute: minute);
}

final _pasted = RegExp(r'^(\d{1,2})(?::?(\d{2}))?\s*(?:([ap])\.?m\.?)?$');

/// The time written in `text`: "1430", "14:30", "2:30 pm", "2:30PM", "9".
///
/// Null when it isn't one.
///
/// With am or pm the hour is on the 12-hour clock. Without, an hour of 13
/// or more (or 0) is the 24-hour clock's; on the 12-hour clock an hour of
/// 1 to 12 keeps the period it's in now, `pm`.
({int hour, int minute})? parseTime(
  String text, {
  required bool use24HourFormat,
  required bool pm,
}) {
  final match = _pasted.firstMatch(text.trim().toLowerCase());
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.tryParse(match[2] ?? '0') ?? 0;
  if (minute > 59) return null;
  if (match[3] case final suffix?) {
    if (hour < 1 || hour > 12) return null;
    return (hour: hourFrom12HourClock(hour, pm: suffix == 'p'), minute: minute);
  }
  if (hour > 23) return null;
  if (use24HourFormat || hour == 0 || hour > 12) {
    return (hour: hour, minute: minute);
  }
  return (hour: hourFrom12HourClock(hour, pm: pm), minute: minute);
}

/// What the 12-hour clock calls the morning and the afternoon.
const periodNames = ['AM', 'PM'];
