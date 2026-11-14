import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';
import 'src/test_icons.dart';

/// A sidebar app: a collapsible "Mail" group of rows beside a page with a
/// trigger and a search field.
class _App extends StatefulWidget {
  const _App({
    this.controller,
    this.side = CoilSidebarSide.start,
    this.peek = CoilSidebarPeek.none,
  });

  final CoilSidebarController? controller;
  final CoilSidebarSide side;
  final CoilSidebarPeek peek;

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String page = 'Inbox';
  bool mailOpen = true;

  @override
  Widget build(BuildContext context) => CoilSidebarScaffold(
    controller: widget.controller,
    side: widget.side,
    peek: widget.peek,
    sidebar: CoilSidebar(
      children: [
        CoilSidebarGroup(
          label: 'Mail',
          expanded: mailOpen,
          onExpandedChanged: (open) => setState(() => mailOpen = open),
          child: CoilSidebarMenu(
            items: [
              for (final label in ['Inbox', 'Sent'])
                CoilSidebarItem(
                  label: label,
                  selected: page == label,
                  onPressed: () => setState(() => page = label),
                ),
            ],
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        const CoilSidebarTrigger(icon: TestIcon(TestGlyph.home)),
        Text('Page $page'),
        const SizedBox(width: 200, child: CoilInput()),
      ],
    ),
  );
}

void _useWide(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1200, 800);
  addTearDown(tester.view.reset);
}

Future<CoilSidebarController> _pumpWide(
  WidgetTester tester, {
  CoilSidebarSide side = CoilSidebarSide.start,
  CoilSidebarPeek peek = CoilSidebarPeek.none,
  bool open = true,
}) async {
  _useWide(tester);
  final controller = CoilSidebarController(open: open);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    testApp(
      tier: CoilTier.pointer,
      home: _App(controller: controller, side: side, peek: peek),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Drags the rail by [dx] with a mouse, in small steps, without letting go.
Future<TestGesture> _grabRail(WidgetTester tester, double dx) async {
  final rail = tester.getCenter(find.byType(CoilSidebarRail));
  final gesture = await tester.startGesture(
    rail,
    kind: PointerDeviceKind.mouse,
  );
  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump();
  }
  return gesture;
}

/// Whether a row shows where a pointer can reach it.
bool _rowShown(String label) =>
    find.text(label).hitTestable().evaluate().isNotEmpty;

void main() {
  group('rail', () {
    testWidgets('a drag resizes the sidebar between 160 and 360', (
      tester,
    ) async {
      final controller = await _pumpWide(tester);
      expect(tester.getSize(find.byType(CoilSidebar)).width, 256);

      var gesture = await _grabRail(tester, 400);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.width, 360);
      expect(tester.getSize(find.byType(CoilSidebar)).width, 360);

      gesture = await _grabRail(tester, -230);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.width, 160);
      expect(controller.open, isTrue);
    });

    testWidgets('on the right edge, dragging left widens it', (tester) async {
      final controller = await _pumpWide(tester, side: CoilSidebarSide.end);
      expect(tester.getTopLeft(find.byType(CoilSidebar)).dx, 1200 - 256);
      final gesture = await _grabRail(tester, -50);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.width, 306);
    });

    testWidgets('dragging 56 past the minimum folds it, and pulling back '
        'before release keeps it open', (tester) async {
      final controller = await _pumpWide(tester);

      // 256 → 120: past 160 but not by 56 yet.
      var gesture = await _grabRail(tester, -136);
      expect(controller.open, isTrue);
      expect(controller.width, 160);
      // Further, to 90: past the slop, it previews folding.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      expect(controller.open, isFalse);
      // Back to 200 before letting go: it opens again.
      await gesture.moveBy(const Offset(110, 0));
      await tester.pump();
      expect(controller.open, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.width, closeTo(200, 0.01));

      gesture = await _grabRail(tester, -200);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.open, isFalse);
      expect(_rowShown('Inbox'), isFalse);
      // The page takes the whole width back.
      expect(tester.getCenter(find.byType(CoilSidebarTrigger)).dx, 600);
    });

    testWidgets('a click folds the sidebar', (tester) async {
      final controller = await _pumpWide(tester);
      final rail = tester.getCenter(find.byType(CoilSidebarRail));
      await tester.tapAt(rail, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.open, isFalse);
    });

    testWidgets('the touch tier shows no rail', (tester) async {
      _useWide(tester);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _App()),
      );
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);
      expect(find.bySemanticsLabel('Resize or collapse sidebar'), findsNothing);
    });
  });

  group('shortcut', () {
    testWidgets('[ toggles while focus is inside the scaffold', (
      tester,
    ) async {
      final controller = await _pumpWide(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pumpAndSettle();
      expect(controller.open, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pumpAndSettle();
      expect(controller.open, isTrue);
    });

    testWidgets('a sidebar on the right answers ] instead', (tester) async {
      final controller = await _pumpWide(tester, side: CoilSidebarSide.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pumpAndSettle();
      expect(controller.open, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pumpAndSettle();
      expect(controller.open, isFalse);
    });

    testWidgets('typing [ in a text field types it', (tester) async {
      final controller = await _pumpWide(tester);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.enterText(find.byType(EditableText), '[');
      await tester.pumpAndSettle();
      expect(controller.open, isTrue);
      expect(find.text('['), findsOneWidget);
    });

    testWidgets('only the innermost scaffold holding focus answers', (
      tester,
    ) async {
      _useWide(tester);
      final outer = CoilSidebarController();
      final inner = CoilSidebarController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: CoilSidebarScaffold(
            controller: outer,
            sidebar: const CoilSidebar(children: [Text('Outer')]),
            body: CoilSidebarScaffold(
              controller: inner,
              drawerBreakpoint: 0,
              sidebar: const CoilSidebar(children: [Text('Inner')]),
              body: CoilButton(onPressed: () {}, child: const Text('Go')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Focus the button inside the inner scaffold.
      Focus.of(tester.element(find.text('Go'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pumpAndSettle();
      expect(inner.open, isFalse);
      expect(outer.open, isTrue);
    });

    testWidgets('a static sidebar ignores it', (tester) async {
      _useWide(tester);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: CoilSidebarScaffold(
            collapsible: CoilSidebarCollapsible.none,
            sidebar: const CoilSidebar(children: [Text('Always')]),
            body: CoilButton(onPressed: () {}, child: const Text('Go')),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pumpAndSettle();
      expect(find.text('Always'), findsOneWidget);
    });
  });

  group('peek', () {
    testWidgets('a press on the folded edge floats it out until Escape', (
      tester,
    ) async {
      final controller = await _pumpWide(
        tester,
        peek: CoilSidebarPeek.click,
        open: false,
      );
      expect(_rowShown('Inbox'), isFalse);
      final page = tester.getTopLeft(find.text('Page Inbox'));
      await tester.tap(find.bySemanticsLabel('Peek sidebar'));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);
      expect(controller.open, isFalse, reason: 'a peek never pins it');
      // It floats over the page instead of pushing it.
      expect(tester.getTopLeft(find.text('Page Inbox')), page);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
    });

    testWidgets('a press elsewhere dismisses it, a press inside does not', (
      tester,
    ) async {
      await _pumpWide(tester, peek: CoilSidebarPeek.click, open: false);
      await tester.tap(find.bySemanticsLabel('Peek sidebar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(find.text('Page Sent'), findsOneWidget);
      expect(_rowShown('Inbox'), isTrue);

      await tester.tapAt(const Offset(900, 400));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
    });

    testWidgets('a hovering mouse floats it out after a beat and lets go '
        'once it leaves', (tester) async {
      await _pumpWide(tester, peek: CoilSidebarPeek.hover, open: false);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(600, 400));
      await mouse.moveTo(const Offset(4, 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_rowShown('Inbox'), isFalse, reason: 'still within the intent');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);

      // Moving onto the card keeps it.
      await mouse.moveTo(const Offset(100, 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_rowShown('Inbox'), isTrue);

      await mouse.moveTo(const Offset(800, 400));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
    });

    testWidgets('a touch never peeks on the trigger', (tester) async {
      await _pumpWide(tester, peek: CoilSidebarPeek.hover, open: false);
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(CoilSidebarTrigger)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(_rowShown('Inbox'), isFalse);
      await finger.up();
      await tester.pumpAndSettle();
      // The tap itself opens it for good.
      expect(_rowShown('Inbox'), isTrue);
    });
  });

  group('keyboard', () {
    testWidgets('Tab reaches the group label, which Enter folds', (
      tester,
    ) async {
      await _pumpWide(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);
    });

    testWidgets('a folded sidebar leaves the focus order', (tester) async {
      await _pumpWide(tester, open: false);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.ancestor(
            of: find.byElementPredicate((e) => e == focused),
            matching: find.byType(CoilSidebar),
          ),
          findsNothing,
        );
      }
    });
  });

  group('drawer', () {
    testWidgets('on a phone the trigger opens a drawer that a pick closes', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _App()),
      );
      expect(_rowShown('Inbox'), isFalse);
      await tester.tap(find.byType(CoilSidebarTrigger));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(find.text('Page Sent'), findsOneWidget);
      expect(_rowShown('Inbox'), isFalse);
    });

    testWidgets('it shows the app state as it changes', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _App()),
      );
      await tester.tap(find.byType(CoilSidebarTrigger));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mail'));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
      await tester.tap(find.text('Mail'));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);
    });

    testWidgets('the scrim, Escape, back and a drag close it', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _App()),
      );
      Future<void> open() async {
        await tester.tap(find.byType(CoilSidebarTrigger));
        await tester.pumpAndSettle();
        expect(_rowShown('Inbox'), isTrue);
      }

      await open();
      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);

      await open();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);

      await open();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
      expect(find.text('Page Inbox'), findsOneWidget, reason: 'back stays');

      await open();
      await tester.fling(find.text('Mail'), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isFalse);
    });

    testWidgets('a short drag lets it settle back open', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(tier: CoilTier.touch, home: const _App()),
      );
      await tester.tap(find.byType(CoilSidebarTrigger));
      await tester.pumpAndSettle();
      await tester.timedDrag(
        find.text('Mail'),
        const Offset(-40, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(_rowShown('Inbox'), isTrue);
    });
  });

  testWidgets('the controller drives it and reports the rail', (tester) async {
    final controller = await _pumpWide(tester);
    controller.open = false;
    await tester.pumpAndSettle();
    expect(_rowShown('Inbox'), isFalse);
    controller
      ..width = 300
      ..open = true;
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CoilSidebar)).width, 300);
    controller.toggle();
    await tester.pumpAndSettle();
    expect(controller.open, isFalse);
  });

  testWidgets('the inset page is a card that meets the open sidebar', (
    tester,
  ) async {
    _useWide(tester);
    final controller = CoilSidebarController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: CoilSidebarScaffold(
          controller: controller,
          variant: CoilSidebarVariant.inset,
          sidebar: const CoilSidebar(children: [Text('Nav')]),
          body: const SizedBox.expand(key: ValueKey('page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = find.byKey(const ValueKey('page'));
    expect(tester.getRect(page), const Rect.fromLTRB(256, 8, 1192, 792));
    controller.open = false;
    await tester.pumpAndSettle();
    expect(tester.getRect(page), const Rect.fromLTRB(8, 8, 1192, 792));
  });
}
