import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

    Widget loadingButton({
      required bool loading,
      Widget? leading,
      String label = 'Save',
    }) => Directionality(
      textDirection: TextDirection.ltr,
      child: CoilTheme(
        data: goldenLight,
        child: Center(
          child: CoilButton(
            onPressed: () {},
            loading: loading,
            loadingIndicator: const SizedBox.square(
              dimension: 16,
              key: Key('custom-spinner'),
            ),
            leading: leading,
            child: Text(label, key: const Key('label')),
          ),
        ),
      ),
    );

    testWidgets('loading with a leading widget swaps it for the spinner '
        'in place, at the same size', (tester) async {
      const icon = TestIcon(TestGlyph.plus, key: Key('icon'));
      const spinner = Key('custom-spinner');
      await tester.pumpWidget(loadingButton(loading: false, leading: icon));
      final width = tester.getSize(find.byType(CoilButton)).width;

      await tester.pumpWidget(loadingButton(loading: true, leading: icon));
      await tester.pump(const Duration(milliseconds: 16));
      // Mid-swap: the icon is still leaving and the spinner arriving.
      expect(find.byKey(spinner), findsOneWidget);
      expect(find.byKey(const Key('icon')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('icon')), findsNothing);
      expect(tester.getSize(find.byType(CoilButton)).width, width);

      await tester.pumpWidget(loadingButton(loading: false, leading: icon));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(spinner), findsOneWidget, reason: 'it fades out');
      await tester.pumpAndSettle();
      expect(find.byKey(spinner), findsNothing);
      expect(tester.getSize(find.byType(CoilButton)).width, width);
    });

    testWidgets('loading without a leading widget grows the button by a '
        'spinner beside its still-visible label, and shrinks back', (
      tester,
    ) async {
      await tester.pumpWidget(loadingButton(loading: false));
      final idle = tester.getSize(find.byType(CoilButton)).width;
      final labelLeft = tester.getTopLeft(find.byKey(const Key('label'))).dx;

      await tester.pumpWidget(loadingButton(loading: true));
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getSize(find.byType(CoilButton)).width;
      expect(mid, greaterThan(idle), reason: 'it is growing');
      await tester.pumpAndSettle();
      final loading = tester.getSize(find.byType(CoilButton)).width;
      expect(loading, greaterThan(mid), reason: 'it was still growing');
      expect(find.byKey(const Key('custom-spinner')), findsOneWidget);
      expect(find.byKey(const Key('label')), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(const Key('label')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
        reason: 'the label stays visible',
      );
      // The spinner sits before the label, which moved over to make room.
      expect(
        tester.getTopLeft(find.byKey(const Key('label'))).dx,
        greaterThan(labelLeft),
      );
      expect(
        tester.getRect(find.byKey(const Key('custom-spinner'))).right,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('label'))).dx),
      );

      await tester.pumpWidget(loadingButton(loading: false));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CoilButton)).width, idle);
      expect(find.byKey(const Key('custom-spinner')), findsNothing);
    });

    testWidgets('a longer label springs the button wider instead of '
        'jumping', (tester) async {
      await tester.pumpWidget(loadingButton(loading: false));
      final short = tester.getSize(find.byType(CoilButton)).width;
      await tester.pumpWidget(loadingButton(loading: false, label: 'Saving…'));
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getSize(find.byType(CoilButton)).width;
      await tester.pumpAndSettle();
      final long = tester.getSize(find.byType(CoilButton)).width;
      expect(long, greaterThan(short));
      expect(mid, inExclusiveRange(short, long));
    });
  });
}
