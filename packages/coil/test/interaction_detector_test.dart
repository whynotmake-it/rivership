// CoilInteractionDetector's rules, checked on a bare detector: hover only
// from pointers that can hover, press cleared when a touch becomes a
// scroll, and focus only with primary focus after keyboard use. Every
// component, ejected or not, gets its states from these rules.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _target = ValueKey('target');

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) =>
      CoilTheme(data: CoilThemeData.light, child: navigator!),
  onGenerateRoute: (_) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 200, height: 300, child: child),
    ),
  ),
);

Widget _detector(WidgetStatesController states, {FocusNode? focusNode}) =>
    CoilInteractionDetector(
      states: states,
      focusNode: focusNode,
      onTap: () {},
      child: const SizedBox(key: _target, width: 100, height: 40),
    );

void main() {
  late WidgetStatesController states;

  setUp(() => states = WidgetStatesController());
  tearDown(() => states.dispose());

  group('hover', () {
    for (final (kind, hovers) in [
      (PointerDeviceKind.mouse, true),
      (PointerDeviceKind.stylus, true),
      (PointerDeviceKind.touch, false),
    ]) {
      testWidgets('a ${kind.name} ${hovers ? 'hovers' : 'never hovers'}', (
        tester,
      ) async {
        await tester.pumpWidget(_app(_detector(states)));
        final pointer = await tester.createGesture(kind: kind);
        addTearDown(pointer.removePointer);
        await pointer.down(tester.getCenter(find.byKey(_target)));
        await pointer.up();
        await pointer.moveTo(tester.getCenter(find.byKey(_target)));
        await tester.pump(const Duration(seconds: 1));

        expect(states.value.contains(WidgetState.hovered), hovers);
      });
    }
  });

  testWidgets('a press clears when the touch becomes a scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ListView(
          children: [_detector(states), const SizedBox(height: 1000)],
        ),
      ),
    );
    final touch = await tester.startGesture(
      tester.getCenter(find.byKey(_target)),
    );
    await tester.pump(kPressTimeout);
    expect(states.value, contains(WidgetState.pressed));

    await touch.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(states.value, isNot(contains(WidgetState.pressed)));
    await touch.up();
  });

  group('focus', () {
    late FocusNode node;

    setUp(() => node = FocusNode());
    tearDown(() => node.dispose());

    testWidgets('shows with primary focus after keyboard use', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Focus(
            focusNode: node,
            child: _detector(states, focusNode: node),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      node.requestFocus();
      await tester.pump();
      expect(states.value, contains(WidgetState.focused));

      await tester.tap(find.byKey(_target));
      await tester.pump(const Duration(seconds: 1));
      expect(
        states.value,
        isNot(contains(WidgetState.focused)),
        reason: 'a pointer press hides it',
      );
    });

    testWidgets("a focused descendant doesn't count", (tester) async {
      final inner = FocusNode();
      addTearDown(inner.dispose);
      await tester.pumpWidget(
        _app(
          Focus(
            focusNode: node,
            child: CoilInteractionDetector(
              states: states,
              focusNode: node,
              child: Focus(focusNode: inner, child: const SizedBox()),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      inner.requestFocus();
      await tester.pump();

      expect(node.hasFocus, isTrue);
      expect(states.value, isNot(contains(WidgetState.focused)));
    });
  });
}
