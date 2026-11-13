import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/coil_pattern.dart';
import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';

typedef _Person = ({String name, String role, int commits});

const _people = <_Person>[
  (name: 'Ada', role: 'Engineer', commits: 1204),
  (name: 'Grace', role: 'Admiral', commits: 87),
  (name: 'Linus', role: 'Maintainer', commits: 33012),
  (name: 'Margaret', role: 'Director', commits: 410),
];

List<CoilTableColumn<_Person>> _columns({
  CoilSortDirection? sort,
  VoidCallback? onSort,
  double minWidth = 96,
}) => [
  CoilTableColumn(
    label: 'Name',
    sort: sort,
    onSort: onSort,
    minWidth: minWidth,
    cellBuilder: (context, p) => Text(p.name),
  ),
  CoilTableColumn(
    label: 'Role',
    minWidth: minWidth,
    cellBuilder: (context, p) => Text(p.role),
  ),
  CoilTableColumn(
    label: 'Commits',
    width: 104,
    alignment: AlignmentDirectional.centerEnd,
    cellBuilder: (context, p) => Text('${p.commits}'),
  ),
];

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
  double width = 360,
  CoilThemeData theme = CoilThemeData.light,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: WidgetsApp(
    // A fresh app per pump: the route would keep the first child.
    key: UniqueKey(),
    color: const Color(0xFF000000),
    builder: (context, navigator) => Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: theme.copyWith(tier: tier),
        child: navigator!,
      ),
    ),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

/// A table that applies its own selection.
class _Host extends StatefulWidget {
  const _Host({this.onActivated});

  final ValueChanged<_Person>? onActivated;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Set<_Person> values = {};

  @override
  Widget build(BuildContext context) => CoilTable<_Person>(
    columns: _columns(),
    rows: _people,
    values: values,
    onChanged: (v) => setState(() => values = v),
    onRowActivated: widget.onActivated,
  );
}

CoilHoverState? _hover(WidgetTester tester) =>
    CoilHoverRegion.maybeOf(tester.element(find.text('Ada')));

void main() {
  matrixGoldenTest(
    'table',
    (context) => SizedBox(
      width: 340,
      child: CoilTable<_Person>(
        columns: _columns(sort: CoilSortDirection.ascending, onSort: () {}),
        rows: _people.take(3).toList(),
        values: {_people[1]},
        onChanged: (_) {},
      ),
    ),
  );

  testWidgets('table states sheet', (tester) async {
    final scrolled = ScrollController(initialScrollOffset: 40);
    addTearDown(scrolled.dispose);
    final sheet = await pumpSheet(
      tester,
      ThemedPair(
        title: 'table: hovered + merged selection, scrolled, empty',
        direction: Axis.vertical,
        builder: (context) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 24,
          children: [
            SizedBox(
              width: 340,
              child: CoilTable<_Person>(
                columns: _columns(),
                rows: _people,
                values: {_people[0], _people[1]},
                onChanged: (_) {},
              ),
            ),
            SizedBox(
              width: 220,
              child: CoilTable<_Person>(
                columns: _columns(minWidth: 120),
                rows: _people.take(3).toList(),
                controller: CoilTheme.of(context).brightness == Brightness.light
                    ? scrolled
                    : null,
              ),
            ),
            SizedBox(
              width: 260,
              child: CoilTable<_Person>(
                columns: _columns(),
                rows: const [],
                empty: const Text('No people yet'),
              ),
            ),
          ],
        ),
      ),
      surface: const Size(1000, 760),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Linus').first));
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/table.png');
  });

  inkCenteringTests({
    'table/header': (ink) => CoilTable<int>(
      columns: [
        CoilTableColumn(
          label: 'HEH',
          child: InkLabel(ink, const Text('HEH')),
          cellBuilder: (context, row) => Text('$row'),
        ),
      ],
      rows: const [],
      emptyRows: 0,
    ),
  });

  testWidgets('table pattern (LTR and RTL)', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(_app(direction: direction, const _Host()));
      await expectCoilPattern(
        tester,
        find.byType(CoilTable<_Person>),
        CoilPattern.table,
      );
    }
  });

  testWidgets('Enter opens the active row; a tap opens the tapped row', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _app(_Host(onActivated: (p) => opened.add(p.name))),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, ['Linus'], reason: 'Tab lands on Ada; Down twice');
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened.last, 'Margaret');

    await tester.tap(find.text('Grace'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opened.last, 'Grace');
  });

  testWidgets('without onRowActivated a tap toggles the row', (tester) async {
    await tester.pumpWidget(_app(const _Host()));
    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.values.map((p) => p.name), {'Grace', 'Ada'});
    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(host.values.map((p) => p.name), {'Ada'});
  });

  testWidgets('touch presses a row and leaves no highlight; a mouse hovers', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tier: CoilTier.touch, const _Host()));
    final touch = await tester.startGesture(tester.getCenter(find.text('Ada')));
    await tester.pump(const Duration(milliseconds: 150));
    final detector = tester.widget<CoilInteractionDetector>(
      find
          .ancestor(
            of: find.text('Ada'),
            matching: find.byType(CoilInteractionDetector),
          )
          .first,
    );
    expect(detector.states.value, contains(WidgetState.pressed));
    await touch.up();
    await tester.pumpAndSettle();
    expect(detector.states.value, isEmpty);
    expect(_hover(tester)!.activeIndex, isNull);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Linus')));
    await tester.pumpAndSettle();
    expect(_hover(tester)!.activeIndex, 2);
  });

  testWidgets('a sortable header is a pressable column header', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var sorts = 0;
    await tester.pumpWidget(
      _app(
        CoilTable<_Person>(
          columns: _columns(
            sort: CoilSortDirection.descending,
            onSort: () => sorts++,
          ),
          rows: _people,
        ),
      ),
    );
    await tester.tap(find.text('Name'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(sorts, 1);
    expect(
      tester.getSemantics(find.text('Name')),
      matchesSemantics(
        label: 'Name',
        value: 'Sorted descending',
        isButton: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a narrow table scrolls sideways; arrows spring it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(width: 200, const _Host()));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(scrollable.position.pixels, inExclusiveRange(0, 60));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 60);
  });

  testWidgets('reduced motion makes keyboard scrolls instant', (tester) async {
    await tester.pumpWidget(
      _app(width: 200, reducedMotion: true, const _Host()),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, 60);
  });

  testWidgets('the empty state holds its rows of height', (tester) async {
    await tester.pumpWidget(
      _app(
        CoilTable<_Person>(
          columns: _columns(),
          rows: const [],
          emptyRows: 4,
          empty: const Text('No people yet'),
        ),
      ),
    );
    expect(find.text('No people yet'), findsOneWidget);
    // A 36 header and four 36 rows (pointer).
    expect(tester.getSize(find.byType(CoilTable<_Person>)).height, 36 * 5);
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    const themed = Color(0xFF00FF00);
    const instance = Color(0xFFFF0000);
    Color headerColor() => tester
        .widget<RichText>(
          find.descendant(
            of: find.text('Role'),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!
        .color!;
    Widget table({CoilTableStyle? style}) => CoilTable<_Person>(
      columns: _columns(),
      rows: _people,
      style: style,
    );

    await tester.pumpWidget(_app(table()));
    await tester.pumpAndSettle();
    expect(headerColor(), CoilThemeData.light.colors.mutedForeground);

    final theme = CoilThemeData.light.withComponentStyle(
      const CoilTableStyle(headerLabel: WidgetStatePropertyAll(themed)),
    );
    await tester.pumpWidget(_app(theme: theme, table()));
    await tester.pumpAndSettle();
    expect(headerColor(), themed);

    await tester.pumpWidget(
      _app(
        theme: theme,
        table(
          style: const CoilTableStyle(
            headerLabel: WidgetStatePropertyAll(instance),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(headerColor(), instance);
  });
}
