import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_widgets/motor_widgets.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

void main() {
  group('CoilButton', () {
    testWidgets('a label too long for its room ends in an ellipsis', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CoilTheme(
            data: goldenLight,
            child: Center(
              child: SizedBox(
                width: 120,
                child: CoilButton(
                  onPressed: () {},
                  leading: const TestIcon(TestGlyph.plus),
                  trailing: const TestIcon(TestGlyph.arrowRight),
                  child: const Text('Update your payment method'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CoilButton)).width, 120);
      final text = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Update your payment method'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });

    testWidgets('activates on tap, Enter and Space', (tester) async {
      var count = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Center(
            child: CoilButton(
              onPressed: () => count++,
              focusNode: focusNode,
              child: const Text('Go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      expect(count, 1);
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(count, 3);
    });

    testWidgets('shows focus only for keyboard focus', (tester) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => FocusScope(
            autofocus: true,
            child: Center(
              child: CoilButton(
                onPressed: () {},
                statesController: states,
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      // Pointer interaction: focus is not visible.
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(states.value, isNot(contains(WidgetState.focused)));

      // Keyboard: Tab into the button shows focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(states.value, contains(WidgetState.focused));
    });

    testWidgets('exposes button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Center(
            child: CoilButton.icon(
              onPressed: () {},
              semanticLabel: 'Add item',
              icon: const TestIcon(TestGlyph.plus),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(CoilButton)),
        matchesSemantics(
          label: 'Add item',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    for (final withLeading in [false, true]) {
      testWidgets(
        'loading blur-fades both ways '
        '(${withLeading ? 'leading slot' : 'text only'})',
        (tester) async {
          Widget build({required bool loading}) => Directionality(
            textDirection: TextDirection.ltr,
            child: CoilTheme(
              data: goldenLight,
              child: Center(
                child: CoilButton(
                  onPressed: () {},
                  loading: loading,
                  loadingIndicator: const SizedBox(key: Key('custom-spinner')),
                  leading: withLeading
                      ? const TestIcon(TestGlyph.plus, key: Key('icon'))
                      : null,
                  child: const Text('Save', key: Key('label')),
                ),
              ),
            ),
          );
          final idle = withLeading
              ? find.byKey(const Key('icon'))
              : find.byKey(const Key('label'));
          final spinner = find.byKey(const Key('custom-spinner'));

          await tester.pumpWidget(build(loading: false));
          final switcher = tester.state(find.byType(MotionSwitcher));
          await tester.pumpWidget(build(loading: true));
          // The switcher keeps its state when the hidden label joins the
          // stack in front of it, so the swap animates instead of snapping.
          expect(tester.state(find.byType(MotionSwitcher)), same(switcher));
          await tester.pump(const Duration(milliseconds: 16));
          // Mid-swap: the idle content is still leaving and the spinner
          // arriving, both drawn by the switcher, not snapped.
          expect(spinner, findsOneWidget);
          expect(
            find.ancestor(of: idle, matching: find.byType(MotionSwitcher)),
            findsWidgets,
          );
          await tester.pumpAndSettle();
          expect(
            find.ancestor(of: idle, matching: find.byType(MotionSwitcher)),
            findsNothing,
          );

          await tester.pumpWidget(build(loading: false));
          await tester.pump(const Duration(milliseconds: 16));
          expect(spinner, findsOneWidget, reason: 'the spinner fades out');
          await tester.pumpAndSettle();
          expect(spinner, findsNothing);
        },
      );
    }
  });
}
