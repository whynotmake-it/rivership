import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const datePickerEntry = CatalogEntry(
  slug: 'date-picker',
  title: 'DatePicker',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A field that opens a calendar to pick a date, and a time alongside it '
      'when you need one.',
  page: DatePickerPage.new,
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

String _describe(DateTime date, {bool withTime = false}) {
  final day =
      '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
  if (!withTime) return day;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day, ${date.hour}:$minute';
}

DateTime _at(int daysAhead, int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + daysAhead, hour, minute);
}

enum _Presentation {
  auto('Auto', null),
  popover('Popover', CoilPresentation.popover),
  floating('Panel', CoilPresentation.floating),
  sheet('Sheet', CoilPresentation.sheet);

  const _Presentation(this.label, this.value);

  final String label;
  final CoilPresentation? value;
}

class DatePickerPage extends StatefulWidget {
  const DatePickerPage({super.key});

  @override
  State<DatePickerPage> createState() => _DatePickerPageState();
}

class _DatePickerPageState extends State<DatePickerPage> {
  var _presentation = _Presentation.auto;
  var _withTime = true;
  var _weekdaysOnly = false;
  DateTime? _date = _at(5, 9);

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'DatePicker',
    summary:
        'The calendar opens in a popover next to the field on desktop and '
        'in a floating panel on a phone. Picking a day commits straight away, '
        'and when a time comes with it the panel waits for Done.',
    hero: const _TaskForm(),
    usage: '''
CoilField(
  label: const Text('Due date'),
  child: CoilDatePicker(
    value: due,
    placeholder: const Text('No due date'),
    firstDate: DateTime.now(),
    onChanged: (v) => setState(() => due = v),
  ),
)''',
    notes: const [
      CatalogNote(
        'Pointer',
        'The popover is only as wide as the calendar’s seven cells. A date on '
            'its own commits and closes the popover as you tap it, while with '
            'a time every pick applies right away and Enter or a tap outside '
            'closes it.',
      ),
      CatalogNote(
        'Touch',
        'On a phone it opens a floating panel whose footer names the date you '
            'have drafted so far and keeps Done in view. The close button, the '
            'scrim, a swipe sideways or down and the back gesture all cancel.',
      ),
      CatalogNote(
        'Keyboard',
        'Everything the calendar supports works here, and on top of that '
            'Enter confirms the pick, Esc closes without changing the '
            'value, and Space picks a day without closing.',
      ),
      CatalogNote(
        'Accessibility',
        'The hour and minute are announced as adjustable, so a screen reader '
            'user can swipe up or down to change the time instead of scrolling '
            'or typing.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Presentation',
              value: _presentation,
              values: _Presentation.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _presentation = v),
            ),
            DemoControl.toggle(
              label: 'With time',
              value: _withTime,
              onChanged: (v) => setState(() => _withTime = v),
            ),
            DemoControl.toggle(
              label: 'Weekdays only',
              value: _weekdaysOnly,
              onChanged: (v) => setState(() => _weekdaysOnly = v),
            ),
          ],
        ),
        child: CoilField(
          label: const Text('Interview'),
          description: Text(
            _date == null
                ? 'Nothing scheduled.'
                : 'Scheduled for ${_describe(_date!, withTime: _withTime)}.',
          ),
          child: CoilDatePicker(
            value: _date,
            withTime: _withTime,
            minuteInterval: 15,
            placeholder: const Text('Not scheduled'),
            icon: const CatalogIcon(Glyph.calendar),
            presentation: _presentation.value,
            sheetTitle: const Text('Interview'),
            firstDate: DateTime.now(),
            isDisabled: _weekdaysOnly
                ? (day) => day.weekday >= DateTime.saturday
                : null,
            onChanged: (v) => setState(() => _date = v),
          ),
        ),
      ),
    ],
  );
}

/// A new task: a title, when it's due, when work starts and a reminder.
class _TaskForm extends StatefulWidget {
  const _TaskForm();

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _title = TextEditingController(text: 'Write release notes');
  DateTime? _due = _at(3, 17);
  DateTime? _starts = _at(1, 9, 30);
  DateTime? _reminder;
  String? _created;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _create() => setState(() {
    final due = _due;
    _created = due == null
        ? '“${_title.text}” added with no due date.'
        : '“${_title.text}” added, due ${_describe(due)}.';
  });

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('New task', style: text.title),
        const SizedBox(height: 16),
        DemoColumn(
          children: [
            CoilField(
              label: const Text('Title'),
              child: CoilInput(
                controller: _title,
                placeholder: const Text('What needs doing?'),
                onChanged: (_) => setState(() => _created = null),
              ),
            ),
            CoilField(
              label: const Text('Due date'),
              child: CoilDatePicker(
                value: _due,
                placeholder: const Text('No due date'),
                icon: const CatalogIcon(Glyph.calendar),
                firstDate: DateTime.now(),
                onChanged: (v) => setState(() {
                  _due = v;
                  _created = null;
                }),
              ),
            ),
            CoilField(
              label: const Text('Starts'),
              child: CoilDatePicker(
                value: _starts,
                withTime: true,
                minuteInterval: 15,
                placeholder: const Text('Not scheduled'),
                icon: const CatalogIcon(Glyph.calendar),
                sheetTitle: const Text('Starts'),
                firstDate: DateTime.now(),
                onChanged: (v) => setState(() {
                  _starts = v;
                  _created = null;
                }),
              ),
            ),
            CoilField(
              label: const Text('Reminder'),
              child: CoilDatePicker(
                value: _reminder,
                withTime: true,
                minuteInterval: 15,
                placeholder: const Text('No reminder'),
                icon: const CatalogIcon(Glyph.bell),
                presentation: CoilPresentation.sheet,
                sheetTitle: const Text('Reminder'),
                firstDate: DateTime.now(),
                onChanged: (v) => setState(() {
                  _reminder = v;
                  _created = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          spacing: 12,
          children: [
            CoilButton(onPressed: _create, child: const Text('Create task')),
            if (_created case final created?)
              Expanded(child: Text(created, style: text.muted.caption)),
          ],
        ),
      ],
    );
  }
}
