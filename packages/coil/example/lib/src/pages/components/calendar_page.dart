import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const calendarEntry = CatalogEntry(
  slug: 'calendar',
  title: 'Calendar',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A month grid where the selection glides to the day you pick, and the '
      'whole month is reachable from the keyboard.',
  page: CalendarPage.new,
);

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dayName(DateTime day) =>
    '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime? _day;
  var _weekends = true;
  var _booked = false;
  var _window = false;
  var _compact = false;

  bool _isDisabled(DateTime day) =>
      (_weekends && day.weekday >= DateTime.saturday) ||
      (_booked && day.day % 5 == 0);

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final today = _today();
    return CatalogPage(
      title: 'Calendar',
      summary:
          'Pick a day and everything that depends on it updates. You can '
          'swipe or use the arrows to page through months, and tapping the '
          'month name zooms out so you can jump across years.',
      hero: const _Booking(),
      usage: '''
CoilCalendar(
  selected: day,
  firstDate: DateTime.now(),
  isDisabled: (day) => day.weekday >= DateTime.saturday,
  onSelected: (picked) => setState(() => day = picked),
)''',
      notes: const [
        CatalogNote(
          'Keyboard',
          'The grid takes a single tab stop. The arrow keys move by a day or '
              'a week, Home and End go to the ends of the week, and PageUp '
              'and PageDown change the month, or the year with Shift held. '
              'Enter picks the day and submits, while Space only picks it.',
        ),
        CatalogNote(
          'Touch',
          'Swiping pages through the months, following your finger and '
              'keeping the momentum of a fling. Every day takes the tap on '
              'its whole cell, and the cells stay square at any width.',
        ),
        CatalogNote(
          'Motion',
          'The title zooms out to a year of months and back on the standard '
              'spring. The grid always draws six rows, so its height never '
              'jumps as you move between months.',
        ),
        CatalogNote(
          'Accessibility',
          'Each cell is labelled with its full date, the previous and next '
              'month are exposed as actions, and the title is a button that '
              'reads as "November 2026".',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          description:
              'The app decides which days are disabled and how far the '
              'pickable window reaches, and the calendar only draws what it '
              'is given.',
          controls: DemoControls(
            children: [
              DemoControl.toggle(
                label: 'No weekends',
                value: _weekends,
                onChanged: (v) => setState(() => _weekends = v),
              ),
              DemoControl.toggle(
                label: 'Booked days',
                value: _booked,
                onChanged: (v) => setState(() => _booked = v),
              ),
              DemoControl.toggle(
                label: 'Next 30 days',
                value: _window,
                onChanged: (v) => setState(() => _window = v),
              ),
              DemoControl.toggle(
                label: 'Compact',
                value: _compact,
                onChanged: (v) => setState(() => _compact = v),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                CoilAdaptiveScope(
                  size: _compact ? CoilSize.compact : CoilSize.regular,
                  child: CoilCalendar(
                    selected: _day,
                    firstDate: _window ? today : null,
                    lastDate: _window
                        ? today.add(const Duration(days: 30))
                        : null,
                    isDisabled: _isDisabled,
                    onSelected: (day) => setState(() => _day = day),
                  ),
                ),
                Text(
                  _day == null ? 'No day picked' : _dayName(_day!),
                  style: text.muted.caption,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A call booking: the calendar on one side, the picked day's open times
/// on the other.
class _Booking extends StatefulWidget {
  const _Booking();

  @override
  State<_Booking> createState() => _BookingState();
}

class _BookingState extends State<_Booking> {
  static const _times = [
    '9:00',
    '9:30',
    '10:30',
    '11:00',
    '13:00',
    '13:30',
    '14:30',
    '15:00',
    '16:00',
  ];

  final _now = _today();
  late DateTime _day = _nextOpen(_now);
  String? _time;
  String? _booked;

  static bool _closed(DateTime day) => day.weekday >= DateTime.saturday;

  static DateTime _nextOpen(DateTime from) {
    var day = from;
    while (_closed(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  /// Some times are always taken, differently each day.
  bool _taken(String time) => (_times.indexOf(time) + _day.day) % 3 == 0;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).gap;
    final calendar = CoilCalendar(
      selected: _day,
      firstDate: _now,
      lastDate: _now.add(const Duration(days: 90)),
      isDisabled: _closed,
      onSelected: (day) => setState(() {
        _day = day;
        _time = null;
        _booked = null;
      }),
    );
    final slots = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dayName(_day),
          style: text.subtitle.copyWith(fontWeight: text.emphasis),
        ),
        const SizedBox(height: 2),
        Text('30 minute call, your time zone', style: text.muted.caption),
        const SizedBox(height: 12),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final time in _times)
              CoilButton(
                variant: CoilButtonVariant.secondary,
                size: CoilSize.compact,
                selected: _time == time,
                onPressed: _taken(time)
                    ? null
                    : () => setState(() {
                        _time = time;
                        _booked = null;
                      }),
                child: Text(time),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          spacing: 12,
          children: [
            CoilButton(
              onPressed: _time == null
                  ? null
                  : () => setState(() => _booked = _time),
              child: const Text('Book call'),
            ),
            if (_booked != null)
              Expanded(
                child: Text(
                  'Booked for ${_dayName(_day)} at $_booked.',
                  style: text.muted.caption,
                ),
              ),
          ],
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                calendar,
                Expanded(child: slots),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Center(child: calendar),
                slots,
              ],
            ),
    );
  }
}
