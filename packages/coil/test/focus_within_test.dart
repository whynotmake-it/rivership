// CoilFocusWithin: a container learns when visible focus is inside it.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A container that shows 'outlined' while focus inside it is visible.
Widget _panel(List<Widget> children) => CoilFocusWithin(
  builder: (context, visible, child) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [Text(visible ? 'outlined' : 'plain'), child!],
  ),
  child: Column(mainAxisSize: MainAxisSize.min, children: children),
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, navigator) =>
        CoilTheme(data: CoilThemeData.light, child: navigator!),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 240, child: child),
      ),
    ),
  ),
);

final _outside = FocusNode(debugLabel: 'outside');

Widget _form() => Column(
  children: [
    CoilButton(
      focusNode: _outside,
      onPressed: () {},
      child: const Text('Outside'),
    ),
    _panel([
      CoilButton(onPressed: () {}, child: const Text('Save')),
      const CoilInput(placeholder: Text('Name')),
    ]),
  ],
);

void main() {
  setUp(CoilInputModality.debugReset);

  testWidgets('keyboard focus inside outlines the container', (tester) async {
    await _pump(tester, _form());
    expect(find.text('plain'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_outside.hasFocus, isTrue);
    expect(find.text('plain'), findsOneWidget, reason: 'focus is outside');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text('outlined'), findsOneWidget, reason: 'Save is focused');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(_outside.hasFocus, isTrue);
    expect(find.text('plain'), findsOneWidget, reason: 'focus left');
  });

  testWidgets('a click hides it, as it hides a focus ring', (tester) async {
    await _pump(tester, _form());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text('outlined'), findsOneWidget);

    // Clicking a button doesn't move focus, but it's pointer input now.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(tester.getCenter(find.text('Save')));
    await mouse.up();
    await tester.pump();
    expect(find.text('plain'), findsOneWidget);
  });

  testWidgets('a text field focused by a click outlines it', (tester) async {
    await _pump(tester, _form());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(tester.getCenter(find.byType(EditableText)));
    await mouse.up();
    await tester.pump();
    expect(find.text('outlined'), findsOneWidget);
  });

  testWidgets('it adds no tab stop', (tester) async {
    await _pump(tester, _form());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus!;
    expect(focused, isNot(_outside));
    expect(
      focused.context!.findAncestorWidgetOfExactType<CoilButton>(),
      isNotNull,
      reason: 'the second stop is Save, not the container',
    );
  });
}
