// CoilRovingFocus's keys: one tab stop, arrows move along the axis (flipped
// in RTL), Home and End jump, and wrapping is opt-in.
import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<FocusNode> nodes;

  setUp(() => nodes = List.generate(3, (i) => FocusNode(debugLabel: '$i')));
  tearDown(() {
    for (final node in nodes) {
      node.dispose();
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    int? tabStop,
    bool wrap = false,
    TextDirection direction = TextDirection.ltr,
    CoilRovingTabStops tabStops = CoilRovingTabStops.one,
  }) => tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      onGenerateRoute: (_) => PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => Directionality(
          textDirection: direction,
          child: Column(
            children: [
              CoilRovingFocus(
                nodes: nodes,
                tabStop: tabStop,
                wrap: wrap,
                tabStops: tabStops,
                child: Row(
                  children: [
                    for (final node in nodes)
                      Focus(
                        focusNode: node,
                        child: const SizedBox.square(dimension: 10),
                      ),
                  ],
                ),
              ),
              const Focus(debugLabel: 'after', child: SizedBox(height: 10)),
            ],
          ),
        ),
      ),
    ),
  );

  int? focused() {
    final index = nodes.indexWhere((n) => n.hasPrimaryFocus);
    return index < 0 ? null : index;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('Tab reaches only the tab stop, then leaves the group', (
    tester,
  ) async {
    await pump(tester, tabStop: 1);
    await press(tester, LogicalKeyboardKey.tab);
    expect(focused(), 1);
    await press(tester, LogicalKeyboardKey.tab);
    expect(focused(), isNull);
  });

  testWidgets('arrows move, Home and End jump, the ends stop', (
    tester,
  ) async {
    await pump(tester);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 1);
    await press(tester, LogicalKeyboardKey.end);
    expect(focused(), 2);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 2);
    await press(tester, LogicalKeyboardKey.home);
    expect(focused(), 0);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 0);
  });

  testWidgets('wrap goes round', (tester) async {
    await pump(tester, wrap: true);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 2);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 0);
  });

  testWidgets('RTL flips the horizontal arrows', (tester) async {
    await pump(tester, direction: TextDirection.rtl);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 1);
  });

  testWidgets('with a tab stop on each item, Tab visits every one', (
    tester,
  ) async {
    await pump(tester, tabStops: CoilRovingTabStops.each);
    for (final index in [0, 1, 2]) {
      await press(tester, LogicalKeyboardKey.tab);
      expect(focused(), index);
    }
  });

  testWidgets('gives back the Tab stops it took', (tester) async {
    Widget group(List<FocusNode> nodes, CoilRovingTabStops tabStops) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: CoilRovingFocus(
            nodes: nodes,
            tabStop: 0,
            tabStops: tabStops,
            child: Row(
              children: [
                for (final node in nodes)
                  Focus(
                    focusNode: node,
                    child: const SizedBox.square(dimension: 10),
                  ),
              ],
            ),
          ),
        );
    List<bool> skipped() => [for (final n in nodes) n.skipTraversal];

    await tester.pumpWidget(group(nodes, CoilRovingTabStops.one));
    expect(skipped(), [false, true, true]);

    // Switching to a stop on each item reaches every one again.
    await tester.pumpWidget(group(nodes, CoilRovingTabStops.each));
    expect(skipped(), [false, false, false]);

    // A node dropped from the group is the caller's again.
    await tester.pumpWidget(group(nodes, CoilRovingTabStops.one));
    await tester.pumpWidget(group(nodes.take(2).toList(), .one));
    expect(skipped(), [false, true, false]);

    // And the group going away gives all of them back.
    await tester.pumpWidget(const SizedBox());
    expect(skipped(), [false, false, false]);
  });

  testWidgets('an arrow a nested group leaves alone moves the outer group', (
    tester,
  ) async {
    // A vertical list of rows; the first row holds a horizontal group.
    final rows = List.generate(2, (i) => FocusNode(debugLabel: 'row $i'));
    final field = FocusNode(debugLabel: 'field');
    addTearDown(() {
      for (final node in [...rows, field]) {
        node.dispose();
      }
    });
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          pageBuilder: (context, _, _) => CoilRovingFocus(
            nodes: rows,
            tabStop: 0,
            axis: Axis.vertical,
            child: Column(
              children: [
                Focus(
                  focusNode: rows[0],
                  child: CoilRovingFocus(
                    nodes: nodes,
                    tabStop: 0,
                    child: Row(
                      children: [
                        for (final node in nodes)
                          Focus(
                            focusNode: node,
                            child: const SizedBox.square(dimension: 10),
                          ),
                        // Not an item: its arrows stay with it.
                        Focus(
                          focusNode: field,
                          child: const SizedBox.square(dimension: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                Focus(
                  focusNode: rows[1],
                  child: const SizedBox(height: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nodes[0].requestFocus();
    await tester.pump();

    // Right stays in the inner group.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 1);
    expect(rows[1].hasFocus, isFalse);

    // Down isn't the inner group's: the outer group moves to the next row.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(rows[1].hasPrimaryFocus, isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(rows[0].hasPrimaryFocus, isTrue);

    // Focus inside a row that isn't a nested item keeps its arrows.
    field.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(field.hasPrimaryFocus, isTrue);
  });
}
