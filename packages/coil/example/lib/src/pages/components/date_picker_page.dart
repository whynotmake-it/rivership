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
    summary: 'A popover next to the field; a sheet on a phone.',
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
    ],
  );
}
