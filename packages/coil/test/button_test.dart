import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

void main() {
  group('CoilButton', () {
    testWidgets('overview sheet', (tester) async {
      Widget button(
        CoilButtonVariant variant,
        SheetState state, {
        CoilSize? size,
        bool icons = false,
        bool iconOnly = false,
        bool loading = false,
      }) {
        final onPressed = state.isDisabled ? null : () {};
        if (iconOnly) {
          return CoilButton.icon(
            onPressed: onPressed,
            variant: variant,
            size: size,
            statesController: state.controller(),
            semanticLabel: 'Add',
            icon: const TestIcon(TestGlyph.plus),
          );
        }
        return CoilButton(
          onPressed: onPressed,
          variant: variant,
          size: size,
          loading: loading,
          statesController: state.controller(),
          leading: icons ? const TestIcon(TestGlyph.plus) : null,
          trailing: icons ? const TestIcon(TestGlyph.arrowRight) : null,
          child: Text(
            variant.name[0].toUpperCase() + variant.name.substring(1),
          ),
        );
      }

      final sheet = ThemedPair(
        title: 'Button',
        builder: (context) => StateTable(
          rows: [
            for (final v in CoilButtonVariant.values)
              SheetRow(v.name, (s) => button(v, s)),
            for (final v in CoilButtonVariant.values)
              SheetRow('${v.name} · icons', (s) => button(v, s, icons: true)),
            for (final v in CoilButtonVariant.values)
              SheetRow(
                '${v.name} · compact',
                (s) => button(v, s, size: CoilSize.compact),
              ),
            SheetRow(
              'icon',
              (s) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  for (final v in CoilButtonVariant.values)
                    button(v, s, iconOnly: true),
                ],
              ),
            ),
            SheetRow(
              'icon · compact',
              (s) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  for (final v in CoilButtonVariant.values)
                    button(
                      v,
                      s,
                      iconOnly: true,
                      size: CoilSize.compact,
                    ),
                ],
              ),
            ),
            SheetRow(
              'loading',
              (s) => button(CoilButtonVariant.primary, s, loading: true),
            ),
          ],
        ),
      );
      final finder = await pumpSheet(tester, sheet);
      await expectSheetGolden(tester, finder, 'goldens/button.png');
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
  });
}
