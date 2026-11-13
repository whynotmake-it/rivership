import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

class _Menu extends StatefulWidget {
  const _Menu({required this.log, this.extra = 0});

  final List<String> log;

  /// Extra rows, to make the menu long.
  final int extra;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  bool grid = false;

  @override
  Widget build(BuildContext context) => Center(
    child: CoilDropdown(
      entries: [
        const CoilMenuLabel('File'),
        CoilAction(
          label: 'Rename',
          shortcut: const Text('⌘R'),
          onPressed: () => widget.log.add('rename'),
        ),
        const CoilAction(label: 'Move'),
        CoilAction(
          label: 'Show grid',
          mark: CoilActionMark.check,
          selected: grid,
          onPressed: () {
            widget.log.add('grid');
            setState(() => grid = !grid);
          },
        ),
        for (var i = 0; i < widget.extra; i++)
          CoilAction(label: 'Extra $i', onPressed: () {}),
        const CoilMenuSeparator(),
        CoilAction(
          label: 'Delete',
          tone: CoilActionTone.destructive,
          onPressed: () => widget.log.add('delete'),
        ),
      ],
      builder: (context, menu) => CoilButton(
        onPressed: menu.open,
        child: const Text('Actions'),
      ),
    ),
  );
}

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
  }

  testWidgets('arrows skip headings, separators and disabled rows', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(testApp(home: _Menu(log: log)));
    await open(tester);
    // Down from the top lands on Rename, then skips the disabled Move.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['delete']);
    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('a checkable row shows its mark, then closes the menu', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(testApp(home: _Menu(log: log)));
    await open(tester);
    await tester.tap(find.text('Show grid'));
    await tester.pump();
    expect(log, ['grid']);
    // Still open while the mark lands.
    expect(find.text('Show grid'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('Show grid'))
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      isNotNull,
    );
    await tester.pumpAndSettle();
    expect(find.text('Show grid'), findsNothing);
  });

  testWidgets('shortcuts show for a pointer, not for touch', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _Menu(log: [])),
    );
    await open(tester);
    expect(find.text('⌘R'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: const _Menu(log: [])),
    );
    await open(tester);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('⌘R'), findsNothing);
  });

  testWidgets('on a phone a short menu stays anchored', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: const _Menu(log: [])),
    );
    await open(tester);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.byType(CoilSheetPanel), findsNothing);
  });

  testWidgets('on a phone a long menu opens as a sheet', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(tier: CoilTier.touch, home: const _Menu(log: [], extra: 8)),
    );
    await open(tester);
    expect(find.byType(CoilSheetPanel), findsOneWidget);
  });
}
