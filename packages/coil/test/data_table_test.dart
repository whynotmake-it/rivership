import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

typedef _Person = ({String name, int age});

const _people = <_Person>[
  (name: 'Ada', age: 36),
  (name: 'Grace', age: 85),
  (name: 'Alan', age: 41),
];

CoilDataTableController<_Person> _controller({int pageSize = 0}) =>
    CoilDataTableController(
      rows: _people,
      pageSize: pageSize,
      matches: (person, query) => person.name.toLowerCase().contains(query),
    );

void main() {
  group('controller', () {
    test('filters by the query and sorts both ways', () {
      final c = _controller();
      int byAge(_Person a, _Person b) => a.age.compareTo(b.age);
      c.sortBy(1, byAge);
      expect(c.view.map((p) => p.name), ['Ada', 'Alan', 'Grace']);
      c.sortBy(1, byAge);
      expect(c.view.map((p) => p.name), ['Grace', 'Alan', 'Ada']);
      c.query = 'a';
      expect(c.view.map((p) => p.name), ['Grace', 'Alan', 'Ada']);
      c.query = 'al';
      expect(c.view.map((p) => p.name), ['Alan']);
    });

    test('pages, and a new query goes back to the first page', () {
      final c = _controller(pageSize: 2);
      expect(c.pageCount, 2);
      c.page = 1;
      expect(c.view.map((p) => p.name), ['Alan']);
      c.query = 'a';
      expect(c.page, 0);
    });

    test('new rows drop selections that are gone', () {
      final c = _controller()
        ..selected = {_people.first, _people.last}
        ..rows = _people.sublist(1);
      expect(c.selected, {_people.last});
    });
  });

  testWidgets('a sortable header sorts, and selecting shows the count', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: Padding(
          padding: const EdgeInsets.all(16),
          child: CoilDataTable<_Person>(
            controller: controller,
            columns: [
              CoilDataColumn(
                label: 'Name',
                cellBuilder: (context, p) => Text(p.name),
                compare: (a, b) => a.name.compareTo(b.name),
              ),
              CoilDataColumn(
                label: 'Age',
                cellBuilder: (context, p) => Text('${p.age}'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('3 rows'), findsOneWidget);
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(controller.view.first.name, 'Ada');
    expect(
      tester.getTopLeft(find.text('Ada')).dy,
      lessThan(tester.getTopLeft(find.text('Alan')).dy),
    );
    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 selected'), findsOneWidget);
  });
}
