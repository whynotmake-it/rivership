import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String page = 'Inbox';

  @override
  Widget build(BuildContext context) => CoilSidebarScaffold(
    sidebar: CoilSidebar(
      children: [
        CoilSidebarGroup(
          label: 'Mail',
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
    body: Builder(
      builder: (context) => Center(
        child: CoilButton(
          onPressed: CoilSidebarScaffold.of(context).toggle,
          child: Text('Page $page'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('in a wide window the sidebar sits beside the page and folds '
      'away', (tester) async {
    useScreen(tester, TestScreen.desktop);
    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pumpWidget(
      testApp(tier: CoilTier.pointer, home: const _App()),
    );
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(find.text('Page Sent'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Sent')).flagsCollection.isSelected,
      isNotNull,
    );

    await tester.tap(find.text('Page Sent'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Inbox'), findsNothing);
    expect(tester.getTopLeft(find.text('Page Sent')).dx, lessThan(800));

    // Ctrl+B unfolds it again while focus is inside.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Inbox'), findsOneWidget);
  });

  testWidgets('on a phone it opens as a drawer that a pick closes', (
    tester,
  ) async {
    useScreen(tester, TestScreen.phone);
    await tester.pumpWidget(testApp(tier: CoilTier.touch, home: const _App()));
    expect(find.text('Inbox'), findsNothing);
    await tester.tap(find.text('Page Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(find.text('Page Sent'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
  });
}
