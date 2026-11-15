import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

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
    final metrics = CoilTheme.metricsOf(
      tester.element(find.byType(EditableText)),
    );
    expect(caret.height, greaterThanOrEqualTo(metrics.field.fontSize));
    expect(caret.height, lessThan(metrics.field.lineHeight));
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
    Widget group() => const CoilInputGroup(
      children: [
        CoilField(label: Text('First'), child: CoilInput()),
        CoilField(label: Text('Second'), child: CoilInput()),
      ],
    );

    testWidgets('mouse in the gap lights the nearest field; touch never '
        'hovers', (tester) async {
      const touchKey = ValueKey('touch');
      const mouseKey = ValueKey('mouse');
      Widget column(Key key, String title) => Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(title),
          SizedBox(width: 240, child: group()),
        ],
      );
      final finder = await pumpSheet(
        tester,
        SheetPanel(
          title: 'InputGroup: touch tapped vs mouse between fields',
          theme: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 48,
            children: [
              column(touchKey, 'touch: tapped the first field'),
              column(mouseKey, 'mouse: in the gap above "Second"'),
            ],
          ),
        ),
      );
      Finder inColumn(Key key, Finder f) =>
          find.descendant(of: find.byKey(key), matching: f);

      await tester.tap(inColumn(touchKey, find.byType(CoilInput)).first);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final first = tester.getRect(
        inColumn(mouseKey, find.byType(CoilInput)).first,
      );
      final second = tester.getRect(inColumn(mouseKey, find.text('Second')));
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(first.center.dx, second.top - 2));
      await tester.pumpAndSettle();
      await expectSheetGolden(tester, finder, 'goldens/input_group_hover.png');
    });

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

  testWidgets('text inputs sheet', (tester) async {
    Widget sheet(BuildContext context) => SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const CoilInput.multiline(placeholder: Text('Tell us more')),
          CoilInput.multiline(
            controller: TextEditingController(
              text:
                  'A longer note that wraps onto a second line and keeps '
                  'going for a third.',
            ),
            leading: const TestIcon(TestGlyph.heart),
            invalid: true,
          ),
          CoilInputGroup(
            children: [
              const CoilField(
                label: Text('Search'),
                child: CoilInput(
                  placeholder: Text('Files and folders'),
                  leading: TestIcon(TestGlyph.search),
                ),
              ),
              CoilField(
                label: const Text('Website'),
                error: const Text('Enter an address like example.com'),
                child: CoilInput(
                  controller: TextEditingController(text: 'example'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final finder = await pumpSheet(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tier in CoilTier.values)
            ThemedPair(
              title: 'Textarea, InputGroup · ${tier.name}',
              tier: tier,
              builder: sheet,
            ),
        ],
      ),
    );
    await expectSheetGolden(tester, finder, 'goldens/text_inputs.png');
  });
}
