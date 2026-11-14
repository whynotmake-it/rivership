import 'dart:ui' show Tristate;

import 'package:coil/coil.dart';
import 'package:coil_cli/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';
import 'src/test_icons.dart';

/// Chat (with Threads and Drafts under it), Agents, and an unread thread
/// with an action and a badge.
class _Menu extends StatefulWidget {
  const _Menu({this.onAction});

  final VoidCallback? onAction;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  String page = 'Agents';
  bool chatOpen = false;

  CoilSidebarItem _leaf(String label) => CoilSidebarItem(
    label: Text(label),
    selected: page == label,
    onPressed: () => setState(() => page = label),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Page $page'),
      CoilSidebarMenu(
        items: [
          CoilSidebarItem(
            label: const Text('Chat'),
            leading: const TestIcon(TestGlyph.home),
            expanded: chatOpen,
            onExpandedChanged: (open) => setState(() => chatOpen = open),
            children: [_leaf('Threads'), _leaf('Drafts')],
          ),
          _leaf('Agents'),
          CoilSidebarItem(
            label: const Text('Fix login'),
            status: CoilSidebarStatus.unread,
            trailing: const Text('4'),
            actions: [
              CoilAction(
                label: const Text('Branch'),
                searchText: 'Branch',
                leading: const TestIcon(TestGlyph.plus),
                onPressed: widget.onAction,
              ),
              CoilSubmenu(
                label: const Text('More'),
                searchText: 'More',
                leading: const TestIcon(TestGlyph.settings),
                entries: [
                  CoilAction(
                    label: const Text('Rename'),
                    searchText: 'Rename',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
            onPressed: () => setState(() => page = 'Fix login'),
          ),
        ],
      ),
      CoilButton(onPressed: () {}, child: const Text('After')),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  CoilTier tier = CoilTier.pointer,
  VoidCallback? onAction,
  double width = 260,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(400, 600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      tier: tier,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: _Menu(onAction: onAction),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The label of the row that has focus.
String? _focusedRow(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  final texts = find.descendant(
    of: find.byElementPredicate((e) => e == focused),
    matching: find.byType(Text),
  );
  return texts.evaluate().isEmpty
      ? null
      : (texts.evaluate().first.widget as Text).data;
}

bool _shown(String label) =>
    find.text(label).hitTestable().evaluate().isNotEmpty;

void main() {
  testWidgets('Tab lands on the selected row', (tester) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(_focusedRow(tester), 'Agents');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(_focusedRow(tester), isNot('Fix login'), reason: 'one tab stop');
  });

  testWidgets('Up and Down rove the visible rows; Right and Left open, '
      'enter, leave and close a parent', (tester) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(_focusedRow(tester), 'Chat');
    // Folded, its children are skipped.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(_focusedRow(tester), 'Agents');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_shown('Threads'), isTrue);
    expect(_focusedRow(tester), 'Chat');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(_focusedRow(tester), 'Threads');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(_focusedRow(tester), 'Drafts');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Page Drafts'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(_focusedRow(tester), 'Chat');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_shown('Threads'), isFalse);
  });

  testWidgets('a parent row toggles its children on a press', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(_shown('Drafts'), isTrue);
    await tester.tap(find.text('Drafts'));
    await tester.pumpAndSettle();
    expect(find.text('Page Drafts'), findsOneWidget);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(_shown('Drafts'), isFalse);
  });

  testWidgets('a pointer reveals the actions while it hovers the row', (
    tester,
  ) async {
    var actions = 0;
    await _pump(tester, onAction: () => actions++);
    expect(find.bySemanticsLabel('Branch'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(390, 590));
    await mouse.moveTo(tester.getCenter(find.text('Fix login')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Branch'), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.bySemanticsLabel('Branch')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Page Agents'), findsOneWidget, reason: 'not a pick');

    await mouse.moveTo(const Offset(390, 590));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Branch'), findsNothing);
  });

  testWidgets('touch shows only the last action, and a long press opens '
      'them all', (tester) async {
    await _pump(tester, tier: CoilTier.touch);
    expect(find.bySemanticsLabel('Branch'), findsNothing);
    expect(find.bySemanticsLabel('More'), findsOneWidget);
    await tester.longPress(find.text('Fix login'));
    await tester.pumpAndSettle();
    expect(find.text('Branch'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('in a drawer at 2x text, the label still fits beside the '
      'action', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // The phone drawer's width.
    await _pump(tester, tier: CoilTier.touch, width: 320);
    final label = tester.getSize(find.text('Fix login'));
    final text = tester.renderObject<RenderParagraph>(find.text('Fix login'));
    // The whole label fits; nothing is cut off.
    expect(
      label.width,
      greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity)),
    );
    expect(text.didExceedMaxLines, isFalse);
  });

  testWidgets('a right-click opens the actions as a context menu', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(
      find.text('Fix login'),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Branch'), findsOneWidget);
  });

  testWidgets('an unread row says so', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(RegExp('^Fix login, unread')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('active status selects the row', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        home: CoilSidebarMenu(
          items: [
            CoilSidebarItem(
              label: const Text('Open thread'),
              status: CoilSidebarStatus.active,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Open thread'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('a row is a button with its states', (tester) async {
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: CoilSidebarMenu(
          items: [
            CoilSidebarItem(
              label: const Text('Inbox', key: ValueKey('target')),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await expectCoilPattern(
      tester,
      find.ancestor(
        of: find.byKey(const ValueKey('target')),
        matching: find.byType(CoilInteraction),
      ),
      CoilPattern.button,
    );
  });
}
