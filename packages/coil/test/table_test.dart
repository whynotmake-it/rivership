import 'dart:ui' show Tristate;

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

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
  double textScale = 1,
  CoilThemeData theme = CoilThemeData.light,
}) => MediaQuery(
  data: MediaQueryData(
    disableAnimations: reducedMotion,
    textScaler: TextScaler.linear(textScale),
  ),
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

  testWidgets('an empty table is as tall as one with its rows of data', (
    tester,
  ) async {
    Future<double> height(List<_Person> rows) async {
      await tester.pumpWidget(
        _app(
          textScale: 2,
          CoilTable<_Person>(
            columns: _columns(),
            rows: rows,
            emptyRows: 4,
            empty: const Text('No people yet'),
          ),
        ),
      );
      return tester.getSize(find.byType(CoilTable<_Person>)).height;
    }

    final empty = await height(const []);
    expect(find.text('No people yet'), findsOneWidget);
    expect(empty, await height(_people));
  });

  testWidgets('after a sort the active row and selection stay on their data', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var rows = _people;
    var values = <_Person>{};
    final opened = <String>[];
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CoilTable<_Person>(
              columns: _columns(),
              rows: rows,
              values: values,
              onChanged: (v) => setState(() => values = v),
              onRowActivated: (p) => opened.add(p.name),
            );
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(values.map((p) => p.name), {'Grace'});

    // Name, descending: Margaret, Linus, Grace, Ada.
    rebuild(
      () => rows = [..._people]..sort((a, b) => b.name.compareTo(a.name)),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, ['Grace']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened.last, 'Ada');

    var row = tester.getSemantics(find.text('Grace'));
    while (row.getSemanticsData().role != SemanticsRole.row) {
      row = row.parent!;
    }
    expect(row.flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('per-track motions apply to the next animation', (
    tester,
  ) async {
    Map<CoilTableTrack<Object>, Motion>? motions;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CoilTable<_Person>(
              columns: _columns(),
              rows: _people,
              motions: motions,
            );
          },
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final colors = CoilThemeData.light.colors;

    // How far Ada's label has gone from muted to foreground, 0 to 1, a
    // short while into a hover.
    Future<double> progress() async {
      await mouse.moveTo(tester.getCenter(find.text('Ada')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final color = DefaultTextStyle.of(
        tester.element(find.text('Ada')),
      ).style.color!;
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      final span = colors.foreground.r - colors.mutedForeground.r;
      return (color.r - colors.mutedForeground.r) / span;
    }

    final fast = await progress();
    rebuild(
      () => motions = {
        CoilTableTrack.rowLabel: const Motion.linear(Duration(seconds: 2)),
      },
    );
    await tester.pump();
    final slow = await progress();
    expect(fast, greaterThan(0));
    expect(slow, lessThan(fast / 2));
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
