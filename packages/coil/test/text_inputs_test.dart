import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
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
  group('CoilTextarea', () {
    testWidgets('grows from 3 to 10 lines, then scrolls (pointer)', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(CoilTextarea(controller: controller)));
      double height() => tester.getSize(find.byType(CoilTextarea)).height;
      // 3 × 20 + 2 × 8: the first line sits where an input's text does.
      expect(height(), 76);
      controller.text = List.filled(5, 'line').join('\n');
      await tester.pump();
      expect(height(), 116);
      controller.text = List.filled(30, 'line').join('\n');
      await tester.pump();
      expect(height(), 216);
    });

    testWidgets('touch sizes: 3 × 22 + 2 × 11', (tester) async {
      await tester.pumpWidget(_app(const CoilTextarea(), tier: CoilTier.touch));
      expect(tester.getSize(find.byType(CoilTextarea)).height, 88);
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
                child: CoilTextarea(
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
        _app(const CoilField(label: Text('Notes'), child: CoilTextarea())),
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

    testWidgets('fields are 12 apart on pointer and 16 on touch', (
      tester,
    ) async {
      for (final (tier, gap) in [
        (CoilTier.pointer, 12.0),
        (CoilTier.touch, 16.0),
      ]) {
        await tester.pumpWidget(_app(group(), tier: tier));
        final first = tester.getRect(find.byType(CoilField).first);
        final second = tester.getRect(find.byType(CoilField).last);
        expect(second.top - first.bottom, gap, reason: tier.name);
      }
    });

    testWidgets('Tab moves between fields', (tester) async {
      await tester.pumpWidget(_app(group()));
      await tester.tap(find.byType(CoilInput).first);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find
            .descendant(
              of: find.byType(CoilInput).last,
              matching: find.byWidget(focused.widget),
            )
            .evaluate(),
        isNotEmpty,
      );
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
          const CoilTextarea(placeholder: Text('Tell us more')),
          CoilTextarea(
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
