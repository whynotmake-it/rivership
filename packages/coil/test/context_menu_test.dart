import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _menu(List<String> log, {int extra = 0}) => Center(
  child: CoilContextMenu(
    entries: [
      CoilAction(label: 'Copy', onPressed: () => log.add('copy')),
      for (var i = 0; i < extra; i++)
        CoilAction(label: 'Extra $i', onPressed: () {}),
    ],
    child: CoilButton(
      onPressed: () => log.add('tap'),
      child: const SizedBox(width: 200, height: 60, child: Text('Target')),
    ),
  ),
);

void main() {
  testWidgets('a right-click opens it at the pointer', (tester) async {
    useScreen(tester, TestScreen.desktop);
    final log = <String>[];
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu(log)));
    // Near the right edge, so it opens leftward of the pointer.
    final at = tester.getTopRight(find.text('Target')) + const Offset(-4, 10);
    await tester.tapAt(at, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byType(CoilPopoverSurface));
    expect(menu.right, closeTo(at.dx, 0.5));
    expect(menu.top, closeTo(at.dy, 0.5));
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(log, ['copy']);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('Shift+F10 opens it next to the focused child', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: _menu([])));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();

    final target = tester.getRect(find.text('Target'));
    expect(
      tester.getTopLeft(find.byType(CoilActionList)).dy,
      greaterThan(target.bottom),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets(
    'Control-click on macOS opens it without clicking the child',
    (tester) async {
      useScreen(tester, TestScreen.desktop);
      final log = <String>[];
      await tester.pumpWidget(
        testApp(tier: CoilTier.pointer, home: _menu(log)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final mouse = await tester.startGesture(
        tester.getCenter(find.text('Target')),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  group('on a phone', () {
    testWidgets('a long press lifts the child and opens at the finger', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      final log = <String>[];
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: _menu(log)),
      );
      final at = tester.getCenter(find.text('Target'));
      final rest = tester.getRect(find.text('Target')).width;
      await tester.longPressAt(at);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(find.text('Copy'), findsOneWidget);
      expect(log, isEmpty);
      expect(tester.getRect(find.text('Target')).width, greaterThan(rest));

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsNothing);
      expect(tester.getRect(find.text('Target')).width, rest);
    });

    testWidgets('a long menu opens as a sheet', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: _menu([], extra: 10)),
      );
      await tester.longPress(find.text('Target'));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsOneWidget);
    });
  });
}
