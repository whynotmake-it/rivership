import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => withOverlay(
    CoilTheme(
      data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
      child: Center(child: SizedBox(width: 240, child: child)),
    ),
  ),
);

void main() {
  group('CoilInput', () {
    testWidgets('types, keeps IME composing, and submits', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;
      final changes = <String>[];
      await tester.pumpWidget(
        _app(
          CoilInput(
            controller: controller,
            placeholder: const Text('Name'),
            onChanged: changes.add,
            onSubmitted: (v) => submitted = v,
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(find.text('Name'), findsOneWidget);

      // An IME composition (e.g. Japanese): the composing range must
      // survive untouched, and the placeholder hides.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'にほ',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(controller.value.composing, const TextRange(start: 0, end: 2));
      expect(find.text('Name'), findsNothing);

      // Commit the composition, then submit.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '日本',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, '日本');
      expect(changes, ['にほ', '日本']);
    });

    testWidgets(
      'desktop shortcuts: select all and word deletion',
      (tester) async {
        final controller = TextEditingController(text: 'hello brave world');
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(CoilInput(controller: controller)));
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        // Collapse to the end, then delete the previous word.
        controller.selection = const TextSelection.collapsed(offset: 17);
        await tester.pump();
        final isMac = defaultTargetPlatform == TargetPlatform.macOS;
        final wordModifier = isMac
            ? LogicalKeyboardKey.alt
            : LogicalKeyboardKey.control;
        await tester.sendKeyDownEvent(wordModifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.sendKeyUpEvent(wordModifier);
        await tester.pump();
        expect(controller.text, 'hello brave ');
      },
      variant: TargetPlatformVariant.desktop(),
    );
  });
}
