import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/ink_centering.dart';
import 'src/test_icons.dart';

CoilSidebarAction _action(TestGlyph glyph, String label) => CoilSidebarAction(
  icon: TestIcon(glyph),
  semanticLabel: label,
  onPressed: () {},
);

/// A sidebar panel with every part: a bar with actions, a collapsible
/// group with actions, nested rows with a badge, status rows with actions
/// shown, a disabled row, and a key chip.
Widget _panel() => SizedBox(
  width: 260,
  height: 560,
  child: CoilSidebar(
    header: CoilSidebarBar(
      primary: CoilSidebarMenu(
        items: [
          CoilSidebarItem(
            label: const Text('Acme AI'),
            leading: const TestIcon(TestGlyph.home),
            trailing: CoilKbd('⌘K'),
            onPressed: () {},
          ),
        ],
      ),
      actions: [_action(TestGlyph.search, 'Search')],
    ),
    children: [
      CoilSidebarGroup(
        label: const Text('Workspace'),
        onExpandedChanged: (_) {},
        actions: [_action(TestGlyph.plus, 'Add')],
        child: CoilSidebarMenu(
          items: [
            CoilSidebarItem(
              label: const Text('Agents'),
              leading: const TestIcon(TestGlyph.heart),
              expanded: true,
              onExpandedChanged: (_) {},
              children: [
                CoilSidebarItem(
                  label: const Text('Research'),
                  selected: true,
                  onPressed: () {},
                ),
                CoilSidebarItem(
                  label: const Text('Support'),
                  trailing: const Text('3'),
                  onPressed: () {},
                ),
              ],
            ),
            CoilSidebarItem(
              label: const Text('Settings'),
              leading: const TestIcon(TestGlyph.settings),
              onExpandedChanged: (_) {},
              children: [
                CoilSidebarItem(label: const Text('Hidden'), onPressed: () {}),
              ],
            ),
            const CoilSidebarItem(
              label: Text('Disabled'),
              leading: TestIcon(TestGlyph.x),
            ),
          ],
        ),
      ),
      CoilSidebarGroup(
        label: const Text('Threads'),
        child: CoilSidebarMenu(
          items: [
            CoilSidebarItem(
              label: const Text('Unread thread'),
              status: CoilSidebarStatus.unread,
              trailing: const Text('4'),
              actions: [
                CoilAction(
                  label: 'Add',
                  leading: const TestIcon(TestGlyph.plus),
                  onPressed: () {},
                ),
                CoilAction(
                  label: 'Close',
                  leading: const TestIcon(TestGlyph.x),
                  onPressed: () {},
                ),
              ],
              actionsVisibility: CoilSidebarActionsVisibility.always,
              onPressed: () {},
            ),
            CoilSidebarItem(
              label: const Text('Idle thread'),
              status: CoilSidebarStatus.idle,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ],
  ),
);

void main() {
  matrixGoldenTest(
    'sidebar',
    (context) => _panel(),
    surface: const Size(2400, 3400),
  );

  testWidgets('sidebar states sheet', (tester) async {
    final sheet = await pumpSheet(
      tester,
      Builder(
        builder: (context) => CoilTheme(
          data: CoilThemeData.light,
          child: CoilAdaptiveScope(
            tier: CoilTier.pointer,
            child: ColoredBox(
              color: CoilColors.light.background,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _panel(),
              ),
            ),
          ),
        ),
      ),
      surface: const Size(300, 600),
    );
    // A mouse hovers one row, and the keyboard focuses another.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Idle thread')));
    await tester.pumpAndSettle();
    tester
        .widget<CoilInteraction>(
          find.ancestor(
            of: find.text('Research'),
            matching: find.byType(CoilInteraction),
          ),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();
    // An arrow key moves focus to Support, as the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await expectSheetGolden(tester, sheet, 'goldens/sidebar_states.png');
  });

  inkCenteringTests({
    'sidebar/row': (ink) => SizedBox(
      width: 220,
      child: CoilSidebarMenu(
        items: [
          CoilSidebarItem(
            label: InkLabel(ink, const Text('HEH')),
            semanticLabel: 'HEH',
            onPressed: () {},
          ),
        ],
      ),
    ),
    'sidebar/group label': (ink) => SizedBox(
      width: 220,
      child: CoilSidebarGroup(
        label: InkLabel(ink, const Text('HEH')),
        semanticLabel: 'HEH',
        onExpandedChanged: (_) {},
        child: const SizedBox.shrink(),
      ),
    ),
    'kbd': (ink) => CoilKbd.keys(
      const ['HEH'],
      style: ink
          ? null
          : const CoilKbdStyle(textStyle: TextStyle(color: Color(0x00000000))),
    ),
  });
}
