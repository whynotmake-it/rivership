import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
    child: FocusScope(autofocus: true, child: Center(child: child)),
  ),
);

void main() {
  group('CoilSwitch', () {
    testWidgets('toggles on tap, Space, and drag past the midpoint', (
      tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => CoilSwitch(
              value: value,
              onChanged: (v) => setState(() => value = v),
              label: const Text('Wi-Fi'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Wi-Fi'));
      await tester.pumpAndSettle();
      expect(value, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, isFalse);

      // Drag the thumb to the right.
      final track = tester.getRect(find.byType(CoilSwitch));
      await tester.dragFrom(
        Offset(track.left + 20, track.center.dy),
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('a quick flick toggles from the near side; a slow short '
        'drag springs back', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => CoilSwitch(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      final track = tester.getRect(find.byType(CoilSwitch));
      final start = Offset(track.left + 10, track.center.dy);

      // Slow and short (5 of 14 px of travel, with a mouse): stays off.
      final slow = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 5; i++) {
        await slow.moveBy(const Offset(1, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await slow.up();
      await settle(tester);
      expect(value, isFalse);

      // A fast flick of the same small distance: decides by direction.
      await tester.flingFrom(
        start,
        const Offset(5, 0),
        600,
        deviceKind: PointerDeviceKind.mouse,
      );
      await settle(tester);
      expect(value, isTrue);
    });

    testWidgets('dragging squishes the thumb and lets go cleanly', (
      tester,
    ) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      var value = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => CoilSwitch(
              value: value,
              onChanged: (v) => setState(() => value = v),
              statesController: states,
            ),
          ),
        ),
      );
      final track = tester.getRect(find.byType(CoilSwitch));
      final gesture = await tester.startGesture(
        Offset(track.left + 10, track.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      // The first move only wins the gesture arena; later ones drag.
      await gesture.moveBy(const Offset(2, 0));
      await gesture.moveBy(const Offset(18, 0));
      await settle(tester);
      // Mid-drag: the thumb has been squished (shorter than at rest).
      final thumb = find.descendant(
        of: find.byType(CoilSwitch),
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(thumb.last).height, lessThan(16));
      await gesture.up();
      await settle(tester);
      expect(value, isTrue);
      expect(tester.getSize(thumb.last).height, 16);
      expect(states.value, isNot(contains(WidgetState.pressed)));
    });

    testWidgets('semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(CoilSwitch(value: true, onChanged: (_) {}, semanticLabel: 'A')),
      );
      expect(
        tester.getSemantics(find.byType(CoilSwitch)),
        matchesSemantics(
          label: 'A',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('CoilCheckbox', () {
    testWidgets('a tristate box cycles false → true → null → false', (
      tester,
    ) async {
      bool? value = false;
      final reported = <bool?>[];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => CoilCheckbox(
              value: value,
              tristate: true,
              onChanged: (v) => setState(() => reported.add(value = v)),
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(CoilCheckbox));
        await tester.pump();
      }
      expect(reported, [true, null, false]);
    });

    testWidgets('a two-state box never reports null', (tester) async {
      final reported = <bool?>[];
      await tester.pumpWidget(
        _app(CoilCheckbox(value: true, onChanged: reported.add)),
      );
      await tester.tap(find.byType(CoilCheckbox));
      expect(reported, [false]);
      expect(
        () => CoilCheckbox(value: null, onChanged: (_) {}),
        throwsAssertionError,
      );
    });

    testWidgets('hover darkens the border', (tester) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(
        _app(
          CoilCheckbox(
            value: false,
            onChanged: (_) {},
            statesController: states,
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(CoilCheckbox)));
      await tester.pump();
      expect(states.value, contains(WidgetState.hovered));
    });
  });
}
