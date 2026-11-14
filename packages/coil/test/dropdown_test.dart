import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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
        const CoilMenuLabel(Text('File')),
        CoilAction(
          label: const Text('Rename'),
          searchText: 'Rename',
          shortcut: const Text('⌘R'),
          onPressed: () => widget.log.add('rename'),
        ),
        const CoilAction(label: Text('Move'), searchText: 'Move'),
        CoilAction(
          label: const Text('Show grid'),
          searchText: 'Show grid',
          mark: CoilActionMark.check,
          selected: grid,
          onPressed: () {
            widget.log.add('grid');
            setState(() => grid = !grid);
          },
        ),
        for (var i = 0; i < widget.extra; i++)
          CoilAction(
            label: Text('Extra $i'),
            searchText: 'Extra $i',
            onPressed: () {},
          ),
        const CoilMenuSeparator(),
        CoilAction(
          label: const Text('Delete'),
          searchText: 'Delete',
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

  testWidgets('after a checkable pick the menu ignores input until it '
      'closes', (tester) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: _Menu(log: log),
      ),
    );
    await open(tester);
    final colors = CoilThemeData.light.colors;
    Color? colorOf(String label) => tester
        .renderObject<RenderParagraph>(find.text(label))
        .text
        .style
        ?.color;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Show grid')));
    await tester.pumpAndSettle();
    final resting = colorOf('Rename');
    await mouse.down(tester.getCenter(find.text('Show grid')));
    await mouse.up();
    await tester.pump();
    expect(log, ['grid']);

    // The pointer moves to another row: it doesn't light.
    await mouse.moveTo(tester.getCenter(find.text('Rename')));
    // A color change would start on the next frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(colorOf('Rename'), resting, reason: 'no hover after the pick');
    expect(colorOf('Show grid'), colors.foreground);

    // A second click and the keys pick nothing.
    await mouse.down(tester.getCenter(find.text('Rename')));
    await mouse.up();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 60));
    expect(log, ['grid']);

    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing, reason: 'it closed');
  });

  testWidgets("separators are FF's faint hairline: the border token at "
      '60 %', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(testApp(home: const _Menu(log: [])));
    await open(tester);
    final border = CoilThemeData.light.colors.border;
    final lines = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color.a > 0 && box.color.a < 1)
        .map((box) => box.color)
        .toList();
    expect(lines, [border.withValues(alpha: border.a * 0.6)]);
  });

  for (final (name, colors) in [
    ('light', CoilColors.light),
    ('dark', CoilColors.dark),
  ]) {
    testWidgets('open menu, $name', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          colors: colors,
          tier: CoilTier.pointer,
          home: const _Menu(log: []),
        ),
      );
      await open(tester);
      await expectLater(
        find.byKey(appBoundary),
        matchesGoldenFile('goldens/dropdown_open_$name.png'),
      );
    });
  }

  testWidgets('shortcuts show for a pointer, not for touch', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: const _Menu(log: []),
      ),
    );
    await open(tester);
    expect(find.text('⌘R'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: const _Menu(log: []),
      ),
    );
    await open(tester);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('⌘R'), findsNothing);
  });

  testWidgets('on a phone a short menu stays anchored', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: const _Menu(log: []),
      ),
    );
    await open(tester);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.byType(CoilSheetPanel), findsNothing);
  });

  testWidgets('on a phone a long menu opens as a sheet', (tester) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.touch,
        home: const _Menu(log: [], extra: 8),
      ),
    );
    await open(tester);
    expect(find.byType(CoilSheetPanel), findsOneWidget);
  });
}
