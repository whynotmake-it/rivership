import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _rows(int count) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < count; i++) SizedBox(height: 32, child: Text('Row $i')),
  ],
);

Widget _app(Widget child, {CoilTier tier = CoilTier.pointer}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: tier),
    child: navigator!,
  ),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) =>
        Center(child: SizedBox(width: 200, height: 160, child: child)),
  ),
);

/// [state]'s physics and their parents.
List<ScrollPhysics> _physicsOf(ScrollableState state) => [
  for (ScrollPhysics? p = state.position.physics; p != null; p = p.parent) p,
];

double _offsetOf(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  // A short area scrolled a little, so both edge fades show.

  testWidgets('a scrolling viewport is a tab stop; keys spring it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(40))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'CoilScrollArea',
    );
    expect(
      tester.widget<CoilFocusRing>(find.byType(CoilFocusRing)).visible,
      isTrue,
      reason: 'keyboard focus shows the inset ring',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final midway = _offsetOf(tester);
    await tester.pumpAndSettle();
    expect(_offsetOf(tester), 60);
    expect(midway, inExclusiveRange(0, 60), reason: 'it springs, not jumps');

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    final max = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .maxScrollExtent;
    expect(_offsetOf(tester), max);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(_offsetOf(tester), 0);
  });

  testWidgets('a key a nested area leaves alone scrolls the outer one', (
    tester,
  ) async {
    final outer = ScrollController();
    final inner = ScrollController();
    final innerFocus = FocusNode(debugLabel: 'inner');
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    addTearDown(innerFocus.dispose);
    await tester.pumpWidget(
      _app(
        CoilScrollArea(
          controller: outer,
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: CoilScrollArea(
                  controller: inner,
                  focusNode: innerFocus,
                  axis: Axis.horizontal,
                  child: const SizedBox(width: 800, height: 40),
                ),
              ),
              _rows(40),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    innerFocus.requestFocus();
    await tester.pumpAndSettle();

    // Right is the inner area's.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(inner.offset, greaterThan(0));
    expect(outer.offset, 0);

    // Down isn't: the outer area scrolls, and focus stays inside.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(outer.offset, greaterThan(0));
    expect(innerFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('content that fits is not a tab stop', (tester) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(2))));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('CoilScrollArea'),
    );
  });

  testWidgets('reduced motion makes keyboard scrolls instant', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(CoilScrollArea(child: _rows(40))),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(_offsetOf(tester), greaterThan(0));
  });

  testWidgets('.scrollable gives an existing list the same behavior', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        CoilScrollArea.scrollable(
          controller: controller,
          child: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (context, i) =>
                SizedBox(height: 32, child: Text('$i')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, 60);
  });

  testWidgets('a tap never shows the focus ring', (tester) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(40))));
    await tester.pump();
    await tester.tap(find.byType(CoilScrollArea));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoilFocusRing>(find.byType(CoilFocusRing)).visible,
      isFalse,
    );
  });

  testWidgets('a hovering mouse widens the bar; a touch never does', (
    tester,
  ) async {
    await tester.pumpWidget(_app(CoilScrollArea(child: _rows(40))));
    await tester.drag(
      find.byType(CoilScrollArea),
      const Offset(0, -40),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.pump();
    // The painter is the scrollbar's own state; reading it is test-only.
    ScrollbarPainter painter() =>
        (tester.state(find.byType(CoilScrollbar)) as RawScrollbarState)
            // ignore: invalid_use_of_protected_member
            .scrollbarPainter;
    final area = tester.getRect(find.byType(CoilScrollArea));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: area.center);
    await mouse.moveTo(area.centerRight - const Offset(4, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 6);

    await mouse.moveTo(area.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 4);

    // Dragging the thumb with the mouse keeps it wide and darker.
    // The thumb sits near the top: the list is scrolled 40 of ~1100.
    final thumb = area.topRight + const Offset(-4, 10);
    await mouse.moveTo(thumb);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.down(thumb);
    await mouse.moveBy(const Offset(0, 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 6);
    expect(
      painter().color,
      CoilThemeData.light.colors.foreground.withValues(alpha: 0.16),
    );
    await mouse.up();
    await mouse.moveTo(area.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // A finger on the bar's spot scrolls; it never widens it.
    final finger = await tester.startGesture(
      area.centerRight - const Offset(4, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().thickness, 4);
    await finger.up();
  });

  testWidgets('arrow keys in a text field inside move the caret, not the '
      'scroll', (tester) async {
    final text = TextEditingController(text: 'one\ntwo\nthree');
    final focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        CoilScrollArea(
          child: Column(
            children: [
              EditableText(
                controller: text,
                focusNode: focus,
                maxLines: null,
                style: const TextStyle(fontSize: 14),
                cursorColor: const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF000000),
              ),
              _rows(12),
            ],
          ),
        ),
      ),
    );
    focus.requestFocus();
    text.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final area = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(area.position.pixels, 0);
    expect(text.selection.baseOffset, greaterThan(0));
  });

  testWidgets('scrolls with the ambient behavior and draws only its own bar', (
    tester,
  ) async {
    // An app behavior unlike the platform's: clamping physics on macOS,
    // and a mouse that drags content.
    final behavior = const ScrollBehavior().copyWith(
      physics: const ClampingScrollPhysics(),
      dragDevices: PointerDeviceKind.values.toSet(),
    );
    await tester.pumpWidget(
      _app(
        ScrollConfiguration(
          behavior: behavior,
          child: CoilScrollArea(
            child: Column(
              children: [
                _rows(12),
                // A nested scrollable keeps the app's behavior.
                SizedBox(
                  height: 60,
                  child: ListView(
                    key: const ValueKey('nested'),
                    children: [_rows(4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final outer = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(_physicsOf(outer), contains(isA<ClampingScrollPhysics>()));
    final nested = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('nested')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(_physicsOf(nested), contains(isA<ClampingScrollPhysics>()));

    // A mouse drag scrolls, as the app's behavior allows.
    await tester.drag(
      find.byType(CoilScrollArea),
      const Offset(0, -40),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(outer.position.pixels, greaterThan(0));

    // One bar for the area: coil's, not the behavior's desktop bar too. The
    // nested list has the behavior's own.
    expect(find.byType(CoilScrollbar), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is RawScrollbar), findsNWidgets(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets("scrollbar: none draws no bar, not even the behavior's", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CoilScrollArea(
          scrollbar: CoilScrollbarVisibility.none,
          child: Column(
            children: [
              _rows(12),
              // A nested scrollable keeps the app's behavior and its bar.
              SizedBox(
                height: 60,
                child: ListView(
                  key: const ValueKey('nested'),
                  children: [_rows(4)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(CoilScrollbar), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is RawScrollbar),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nested')),
        matching: find.byWidgetPredicate((w) => w is RawScrollbar),
      ),
      findsOneWidget,
    );

    // The same for a list it wraps. (A new app: the route keeps its page.)
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(
        CoilScrollArea.scrollable(
          controller: controller,
          scrollbar: CoilScrollbarVisibility.none,
          child: ListView(controller: controller, children: [_rows(12)]),
        ),
      ),
    );
    expect(find.byWidgetPredicate((w) => w is RawScrollbar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('content that shrinks while scrolled to the end rebuilds the '
      'area after the frame', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    // Six rows of 32 in an area 160 tall scroll by 32.
    var count = 6;
    late StateSetter setState;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return CoilScrollArea.scrollable(
              controller: controller,
              // Physics that leave the offset past the new end, so the
              // list springs back, and the spring starts during layout.
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(
                  physics: const BouncingScrollPhysics(),
                ),
                child: ListView.builder(
                  controller: controller,
                  itemCount: count,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 32, child: Text('Row $i')),
                ),
              ),
            );
          },
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    // Five fit, so it no longer scrolls.
    setState(() => count = 5);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_offsetOf(tester), 0);
  });
}
