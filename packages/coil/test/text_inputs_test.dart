import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  double width = 280,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => KeyedSubtree(
    key: UniqueKey(),
    child: withOverlay(
      CoilTheme(
        data: CoilThemeData.light.copyWith(tier: tier),
        child: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the caret is as tall as the text, not the line', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const CoilInput(autofocus: true)));
    await tester.pump();
    final editable = tester.allRenderObjects.whereType<RenderEditable>().first;
    final caret = editable.getLocalRectForCaret(const TextPosition(offset: 0));
    final field = CoilTheme.textOf(
      tester.element(find.byType(EditableText)),
    ).field;
    expect(caret.height, greaterThanOrEqualTo(field.fontSize!));
    expect(caret.height, lessThan(field.lineHeight));
  });

  group('CoilInput.multiline', () {
    testWidgets('grows with its text up to maxLines, then scrolls', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(CoilInput.multiline(controller: controller)),
      );
      Future<double> heightWith(int lines) async {
        controller.text = List.filled(lines, 'line').join('\n');
        await tester.pump();
        return tester.getSize(find.byType(CoilInput)).height;
      }

      final empty = await heightWith(0);
      expect(await heightWith(3), empty, reason: 'starts 3 lines tall');
      expect(await heightWith(5), greaterThan(empty));
      final ten = await heightWith(10);
      expect(await heightWith(30), ten, reason: 'stops growing at 10 lines');
    });

    testWidgets('its first line lines up with an input', (tester) async {
      await tester.pumpWidget(
        _app(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CoilInput(
                  controller: TextEditingController(text: 'Input'),
                ),
              ),
              Expanded(
                child: CoilInput.multiline(
                  controller: TextEditingController(text: 'Area'),
                ),
              ),
            ],
          ),
        ),
      );
      final input = tester.getRect(find.byType(EditableText).first);
      final area = tester.getRect(find.byType(EditableText).last);
      expect(area.top, input.top);
    });

    testWidgets('is a multi-line text field that never submits', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const CoilField(label: Text('Notes'), child: CoilInput.multiline()),
        ),
      );
      await tester.tap(find.text('Notes'));
      await tester.pump();
      expect(
        tester.testTextInput.setClientArgs!['inputAction'],
        'TextInputAction.newline',
      );
      final data = tester
          .getSemantics(find.byType(EditableText))
          .getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.flagsCollection.isMultiline, isTrue);
      expect(data.label, 'Notes');
      semantics.dispose();
    });
  });

  group('CoilInputGroup', () {
    testWidgets('Tab moves between fields', (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        _app(
          CoilInputGroup(
            children: [
              CoilField(
                label: const Text('First'),
                child: CoilInput(focusNode: first),
              ),
              CoilField(
                label: const Text('Second'),
                child: CoilInput(focusNode: second),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(CoilInput).first);
      await tester.pump();
      expect(first.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(second.hasFocus, isTrue);
    });
  });
}
