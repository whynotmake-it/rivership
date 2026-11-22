import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const datePickerEntry = CatalogEntry(
  slug: 'date-picker',
  title: 'DatePicker',
  group: CatalogGroup.shellAndComposites,
  summary: 'A field that opens a calendar, with an optional time.',
  page: DatePickerPage.new,
);

class DatePickerPage extends StatefulWidget {
  const DatePickerPage({super.key});

  @override
  State<DatePickerPage> createState() => _DatePickerPageState();
}

class _DatePickerPageState extends State<DatePickerPage> {
  DateTime? _date;
  DateTime? _meeting;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'DatePicker',
    summary:
        'A popover next to the field that hugs the calendar; a floating '
        'panel on a phone, where the calendar fills the width. A day alone '
        'commits on the tap in a popover; with a time, and in a panel, Done '
        'confirms and anything else cancels. Scroll the months, tap the '
        'month to zoom out to the years, and flick the time columns.',
    children: [
      DemoSection(
        title: 'Date',
        child: CoilField(
          label: const Text('Due'),
          child: CoilDatePicker(
            value: _date,
            onChanged: (v) => setState(() => _date = v),
          ),
        ),
      ),
      DemoSection(
        title: 'Date and time',
        child: CoilField(
          label: const Text('Meeting'),
          child: CoilDatePicker(
            value: _meeting,
            withTime: true,
            minuteInterval: 15,
            onChanged: (v) => setState(() => _meeting = v),
          ),
        ),
      ),
      DemoSection(
        title: 'Always a sheet',
        child: CoilField(
          label: const Text('Reminder'),
          child: CoilDatePicker(
            value: _meeting,
            withTime: true,
            presentation: CoilPresentation.sheet,
            sheetTitle: const Text('Reminder'),
            onChanged: (v) => setState(() => _meeting = v),
          ),
        ),
      ),
    ],
  );
}
