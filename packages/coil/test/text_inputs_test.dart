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

/// The fill a text field paints (its chrome's `ShapeDecoration`).
Color _fill(WidgetTester tester, Finder field) =>
    (tester
                .widget<Container>(
                  find.descendant(of: field, matching: find.byType(Container)),
                )
                .decoration!
            as ShapeDecoration)
        .color!;

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

    testWidgets('a pill shape caps the textarea radius', (tester) async {
      final pill = CoilThemeData.light.copyWith(
        tier: CoilTier.pointer,
        shape: CoilShape.pill,
      );
      const metrics = CoilMetrics.pointer;
      expect(
        CoilInputStyle.fallback(pill, metrics, multiline: true).radius,
        12,
      );
      expect(CoilInputStyle.fallback(pill, metrics).radius, 20);
    });
  });

  group('CoilInputGroup', () {
    Widget group() => const CoilInputGroup(
      children: [
        CoilField(label: Text('First'), child: CoilInput()),
        CoilField(label: Text('Second'), child: CoilInput()),
      ],
    );

    testWidgets('the field nearest a mouse hovers, gaps included', (
      tester,
    ) async {
      await tester.pumpWidget(_app(group()));
      final first = find.byType(CoilInput).first;
      final second = find.byType(CoilInput).last;
      final hover = CoilThemeData.light.colors.hover;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(first));
      await tester.pumpAndSettle();
      expect(_fill(tester, first), hover);
      expect(_fill(tester, second).a, 0);

      // Between the first input and the second field's label: still a field.
      final gap = Offset(
        tester.getCenter(first).dx,
        tester.getRect(find.text('Second')).top - 4,
      );
      await mouse.moveTo(gap);
      await tester.pumpAndSettle();
      expect(_fill(tester, second), hover);
      expect(_fill(tester, first).a, 0);
    });

    testWidgets('a touch never hovers', (tester) async {
      await tester.pumpWidget(_app(group()));
      final first = find.byType(CoilInput).first;
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(_fill(tester, first).a, 0);
      expect(find.byType(CoilInput), findsNWidgets(2));
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
