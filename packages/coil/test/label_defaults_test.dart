import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';
import 'src/test_icons.dart';

void main() {
  testWidgets('a Text label names and matches an action on its own', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final semantics = tester.ensureSemantics();
    final log = <String>[];

    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A chat action with no semanticLabel.
              CoilChatMessage(
                sender: CoilChatSender.user,
                entrance: .none,
                actions: [
                  CoilChatMessageAction(
                    label: const Text('Copy'),
                    icon: const TestIcon(TestGlyph.plus),
                    onPressed: () => log.add('copy'),
                  ),
                ],
                child: const Text('Hello'),
              ),
              // Menu actions with no searchText.
              CoilDropdown(
                search: const CoilMenuSearch(
                  placeholder: Text('Find'),
                  semanticLabel: 'Find',
                ),
                entries: [
                  CoilAction(
                    label: const Text('Rename'),
                    onPressed: () => log.add('rename'),
                  ),
                  CoilAction(
                    label: const Text('Duplicate'),
                    onPressed: () => log.add('duplicate'),
                  ),
                ],
                builder: (context, menu) => CoilButton(
                  onPressed: menu.open,
                  child: const Text('Actions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The icon-only meta-row button announces the label's text.
    expect(find.bySemanticsLabel('Copy'), findsOneWidget);

    // The search field matches the label's text, and picking the row runs
    // the action.
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'dup');
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);

    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(log, ['duplicate']);
    semantics.dispose();
  });
}
