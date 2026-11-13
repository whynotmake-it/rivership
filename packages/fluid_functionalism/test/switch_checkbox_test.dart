import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => FluidTheme(
    data: FluidThemeData.light.copyWith(tier: FluidTier.desktop),
    child: FocusScope(autofocus: true, child: Center(child: child)),
  ),
);

void main() {
  group('FluidSwitch', () {
    testWidgets('overview sheet', (tester) async {
      Widget sw(SheetState s, {required bool on, FluidDensity? density}) =>
          FluidSwitch(
            value: on,
            onChanged: s.isDisabled ? null : (_) {},
            density: density,
            statesController: s.controller(),
            label: Text(on ? 'Notifications on' : 'Notifications off'),
          );
      final sheet = ThemedPair(
        title: 'Switch',
        builder: (context) => StateTable(
          rows: [
            SheetRow('off', (s) => sw(s, on: false)),
            SheetRow('on', (s) => sw(s, on: true)),
            SheetRow(
              'off · compact',
              (s) => sw(s, on: false, density: FluidDensity.compact),
            ),
            SheetRow(
              'on · compact',
              (s) => sw(s, on: true, density: FluidDensity.compact),
            ),
            SheetRow(
              'no label',
              (s) => FluidSwitch(
                value: true,
                onChanged: s.isDisabled ? null : (_) {},
                statesController: s.controller(),
                semanticLabel: 'Wi-Fi',
              ),
            ),
          ],
        ),
      );
      final finder = await pumpSheet(tester, sheet);
      await expectSheetGolden(tester, finder, 'goldens/switch.png');
    });

    testWidgets('toggles on tap, Space, and drag past the midpoint', (
      tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => FluidSwitch(
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
      final track = tester.getRect(find.byType(FluidSwitch));
      await tester.dragFrom(
        Offset(track.left + 20, track.center.dy),
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('a quick flick toggles before the midpoint; a slow short '
        'drag springs back', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => FluidSwitch(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      final track = tester.getRect(find.byType(FluidSwitch));
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
            builder: (context, setState) => FluidSwitch(
              value: value,
              onChanged: (v) => setState(() => value = v),
              statesController: states,
            ),
          ),
        ),
      );
      final track = tester.getRect(find.byType(FluidSwitch));
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
        of: find.byType(FluidSwitch),
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
        _app(FluidSwitch(value: true, onChanged: (_) {}, semanticLabel: 'A')),
      );
      expect(
        tester.getSemantics(find.byType(FluidSwitch)),
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

  group('FluidCheckbox', () {
    testWidgets('overview sheet', (tester) async {
      Widget cb(
        SheetState s, {
        bool value = false,
        bool indeterminate = false,
        bool invalid = false,
        FluidDensity? density,
      }) => FluidCheckbox(
        value: value,
        indeterminate: indeterminate,
        invalid: invalid,
        density: density,
        onChanged: s.isDisabled ? null : (_) {},
        statesController: s.controller(),
      );
      final sheet = ThemedPair(
        title: 'Checkbox',
        builder: (context) => StateTable(
          rows: [
            SheetRow('unchecked', cb),
            SheetRow('checked', (s) => cb(s, value: true)),
            SheetRow('indeterminate', (s) => cb(s, indeterminate: true)),
            SheetRow('invalid', (s) => cb(s, invalid: true)),
            SheetRow(
              'compact',
              (s) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  cb(s, density: FluidDensity.compact),
                  cb(s, value: true, density: FluidDensity.compact),
                  cb(s, indeterminate: true, density: FluidDensity.compact),
                ],
              ),
            ),
          ],
        ),
      );
      final finder = await pumpSheet(tester, sheet);
      await expectSheetGolden(tester, finder, 'goldens/checkbox.png');
    });

    testWidgets('indeterminate reports true; draws the check in', (
      tester,
    ) async {
      bool? reported;
      await tester.pumpWidget(
        _app(
          FluidCheckbox(
            value: false,
            indeterminate: true,
            onChanged: (v) => reported = v,
          ),
        ),
      );
      await tester.tap(find.byType(FluidCheckbox));
      expect(reported, isTrue);
    });

    testWidgets('hover darkens the border', (tester) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(
        _app(
          FluidCheckbox(
            value: false,
            onChanged: (_) {},
            statesController: states,
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(FluidCheckbox)));
      await tester.pump();
      expect(states.value, contains(WidgetState.hovered));
    });
  });
}
