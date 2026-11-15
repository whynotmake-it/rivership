import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const calendarEntry = CatalogEntry(
  slug: 'calendar',
  title: 'Calendar',
  group: CatalogGroup.shellAndComposites,
  summary: 'A month grid with a gliding selection and full keyboard.',
  page: CalendarPage.new,
);

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime? _day;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Calendar',
    summary:
        'Arrows move a day or a week, PageUp and PageDown a month, with '
        'Shift a year. Weekends are disabled here.',
    children: [
      DemoSection(
        title: 'Single day',
        child: DemoStage(
          child: CoilCalendar(
            selected: _day,
            isDisabled: (day) => day.weekday >= DateTime.saturday,
            onSelected: (day) => setState(() => _day = day),
          ),
        ),
      ),
    ],
  );
}
