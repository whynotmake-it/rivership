import 'dart:ui';

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _menu(List<String> log) => Align(
  alignment: const Alignment(-0.8, -0.8),
  child: CoilDropdown(
    entries: [
      CoilAction(
        label: const Text('Open'),
        searchText: 'Open',
        onPressed: () => log.add('open'),
      ),
      CoilSubmenu(
        label: const Text('Share'),
        searchText: 'Share',
        entries: [
          CoilAction(
            label: const Text('Email'),
            searchText: 'Email',
            onPressed: () => log.add('email'),
          ),
          CoilAction(
            label: const Text('Message'),
            searchText: 'Message',
            onPressed: () => log.add('message'),
          ),
        ],
      ),
      CoilAction(
        label: const Text('Delete'),
        searchText: 'Delete',
        onPressed: () => log.add('delete'),
      ),
    ],
    builder: (context, menu) =>
        CoilButton(onPressed: menu.open, child: const Text('Actions')),
  ),
);

void main() {
  testWidgets('hovering a submenu row opens it beside the menu, and the '
      'pointer can cross other rows on the way', (tester) async {
    useScreen(tester, TestScreen.desktop);
    tester.view.physicalSize = const Size(1600, 1000);
    final log = <String>[];
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu(log)));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Share')));
    await tester.pump();
    expect(find.text('Email'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final share = tester.getRect(find.text('Share'));
    expect(tester.getTopLeft(find.text('Email')).dx, greaterThan(share.right));

    // Diagonally down toward the submenu, over the Delete row.
    final email = tester.getCenter(find.text('Email'));
    final delete = tester.getCenter(find.text('Delete'));
    await mouse.moveTo(
      Offset(email.dx - 100, (share.center.dy + delete.dy) / 2 + 6),
    );
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    await mouse.moveTo(email);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    expect(log, ['email']);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('Right opens a submenu on its first row, Left closes it', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu([])));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    final expanded = tester.getSemantics(find.text('Share'));
    expect(expanded.flagsCollection.isExpanded, Tristate.isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsNothing);
    expect(find.text('Share'), findsOneWidget);

    // Escape in a submenu closes only the submenu.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('on touch a submenu replaces the rows under a back row', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    final log = <String>[];
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: _menu(log)));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
    expect(find.text('Email'), findsOneWidget);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(log, ['message']);
  });
}
