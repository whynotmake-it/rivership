import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/paint_probe.dart';
import 'src/select_harness.dart';

final _select = find.byKey(const ValueKey('select'));

Future<void> _settle(WidgetTester tester) async {
  // Covers the selection acknowledgment timer, then lets every motion rest.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

FocusNode? get _primaryFocus => FocusManager.instance.primaryFocus;

bool _triggerHasFocus(WidgetTester tester) =>
    _primaryFocus?.debugLabel == 'CoilSelect';

/// The open list: the menu node.
final _list = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.role == SemanticsRole.menu,
);

/// The rows of the open list, in order.
Finder get _rows =>
    find.descendant(of: _list, matching: find.byType(CoilHoverItem));

// Probe colors: the select's highlight, selected fill and focus ring each
// get a pure color, so tests can see which rows show what.
const _hover = Color(0xFFFF0000);
const _selected = Color(0xFF00FF00);
const _ring = Color(0xFF0000FF);

/// [testApp] with the probe colors.
Widget _app({
  required Widget home,
  CoilTier? tier,
  CoilPresentation? presentation,
}) => testApp(
  home: home,
  tier: tier,
  presentation: presentation,
  colors: CoilColors.light.copyWith(brand: _ring),
  selectStyle: const CoilSelectStyle(
    highlight: _hover,
    selectedFill: _selected,
  ),
);

/// The rows that show [role] (hover, selected, press or focus) to the eye.
Future<List<int>> _lit(WidgetTester tester, String role) async {
  if (_list.evaluate().isEmpty) return const [];
  if (role == 'press') {
    return [
      for (final (i, d)
          in tester
              .widgetList<CoilInteractionDetector>(
                find.descendant(
                  of: _list,
                  matching: find.byType(CoilInteractionDetector),
                ),
              )
              .indexed)
        if (d.states.value.contains(WidgetState.pressed) &&
            !d.states.value.contains(WidgetState.hovered))
          i,
    ];
  }
  final rows = tester.widgetList(_rows).length;
  final boundary = find.byKey(appBoundary);
  return [
    for (var i = 0; i < rows; i++)
      if (await _rowShows(tester, boundary, tester.getRect(_rows.at(i)), role))
        i,
  ];
}

Future<bool> _rowShows(
  WidgetTester tester,
  Finder boundary,
  Rect row,
  String role,
) async => switch (role) {
  // A fill shows in the row's leading padding, clear of label and check.
  'hover' => isNear(
    await colorAt(tester, boundary, Offset(row.left + 2, row.center.dy)),
    _hover,
    tolerance: 40,
  ),
  'selected' => isNear(
    await colorAt(tester, boundary, Offset(row.left + 2, row.center.dy)),
    _selected,
    tolerance: 40,
  ),
  // The ring sits 2 px outside the row.
  'focus' => isNear(
    await colorAt(tester, boundary, Offset(row.center.dx, row.top - 2)),
    _ring,
    tolerance: 60,
  ),
  _ => throw ArgumentError(role),
};

Iterable<String> _checkedRows(WidgetTester tester) => [
  for (final semantics in tester.widgetList<Semantics>(
    find.descendant(of: _list, matching: find.byType(Semantics)),
  ))
    if (semantics.properties.selected ?? false) semantics.properties.label!,
];

Set<WidgetState> _triggerStates(WidgetTester tester) => tester
    .widget<CoilInteractionDetector>(
      find.descendant(
        of: _select,
        matching: find.byType(CoilInteractionDetector),
      ),
    )
    .states
    .value;

void main() {
  group('presentation', () {
    testWidgets('pointer opens an anchored popover', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        _app(
          home: const SelectDemo(),
          tier: CoilTier.pointer,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(find.byType(CoilSheetPanel), findsNothing);
      final trigger = tester.getRect(_select);
      final list = tester.getRect(_list);
      // Under the trigger, 6px away, start-aligned, at least as wide.
      expect(list.top, moreOrLessEquals(trigger.bottom + 6));
      expect(list.left, trigger.left);
      expect(list.width, greaterThanOrEqualTo(trigger.width));
      final row = tester.getSize(_rows.first);
      expect(row.height, 36);
    });

    testWidgets('a long select on a phone opens a sheet with 44px rows', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(
          home: const SelectDemo(options: moreFruits),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();

      expect(find.byType(CoilSheetPanel), findsOneWidget);
      final row = tester.getSize(_rows.first);
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
        _app(home: const SelectDemo(), tier: CoilTier.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();

      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(tester.getSize(_rows.first).height, 44);
    });

    testWidgets('the component override wins over the scope', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        _app(
          home: const SelectDemo(presentation: CoilPresentation.sheet),
          tier: CoilTier.pointer,
          presentation: CoilPresentation.popover,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsOneWidget);
    });

    testWidgets(
      'the tier latches by platform: a touch on a desktop keeps its sizes',
      (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        await tester.pumpWidget(_app(home: const SelectDemo()));
        // Desktop platforms start in pointer mode.
        expect(tester.getSize(_select).height, 36);

        await tester.tapAt(Offset.zero);
        await tester.pump();
        expect(tester.getSize(_select).height, 36);

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
        await tester.pumpWidget(_app(home: const SelectDemo()));
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
        _app(
          home: SelectDemo(autofocus: true, onChanged: picks.add),
          tier: CoilTier.pointer,
        ),
      );
      await tester.pump();
      expect(_triggerHasFocus(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_list, findsOneWidget);
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
      expect(_list, findsNothing);
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
      expect(_list, findsNothing);
      expect(_triggerHasFocus(tester), isTrue);
    });

    testWidgets('Tab closes instead of moving focus out of the list', (
      tester,
    ) async {
      final picks = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(picks, isEmpty);
      expect(_list, findsNothing);
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
        _app(
          home: SelectDemo(onChanged: picks.add),
          tier: CoilTier.pointer,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 420), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_list, findsNothing);
      expect(picks, isEmpty);

      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orange'), kind: PointerDeviceKind.mouse);
      // Held open for the acknowledgment.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_list, findsOneWidget);
      await _settle(tester);
      expect(picks, ['orange']);
      expect(_list, findsNothing);
      expect(_primaryFocus, isNotNull);
    });

    testWidgets('disabled rows ignore taps', (tester) async {
      final picks = <String>[];
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        _app(
          home: SelectDemo(onChanged: picks.add),
          tier: CoilTier.pointer,
        ),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grapes'), kind: PointerDeviceKind.mouse);
      await _settle(tester);
      expect(picks, isEmpty);
      expect(_list, findsOneWidget);
    });
  });

  group('sheet', () {
    testWidgets('a tap picks and the sheet slides away', (tester) async {
      final picks = <String>[];
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(
          home: SelectDemo(options: moreFruits, onChanged: picks.add),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mango'));
      await _settle(tester);

      expect(picks, ['mango']);
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(find.text('Mango'), findsOneWidget); // now in the trigger
    });

    testWidgets('tapping the scrim dismisses', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(
          home: const SelectDemo(options: moreFruits),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
    });
  });

  group('no sticky hover on touch', () {
    Future<void> openSheet(WidgetTester tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(
          home: const SelectDemo(options: moreFruits),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
    }

    testWidgets('a touch tap on a sheet row leaves no highlight behind', (
      tester,
    ) async {
      await openSheet(tester);
      // At rest the picked row has its check and no fill.
      expect(await _lit(tester, 'selected'), isEmpty);
      expect(_checkedRows(tester), ['Banana']);

      await tester.tap(find.text('Mango'));
      // Still open for the acknowledgment: the check moved, nothing is lit.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(CoilSheetPanel), findsOneWidget);
      expect(await _lit(tester, 'hover'), isEmpty);
      expect(await _lit(tester, 'press'), isEmpty);
      expect(await _lit(tester, 'selected'), isEmpty);
      expect(await _lit(tester, 'focus'), isEmpty);
      expect(_checkedRows(tester), ['Mango']);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_triggerStates(tester), isNot(contains(WidgetState.hovered)));
      expect(_triggerStates(tester), isNot(contains(WidgetState.pressed)));
    });

    testWidgets('press feedback shows while the finger is down only', (
      tester,
    ) async {
      await openSheet(tester);
      final finger = await tester.startGesture(
        tester.getCenter(find.text('Cherry')),
      );
      await tester.pump(kPressTimeout + const Duration(milliseconds: 20));
      expect(await _lit(tester, 'press'), isNotEmpty);
      expect(await _lit(tester, 'hover'), isEmpty);

      // Sliding off cancels the tap: feedback clears and nothing is picked.
      await finger.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(await _lit(tester, 'press'), isEmpty);
      await finger.up();
      await tester.pumpAndSettle();
      expect(_checkedRows(tester), ['Banana']);
      expect(find.byType(CoilSheetPanel), findsOneWidget);
    });

    testWidgets('a touch tap in a tablet popover leaves no hover either', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      tester.view.physicalSize = const Size(1024, 768) * 2;
      await tester.pumpWidget(
        _app(home: const SelectDemo(), tier: CoilTier.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cherry'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(await _lit(tester, 'hover'), isEmpty);
      expect(await _lit(tester, 'press'), isEmpty);
      // The popover keeps the web's selected fill, now on the picked row.
      expect(await _lit(tester, 'selected'), isNotEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });

    testWidgets('a mouse still drives the fluid hover highlight', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        _app(home: const SelectDemo(), tier: CoilTier.pointer),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(_select));
      await mouse.down(tester.getCenter(_select));
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.text('Cherry')));
      await tester.pumpAndSettle();
      expect(await _lit(tester, 'hover'), isNotEmpty);
      expect(await _lit(tester, 'press'), isEmpty);
      await mouse.removePointer();
    });
  });

  group('phone decision rule', () {
    CoilPresentation rule({
      CoilOverlayKind kind = CoilOverlayKind.actionMenu,
      int items = 5,
      bool search = false,
      bool multi = false,
      int depth = 0,
    }) => CoilAdaptivePopup.phonePresentation(
      CoilOverlayTraits(
        kind: kind,
        itemCount: items,
        hasSearch: search,
        multiSelect: multi,
        submenuDepth: depth,
      ),
    );

    test('short simple menus stay anchored', () {
      expect(rule(), CoilPresentation.popover);
      expect(rule(items: 8), CoilPresentation.popover);
      expect(rule(depth: 1), CoilPresentation.popover);
      expect(
        rule(kind: CoilOverlayKind.contextMenu),
        CoilPresentation.popover,
      );
      expect(
        rule(kind: CoilOverlayKind.select, items: 7),
        CoilPresentation.popover,
      );
    });

    test('anything that needs room is a sheet', () {
      expect(rule(items: 9), CoilPresentation.sheet);
      expect(rule(search: true), CoilPresentation.sheet);
      expect(rule(multi: true, items: 3), CoilPresentation.sheet);
      expect(rule(depth: 2), CoilPresentation.sheet);
      expect(rule(kind: CoilOverlayKind.combobox), CoilPresentation.sheet);
      expect(rule(kind: CoilOverlayKind.dateTime), CoilPresentation.sheet);
    });

    testWidgets('a short select on a phone is an anchored touch popover', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(home: const SelectDemo(), tier: CoilTier.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
      final trigger = tester.getRect(_select);
      final list = tester.getRect(_list);
      expect(list.top, moreOrLessEquals(trigger.bottom + 6));
      expect(tester.getSize(_rows.first).height, 44);
    });

    testWidgets('the override still wins on a phone', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(
          home: const SelectDemo(presentation: CoilPresentation.sheet),
          tier: CoilTier.touch,
        ),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsOneWidget);
    });
  });

  group('multi-select', () {
    testWidgets('a phone opens a sheet; taps toggle and keep it open', (
      tester,
    ) async {
      final changes = <Set<String>>[];
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(
          home: SelectDemo(
            multiple: true,
            options: fruits.take(5).toList(),
            initialValues: const {'banana'},
            onValuesChanged: changes.add,
          ),
          tier: CoilTier.touch,
        ),
      );
      // Only five options, but multi-select always gets a sheet.
      await tester.tap(_select);
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsOneWidget);

      final sheet = find.byType(CoilSheetPanel);
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Apple')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Banana')),
      );
      await tester.pumpAndSettle();
      expect(changes, [
        {'banana', 'apple'},
        {'apple'},
      ]);
      expect(find.byType(CoilSheetPanel), findsOneWidget);
      expect(_checkedRows(tester), ['Apple']);
      // Picks show merged blocks behind their checks; nothing is lit.
      expect(await _lit(tester, 'selected'), [0]);
      expect(await _lit(tester, 'hover'), isEmpty);
      expect(await _lit(tester, 'press'), isEmpty);

      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(find.text('Apple'), findsOneWidget); // the trigger label
    });

    testWidgets('a desktop popover stays open and keys toggle', (
      tester,
    ) async {
      final changes = <Set<String>>[];
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        _app(
          home: SelectDemo(
            multiple: true,
            autofocus: true,
            onValuesChanged: changes.add,
          ),
          tier: CoilTier.pointer,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      // Opens on the first checked row (banana); Down, Space toggles
      // blueberry on.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(changes, [
        {'banana', 'mango', 'blueberry'},
      ]);
      expect(_list, findsOneWidget);
      expect(find.text('Banana, Blueberry, Mango'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });
  });

  group('touch emphasis', () {
    Color textColor(WidgetTester tester, String label) => tester
        .widget<RichText>(
          find.descendant(
            of: _list,
            matching: find.byWidgetPredicate(
              (w) => w is RichText && w.text.toPlainText() == label,
            ),
          ),
        )
        .text
        .style!
        .color!;

    double rowOpacity(WidgetTester tester, String label) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.descendant(
                  of: _list,
                  matching: find.text(label),
                ),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    testWidgets('touch rows rest at full foreground; disabled at 40%', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(home: const SelectDemo(), tier: CoilTier.touch),
      );
      await tester.tap(_select);
      await tester.pumpAndSettle();
      expect(textColor(tester, 'Cherry'), CoilColors.light.foreground);
      expect(rowOpacity(tester, 'Grapes'), 0.4);
    });

    testWidgets('pointer rows rest muted; disabled at 50%', (tester) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        _app(home: const SelectDemo(), tier: CoilTier.pointer),
      );
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(textColor(tester, 'Cherry'), CoilColors.light.mutedForeground);
      expect(rowOpacity(tester, 'Grapes'), 0.5);
    });
  });

  group('slots', () {
    testWidgets('chevron and check can be any widget, styled by IconTheme', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      IconThemeData? chevronTheme;
      IconThemeData? checkTheme;
      await tester.pumpWidget(
        _app(
          tier: CoilTier.pointer,
          home: Center(
            child: SizedBox(
              width: 220,
              child: CoilSelect<String>(
                key: const ValueKey('select'),
                options: fruits,
                value: 'banana',
                onChanged: (_) {},
                indicator: Builder(
                  builder: (context) {
                    chevronTheme = IconTheme.of(context);
                    return const SizedBox(key: ValueKey('my-chevron'));
                  },
                ),
                checkmark: Builder(
                  builder: (context) {
                    checkTheme = IconTheme.of(context);
                    return const SizedBox(key: ValueKey('my-check'));
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('my-chevron')), findsOneWidget);
      expect(chevronTheme!.size, 16);
      await tester.tap(_select, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-check')), findsWidgets);
      expect(checkTheme!.size, 16);
      expect(checkTheme!.color, CoilColors.light.foreground);
    });
  });

  group('text scale', () {
    testWidgets('rows and trigger grow; fills grow with their rows', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        _app(home: const SelectDemo(), tier: CoilTier.touch),
      );
      expect(tester.getSize(_select).height, greaterThan(44));
      await tester.tap(_select);
      await tester.pumpAndSettle();

      final rows = _rows;
      final banana = tester.getRect(rows.at(1));
      expect(banana.height, greaterThan(44));
      // The selected fill covers the whole (taller) Banana row.
      expect(await _lit(tester, 'selected'), [1]);
      final boundary = find.byKey(appBoundary);
      for (final y in [banana.top + 8, banana.bottom - 8]) {
        expect(
          isNear(
            await colorAt(tester, boundary, Offset(banana.left + 4, y)),
            _selected,
            tolerance: 40,
          ),
          isTrue,
        );
      }
    });
  });
}
