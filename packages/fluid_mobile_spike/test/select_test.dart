import 'package:fluid_mobile_spike/fluid_mobile_spike.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

final _select = find.byKey(const ValueKey('select'));

Future<void> _settle(WidgetTester tester) async {
  // Covers the selection acknowledgment timer, then lets every motion rest.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

FocusNode? get _primaryFocus => FocusManager.instance.primaryFocus;

bool _triggerHasFocus(WidgetTester tester) {
  final focus = tester.widget<Focus>(
    find.descendant(of: _select, matching: find.byType(Focus)).first,
  );
  return focus.focusNode?.hasPrimaryFocus ?? false;
}

/// The list's fill whose key starts with `fill-[role]`.
FluidFill _fill(WidgetTester tester, String role) => tester
    .widgetList<FluidFill>(find.byType(FluidFill))
    .singleWhere(
      (fill) => (fill.key! as ValueKey<String>).value.startsWith('fill-$role'),
    );

Iterable<String> _checkedRows(WidgetTester tester) => tester
    .widgetList<FluidOptionRow>(find.byType(FluidOptionRow))
    .where((row) => row.checked)
    .map((row) => (row.label as Text).data!);

void main() {
  group('presentation', () {
    testWidgets('pointer opens an anchored popover', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(),
          inputMode: FluidInputMode.pointer,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(find.byType(FluidSheetPanel), findsNothing);
      final trigger = tester.getRect(_select);
      final list = tester.getRect(find.byType(FluidOptionList<String>));
      // Under the trigger, 6px away, start-aligned, at least as wide.
      expect(list.top, moreOrLessEquals(trigger.bottom + 6));
      expect(list.left, trigger.left);
      expect(list.width, greaterThanOrEqualTo(trigger.width));
      final row = tester.getSize(find.byType(FluidOptionRow).first);
      expect(row.height, 36);
    });

    testWidgets('touch on a phone opens a sheet with 44px rows', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(home: const SelectDemo(), inputMode: FluidInputMode.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();

      expect(find.byType(FluidSheetPanel), findsOneWidget);
      final row = tester.getSize(find.byType(FluidOptionRow).first);
      expect(row.height, 44);
      // The trigger itself grew to the touch step.
      expect(tester.getSize(_select).height, 44);
    });

    testWidgets('touch on a wide screen keeps the popover at touch size', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      tester.view.physicalSize = const Size(1024, 768) * 2;
      await tester.pumpWidget(
        testApp(home: const SelectDemo(), inputMode: FluidInputMode.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();

      expect(find.byType(FluidSheetPanel), findsNothing);
      expect(tester.getSize(find.byType(FluidOptionRow).first).height, 44);
    });

    testWidgets('the component override wins over the scope', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: const SelectDemo(presentation: FluidPresentation.sheet),
          inputMode: FluidInputMode.pointer,
          presentation: FluidPresentation.popover,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(FluidSheetPanel), findsOneWidget);
    });

    testWidgets(
      'the last pointer kind switches the input mode',
      (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        await tester.pumpWidget(testApp(home: const SelectDemo()));
        // Desktop platforms start in pointer mode.
        expect(tester.getSize(_select).height, 36);

        await tester.tapAt(Offset.zero);
        await tester.pump();
        expect(tester.getSize(_select).height, 44);

        await tester.tapAt(Offset.zero, kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(tester.getSize(_select).height, 36);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'phones start in touch mode',
      (tester) async {
        useScreen(tester, TestScreen.phone);
        await tester.pumpWidget(testApp(home: const SelectDemo()));
        expect(tester.getSize(_select).height, 44);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('popover keyboard', () {
    Future<List<String>> open(WidgetTester tester) async {
      final picks = <String>[];
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: SelectDemo(autofocus: true, onChanged: picks.add),
          inputMode: FluidInputMode.pointer,
        ),
      );
      await tester.pump();
      expect(_triggerHasFocus(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.byType(FluidOptionList<String>), findsOneWidget);
      return picks;
    }

    testWidgets('arrows skip disabled rows and Enter picks', (tester) async {
      final picks = await open(tester);
      // Opens on the selected row (banana). Down: blueberry, cherry, then
      // mango (grapes is disabled).
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(picks, ['mango']);
      expect(find.byType(FluidOptionList<String>), findsNothing);
      expect(_triggerHasFocus(tester), isTrue);
    });

    testWidgets('Home, End and Up', (tester) async {
      final picks = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(picks, ['cherry']);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(picks, ['cherry', 'apple']);
    });

    testWidgets('typeahead finds by prefix and cycles a repeated letter', (
      tester,
    ) async {
      final picks = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(picks, ['cherry']);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // From cherry: "b" → banana, "b" again → blueberry.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump(const Duration(seconds: 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(picks, ['cherry', 'blueberry']);
    });

    testWidgets('a multi-letter query narrows the match', (tester) async {
      final picks = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(picks, ['blueberry']);
    });

    testWidgets('Escape closes without picking and returns focus', (
      tester,
    ) async {
      final picks = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(picks, isEmpty);
      expect(find.byType(FluidOptionList<String>), findsNothing);
      expect(_triggerHasFocus(tester), isTrue);
    });

    testWidgets('Tab closes instead of moving focus out of the list', (
      tester,
    ) async {
      final picks = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(picks, isEmpty);
      expect(find.byType(FluidOptionList<String>), findsNothing);
      expect(_triggerHasFocus(tester), isTrue);
    });
  });

  group('pointer', () {
    testWidgets('an outside click dismisses, a row click picks', (
      tester,
    ) async {
      final picks = <String>[];
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: SelectDemo(onChanged: picks.add),
          inputMode: FluidInputMode.pointer,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 420), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(FluidOptionList<String>), findsNothing);
      expect(picks, isEmpty);

      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orange'), kind: PointerDeviceKind.mouse);
      // Held open for the acknowledgment.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FluidOptionList<String>), findsOneWidget);
      await _settle(tester);
      expect(picks, ['orange']);
      expect(find.byType(FluidOptionList<String>), findsNothing);
      expect(_primaryFocus, isNotNull);
    });

    testWidgets('disabled rows ignore taps', (tester) async {
      final picks = <String>[];
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          home: SelectDemo(onChanged: picks.add),
          inputMode: FluidInputMode.pointer,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grapes'), kind: PointerDeviceKind.mouse);
      await _settle(tester);
      expect(picks, isEmpty);
      expect(find.byType(FluidOptionList<String>), findsOneWidget);
    });
  });

  group('sheet', () {
    testWidgets('a tap picks and the sheet slides away', (tester) async {
      final picks = <String>[];
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          home: SelectDemo(onChanged: picks.add),
          inputMode: FluidInputMode.touch,
        ),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mango'));
      await _settle(tester);

      expect(picks, ['mango']);
      expect(find.byType(FluidSheetPanel), findsNothing);
      expect(find.text('Mango'), findsOneWidget); // now in the trigger
    });

    testWidgets('tapping the scrim dismisses', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(home: const SelectDemo(), inputMode: FluidInputMode.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(find.byType(FluidSheetPanel), findsNothing);
    });
  });

  group('no sticky hover on touch', () {
    Future<void> openSheet(WidgetTester tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(home: const SelectDemo(), inputMode: FluidInputMode.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
    }

    testWidgets('a touch tap on a sheet row leaves no highlight behind', (
      tester,
    ) async {
      await openSheet(tester);
      // At rest the picked row has its check and no fill.
      expect(_fill(tester, 'selected').rect, isNull);
      expect(_checkedRows(tester), ['Banana']);

      await tester.tap(find.text('Mango'));
      // Still open for the acknowledgment: the check moved, nothing is lit.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(FluidSheetPanel), findsOneWidget);
      expect(_fill(tester, 'hover').rect, isNull);
      expect(_fill(tester, 'press').rect, isNull);
      expect(_fill(tester, 'selected').rect, isNull);
      expect(_fill(tester, 'focus').rect, isNull);
      expect(_checkedRows(tester), ['Mango']);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final trigger = tester.widget<FluidTriggerBox>(
        find.byType(FluidTriggerBox),
      );
      expect(trigger.hovered, isFalse);
      expect(trigger.pressed, isFalse);
    });

    testWidgets('press feedback shows while the finger is down only', (
      tester,
    ) async {
      await openSheet(tester);
      final finger = await tester.startGesture(
        tester.getCenter(find.text('Cherry')),
      );
      await tester.pump(kPressTimeout + const Duration(milliseconds: 20));
      expect(_fill(tester, 'press').rect, isNotNull);
      expect(_fill(tester, 'hover').rect, isNull);

      // Sliding off cancels the tap: feedback clears and nothing is picked.
      await finger.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(_fill(tester, 'press').rect, isNull);
      await finger.up();
      await tester.pumpAndSettle();
      expect(_checkedRows(tester), ['Banana']);
      expect(find.byType(FluidSheetPanel), findsOneWidget);
    });

    testWidgets('a touch tap in a tablet popover leaves no hover either', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      tester.view.physicalSize = const Size(1024, 768) * 2;
      await tester.pumpWidget(
        testApp(home: const SelectDemo(), inputMode: FluidInputMode.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cherry'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(FluidSheetPanel), findsNothing);
      expect(_fill(tester, 'hover').rect, isNull);
      expect(_fill(tester, 'press').rect, isNull);
      // The popover keeps the web's selected fill, now on the picked row.
      expect(_fill(tester, 'selected').rect, isNotNull);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });

    testWidgets('a mouse still drives the fluid hover highlight', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(home: const SelectDemo(), inputMode: FluidInputMode.pointer),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(_select));
      await mouse.down(tester.getCenter(_select));
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.text('Cherry')));
      await tester.pumpAndSettle();
      expect(_fill(tester, 'hover').rect, isNotNull);
      expect(_fill(tester, 'press').rect, isNull);
      await mouse.removePointer();
    });
  });
}
