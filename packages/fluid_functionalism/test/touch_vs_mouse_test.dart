import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

/// No sticky hover: a touch gives pressed feedback only and leaves nothing
/// behind; hover comes only from pointers that can hover; the focus ring
/// comes only from the keyboard.
void main() {
  late WidgetStatesController touchButton;
  late WidgetStatesController mouseButton;
  late WidgetStatesController touchSwitch;
  late WidgetStatesController mouseSwitch;

  setUp(() {
    touchButton = WidgetStatesController();
    mouseButton = WidgetStatesController();
    touchSwitch = WidgetStatesController();
    mouseSwitch = WidgetStatesController();
  });

  tearDown(() {
    touchButton.dispose();
    mouseButton.dispose();
    touchSwitch.dispose();
    mouseSwitch.dispose();
  });

  const touchKey = ValueKey('touch');
  const mouseKey = ValueKey('mouse');

  Widget column(
    Key key,
    String title,
    WidgetStatesController button,
    WidgetStatesController switchStates,
  ) => _Column(
    key: key,
    title: title,
    buttonStates: button,
    switchStates: switchStates,
  );

  Future<Finder> pump(WidgetTester tester) => pumpSheet(
    tester,
    SheetPanel(
      title: 'After a touch tap vs with a mouse resting on it',
      theme: FluidThemeData.light.copyWith(tier: FluidTier.touch),
      child: FocusScope(
        autofocus: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 48,
          children: [
            column(touchKey, 'touch: tapped', touchButton, touchSwitch),
            column(mouseKey, 'mouse: hovering', mouseButton, mouseSwitch),
          ],
        ),
      ),
    ),
  );

  Finder inColumn(Key key, Finder finder) =>
      find.descendant(of: find.byKey(key), matching: finder);

  FluidHoverState? tabsState(WidgetTester tester, Key key) =>
      FluidHoverRegion.maybeOf(
        tester.element(inColumn(key, find.text('Week')).last),
      );

  testWidgets('touch leaves no hover, highlight or focus ring; mouse hovers', (
    tester,
  ) async {
    final finder = await pump(tester);

    // Touch: tap the button, the switch and a tab, then let motion finish.
    await tester.tap(
      inColumn(touchKey, find.byType(FluidButton)),
    );
    await tester.tap(
      inColumn(touchKey, find.byType(FluidSwitch)),
    );
    await tester.tap(
      inColumn(touchKey, find.text('Month')).last,
    );
    await settle(tester);

    for (final states in [touchButton, touchSwitch]) {
      expect(states.value, isNot(contains(WidgetState.hovered)));
      expect(states.value, isNot(contains(WidgetState.pressed)));
      expect(states.value, isNot(contains(WidgetState.focused)));
    }
    expect(
      tabsState(tester, touchKey)!.activeIndex,
      isNull,
      reason: 'no fluid highlight stays under the lifted finger',
    );

    // Mouse: rest on the other column's controls.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(inColumn(mouseKey, find.byType(FluidButton))),
    );
    await settle(tester);
    expect(mouseButton.value, contains(WidgetState.hovered));
    expect(mouseButton.value, isNot(contains(WidgetState.focused)));

    await mouse.moveTo(
      tester.getCenter(inColumn(mouseKey, find.text('Month')).last),
    );
    await settle(tester);
    expect(tabsState(tester, mouseKey)!.activeIndex, 2);
    expect(mouseButton.value, isNot(contains(WidgetState.hovered)));

    await expectSheetGolden(tester, finder, 'goldens/touch_vs_mouse.png');
  });

  testWidgets('a touch that turns into a scroll drops the pressed state', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => FluidTheme(
          data: FluidThemeData.light,
          child: ListView(
            children: [
              const SizedBox(height: 100),
              Center(
                child: FluidButton(
                  onPressed: () {},
                  statesController: states,
                  child: const Text('Scroll me'),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Scroll me')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(states.value, contains(WidgetState.pressed));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(states.value, isNot(contains(WidgetState.pressed)));
    await gesture.up();
    await settle(tester);
    expect(states.value, isEmpty);
  });

  testWidgets('keyboard shows the ring; a click hides it again', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => FocusScope(
          autofocus: true,
          child: Center(
            child: FluidButton(
              onPressed: () {},
              statesController: states,
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(states.value, contains(WidgetState.focused));

    await tester.tap(find.text('Go'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(
      states.value,
      isNot(contains(WidgetState.focused)),
      reason: 'clicking is pointer input: no ring, like :focus-visible',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      states.value,
      isNot(contains(WidgetState.focused)),
      reason: 'a lone modifier is not keyboard navigation',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(states.value, contains(WidgetState.focused));
  });

  testWidgets('focus after a tap does not light the fluid highlight', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    late BuildContext itemContext;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => FluidTheme(
          data: FluidThemeData.light,
          child: Center(
            child: FluidHoverRegion(
              child: FluidHoverItem(
                index: 0,
                child: Builder(
                  builder: (context) {
                    itemContext = context;
                    return Focus(
                      focusNode: node,
                      child: const SizedBox(width: 100, height: 36),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // A touch elsewhere, then the app moves focus into the item (as a
    // component that focuses on tap would): pointer modality, no highlight.
    await tester.tapAt(const Offset(5, 5));
    node.requestFocus();
    await settle(tester);
    expect(FluidHoverRegion.maybeOf(itemContext)!.activeIndex, isNull);

    // The keyboard takes over: now focus lights it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(FluidHoverRegion.maybeOf(itemContext)!.activeIndex, 0);

    // And a tap anywhere hands control back to the pointer.
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(FluidHoverRegion.maybeOf(itemContext)!.activeIndex, isNull);
  });

  testWidgets('a stylus hovering above the screen hovers', (tester) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => Center(
          child: FluidButton(
            onPressed: () {},
            statesController: states,
            child: const Text('Pen'),
          ),
        ),
      ),
    );
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    addTearDown(pen.removePointer);
    await pen.addPointer(location: Offset.zero);
    await pen.moveTo(tester.getCenter(find.text('Pen')));
    await tester.pump();
    expect(states.value, contains(WidgetState.hovered));
  });
}

class _Column extends StatefulWidget {
  const _Column({
    required this.title,
    required this.buttonStates,
    required this.switchStates,
    super.key,
  });

  final String title;
  final WidgetStatesController buttonStates;
  final WidgetStatesController switchStates;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  bool _on = false;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          widget.title,
          style: FluidTypography.style(
            FluidSizes.desktop.caption,
            color: colors.mutedForeground,
          ),
        ),
        FluidButton(
          onPressed: () {},
          variant: FluidButtonVariant.secondary,
          statesController: widget.buttonStates,
          child: const Text('Save draft'),
        ),
        FluidSwitch(
          value: _on,
          onChanged: (v) => setState(() => _on = v),
          statesController: widget.switchStates,
          label: const Text('Sync'),
        ),
        FluidTabs(
          tabs: const [
            FluidTab(label: Text('Day')),
            FluidTab(label: Text('Week')),
            FluidTab(label: Text('Month')),
          ],
          selectedIndex: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
      ],
    );
  }
}
