import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

/// A button that opens a dialog and records how it closed.
class _Opener extends StatelessWidget {
  const _Opener({
    required this.results,
    this.kind = CoilDialogKind.confirmation,
    this.dismissible = true,
  });

  final List<Object?> results;
  final CoilDialogKind kind;
  final bool dismissible;

  @override
  Widget build(BuildContext context) => Center(
    child: CoilButton(
      onPressed: () async {
        final result = await showCoilDialog<String>(
          context: context,
          kind: kind,
          dismissible: dismissible,
          builder: (context) => CoilDialog(
            title: const Text('Delete file?'),
            description: const Text('This cannot be undone.'),
            onClose: () => Navigator.pop(context, 'closed'),
            actions: [
              CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
              CoilButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        results.add(result);
      },
      child: const Text('Open'),
    ),
  );
}

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Escape closes it and focus returns to the trigger', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final results = <Object?>[];
    await tester.pumpWidget(testApp(home: _Opener(results: results)));
    // Focus the trigger with the keyboard, then open it with Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsOneWidget);
    expect(
      CoilSurface.levelOf(tester.element(find.text('Delete file?'))),
      5,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsNothing);
    expect(results, [null]);
    final trigger = Focus.of(tester.element(find.text('Open')));
    expect(trigger.hasFocus, isTrue);
  });

  testWidgets('an action and the close button pop with their value', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final results = <Object?>[];
    await tester.pumpWidget(testApp(home: _Opener(results: results)));
    await open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(results, ['delete', 'closed']);
  });

  testWidgets('a non-dismissible dialog ignores the scrim and Escape', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    final results = <Object?>[];
    await tester.pumpWidget(
      testApp(home: _Opener(results: results, dismissible: false)),
    );
    await open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsOneWidget);
    expect(results, isEmpty);
  });

  group('on a phone', () {
    testWidgets('a form opens as a sheet, primary action first', (
      tester,
    ) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: const _Opener(results: [], kind: CoilDialogKind.form),
        ),
      );
      await open(tester);
      expect(find.byType(CoilSheetPanel), findsOneWidget);
      final delete = tester.getTopLeft(find.text('Delete'));
      final cancel = tester.getTopLeft(find.text('Cancel'));
      expect(delete.dy, lessThan(cancel.dy));
    });

    testWidgets('a confirmation stays centered', (tester) async {
      useScreen(tester, TestScreen.phone);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.touch,
          home: const _Opener(results: []),
        ),
      );
      await open(tester);
      expect(find.byType(CoilSheetPanel), findsNothing);
      expect(find.text('Delete file?'), findsOneWidget);
    });
  });
}
