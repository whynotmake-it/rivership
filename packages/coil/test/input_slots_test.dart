import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

const _field = ValueKey('field');
const _slot = ValueKey('slot');

/// Pumps [input] 320 wide, once: everything is measured on that frame.
Future<void> _pump(
  WidgetTester tester,
  Widget input, {
  CoilTier tier = CoilTier.pointer,
  CoilShape shape = CoilShape.rounded,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: goldenLight.copyWith(shape: shape),
        child: CoilAdaptiveScope(
          tier: tier,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, child: input),
          ),
        ),
      ),
    ),
  ),
);

Rect _fieldRect(WidgetTester tester) => tester.getRect(find.byKey(_field));
Rect _slotRect(WidgetTester tester) => tester.getRect(find.byKey(_slot));

/// The visual box of the button under [_slot] (its surface, without any
/// hit padding).
Rect _buttonRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byKey(_slot), matching: find.byType(CoilFocusRing))
      .first,
);

double _buttonRadius(WidgetTester tester) =>
    (tester
                .widget<CoilFocusRing>(
                  find
                      .descendant(
                        of: find.byKey(_slot),
                        matching: find.byType(CoilFocusRing),
                      )
                      .first,
                )
                .borderRadius
            as BorderRadius)
        .topLeft
        .x;

({double top, double bottom, double start, double end}) _insets(
  Rect field,
  Rect slot,
) => (
  top: slot.top - field.top,
  bottom: field.bottom - slot.bottom,
  start: slot.left - field.left,
  end: field.right - slot.right,
);

Widget _show({CoilSize? size, VoidCallback? onPressed}) => CoilButton(
  key: _slot,
  size: size,
  variant: CoilButtonVariant.secondary,
  onPressed: onPressed ?? () {},
  child: const Text('Show'),
);

void main() {
  group('CoilInput slots', () {
    testWidgets('an icon or a unit stays inline, the field keeps its height', (
      tester,
    ) async {
      await _pump(tester, const CoilInput(key: _field));
      final plain = _fieldRect(tester);

      await _pump(
        tester,
        const CoilInput(
          key: _field,
          leading: TestIcon(TestGlyph.search, key: _slot),
        ),
      );
      expect(_fieldRect(tester).height, plain.height);
      final icon = _slotRect(tester);
      // Inside the padding (12, the border included), centered.
      expect(icon.left - plain.left, 12);
      expect(icon.center.dy, closeTo(_fieldRect(tester).center.dy, 0.01));

      await _pump(
        tester,
        const CoilInput(
          key: _field,
          trailing: Text('EUR', key: _slot),
        ),
      );
      expect(_fieldRect(tester).height, plain.height);
      expect(_fieldRect(tester).right - _slotRect(tester).right, 12);
    });

    for (final tier in CoilTier.values) {
      for (final (name, shape) in [
        ('rounded', CoilShape.rounded),
        ('pill', CoilShape.pill),
        ('sharp', CoilShape.sharp),
      ]) {
        testWidgets('a button sits inset and concentric: ${tier.name}, $name', (
          tester,
        ) async {
          await _pump(
            tester,
            const CoilInput(key: _field),
            tier: tier,
            shape: shape,
          );
          final plain = _fieldRect(tester).height;

          // No size: the slot makes it compact.
          await _pump(
            tester,
            CoilInput(key: _field, trailing: _show()),
            tier: tier,
            shape: shape,
          );
          final field = _fieldRect(tester);
          final button = _buttonRect(tester);
          expect(field.height, plain, reason: 'the field keeps its height');
          final compact = const CoilMetricsTable().resolve(
            tier,
            CoilSize.compact,
          );
          expect(button.height, compact.controlHeight);
          final insets = _insets(field, button);
          expect(insets.top, 4);
          expect(insets.bottom, 4);
          expect(insets.end, 4);

          final radii = shape.radii(tier);
          final fieldRadius = radii.item;
          final expected = radii.container <= radii.item
              ? radii.item
              : CoilShape.nested(
                  fieldRadius < field.height / 2
                      ? fieldRadius
                      : field.height / 2,
                  4,
                );
          expect(_buttonRadius(tester), expected);
        });
      }
    }

    testWidgets('a pill button in a pill field is a pill', (tester) async {
      await _pump(
        tester,
        CoilInput(key: _field, trailing: _show()),
        shape: CoilShape.pill,
      );
      // 18 (36 / 2) − 4 = 14, half the 28 button.
      expect(_buttonRadius(tester), 14);
    });

    testWidgets('a button too tall for the field grows it minimally', (
      tester,
    ) async {
      await _pump(
        tester,
        CoilInput(
          key: _field,
          trailing: _show(size: CoilSize.regular),
        ),
      );
      final field = _fieldRect(tester);
      // A 36 button and 4 on each side.
      expect(field.height, 44);
      final insets = _insets(field, _buttonRect(tester));
      expect(insets.top, 4);
      expect(insets.bottom, 4);
      expect(insets.end, 4);
    });

    for (final tier in CoilTier.values) {
      for (final (name, shape) in [
        ('rounded', CoilShape.rounded),
        ('pill', CoilShape.pill),
      ]) {
        testWidgets(
          'a compact field keeps its height with a button, inset and '
          'concentric: ${tier.name}, $name',
          (tester) async {
            await _pump(
              tester,
              const CoilInput(key: _field, size: CoilSize.compact),
              tier: tier,
              shape: shape,
            );
            final plain = _fieldRect(tester).height;

            // Whether the slot makes it compact or the app says so.
            for (final size in [null, CoilSize.compact]) {
              var presses = 0;
              await _pump(
                tester,
                CoilInput(
                  key: _field,
                  size: CoilSize.compact,
                  trailing: _show(size: size, onPressed: () => presses++),
                ),
                tier: tier,
                shape: shape,
              );
              final field = _fieldRect(tester);
              final button = _buttonRect(tester);
              expect(field.height, plain, reason: 'the field keeps its height');
              final insets = _insets(field, button);
              expect(insets.top, greaterThan(0));
              expect(insets.bottom, insets.top);
              expect(insets.end, insets.top);
              final fieldRadius = shape.radii(tier).item;
              expect(
                _buttonRadius(tester),
                CoilShape.nested(
                  fieldRadius < field.height / 2
                      ? fieldRadius
                      : field.height / 2,
                  insets.top,
                ),
              );

              await tester.tap(find.byKey(_slot));
              expect(presses, 1);
            }
          },
        );
      }
    }

    testWidgets('inline keeps the button beside the text; the field grows', (
      tester,
    ) async {
      await _pump(
        tester,
        CoilInput(
          key: _field,
          trailing: _show(),
          trailingPlacement: CoilInputSlotPlacement.inline,
        ),
      );
      final field = _fieldRect(tester);
      // Out of the slot scope the button keeps its own regular size (36)
      // and corner, and the padding (8) stays around it.
      expect(_buttonRect(tester).height, 36);
      expect(field.height, 36 + 2 * 8);
      expect(_insets(field, _slotRect(tester)).end, 12);
      expect(_buttonRadius(tester), 8);
    });

    testWidgets('inset moves even a short slot into the padding', (
      tester,
    ) async {
      await _pump(
        tester,
        const CoilInput(
          key: _field,
          trailing: Text('EUR', key: _slot),
          trailingPlacement: CoilInputSlotPlacement.inset,
        ),
      );
      final field = _fieldRect(tester);
      final unit = _slotRect(tester);
      expect(field.height, 36);
      final insets = _insets(field, unit);
      expect(insets.end, closeTo(insets.top, 0.01));
      expect(insets.top, closeTo(insets.bottom, 0.01));
    });

    testWidgets('at 2× text the button stays evenly inset', (tester) async {
      await _pump(tester, const CoilInput(key: _field), textScale: 2);
      final plain = _fieldRect(tester).height;
      await _pump(
        tester,
        CoilInput(key: _field, trailing: _show()),
        textScale: 2,
      );
      final field = _fieldRect(tester);
      final button = _buttonRect(tester);
      final insets = _insets(field, button);
      expect(insets.top, closeTo(insets.bottom, 0.01));
      expect(insets.end, closeTo(insets.top, 0.01));
      expect(insets.top, greaterThanOrEqualTo(4));
      expect(
        field.height,
        closeTo(button.height + 8 > plain ? button.height + 8 : plain, 0.01),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('right to left mirrors the slots', (tester) async {
      await _pump(
        tester,
        CoilInput(
          key: _field,
          leading: const TestIcon(TestGlyph.search),
          trailing: _show(),
        ),
        direction: TextDirection.rtl,
      );
      final field = _fieldRect(tester);
      final insets = _insets(field, _buttonRect(tester));
      expect(insets.start, 4, reason: 'trailing is on the left');
      expect(insets.top, 4);
      final icon = tester.getRect(find.byType(TestIcon));
      expect(field.right - icon.right, 12);
      final text = tester.getRect(find.byType(EditableText));
      expect(text.left, greaterThan(_buttonRect(tester).right));
      expect(text.right, lessThan(icon.left));
    });

    testWidgets('multiline: inline slots on the first line, buttons in the '
        'bottom corner', (tester) async {
      await _pump(
        tester,
        CoilInput.multiline(
          key: _field,
          leading: const TestIcon(TestGlyph.plus),
          trailing: _show(),
        ),
      );
      final field = _fieldRect(tester);
      final text = tester.getRect(find.byType(EditableText));
      final icon = tester.getRect(find.byType(TestIcon));
      // The first of three lines.
      final line = text.height / 3;
      expect(icon.center.dy, closeTo(text.top + line / 2, 0.01));
      final insets = _insets(field, _buttonRect(tester));
      expect(insets.bottom, 4);
      expect(insets.end, 4);
      // The multi-line corner (8 under `rounded`) less the inset.
      expect(_buttonRadius(tester), 8 - 4);
    });

    testWidgets('the field still lines up on its baseline in a row', (
      tester,
    ) async {
      final style = goldenTypography.pointer.field;
      Widget row(Widget? trailing) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Label',
            key: const ValueKey('label'),
            style: style,
            strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
          ),
          Expanded(
            child: CoilInput(key: _field, trailing: trailing),
          ),
        ],
      );
      for (final trailing in [null, _show()]) {
        await _pump(tester, row(trailing));
        final label = tester.getRect(find.byKey(const ValueKey('label')));
        final text = tester.getRect(find.byType(EditableText));
        expect(label.top, closeTo(text.top, 0.01));
        expect(_fieldRect(tester).height, 36);
      }
    });

    testWidgets('the first frame is right, and so is the next after a swap', (
      tester,
    ) async {
      // One pumpWidget is one frame: no second pump.
      await _pump(tester, CoilInput(key: _field, trailing: _show()));
      var field = _fieldRect(tester);
      expect(field.height, 36);
      expect(_insets(field, _buttonRect(tester)).end, 4);

      // A unit becomes a button, and back, a frame each.
      await _pump(
        tester,
        const CoilInput(
          key: _field,
          trailing: Text('EUR', key: _slot),
        ),
      );
      field = _fieldRect(tester);
      expect(field.height, 36);
      expect(field.right - _slotRect(tester).right, 12);

      await _pump(tester, CoilInput(key: _field, trailing: _show()));
      field = _fieldRect(tester);
      expect(field.height, 36);
      expect(_insets(field, _buttonRect(tester)).end, 4);
    });

    testWidgets('dry layout and intrinsics agree with layout', (tester) async {
      await _pump(
        tester,
        CoilInput(
          key: _field,
          leading: const TestIcon(TestGlyph.search),
          trailing: _show(),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byKey(_field));
      final constraints = BoxConstraints.tightFor(width: box.size.width);
      expect(box.getDryLayout(constraints), box.size);
      expect(box.getMinIntrinsicHeight(box.size.width), box.size.height);
      expect(box.getMaxIntrinsicHeight(box.size.width), box.size.height);

      // A field in an IntrinsicWidth is as wide as its content.
      await _pump(
        tester,
        IntrinsicWidth(
          child: CoilInput(
            key: _field,
            controller: TextEditingController(text: 'abc'),
            trailing: _show(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_fieldRect(tester).height, 36);
    });

    testWidgets('on touch the rim around an inset button takes the tap', (
      tester,
    ) async {
      var pressed = 0;
      await _pump(
        tester,
        CoilInput(
          key: _field,
          trailing: _show(onPressed: () => pressed++),
        ),
        tier: CoilTier.touch,
      );
      final button = _buttonRect(tester);
      // 2 px above the button's surface, inside the field's border.
      await tester.tapAt(Offset(button.center.dx, button.top - 2));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });
  });

  group('CoilInputSlotScope', () {
    test('radiusFor nests in the field corner', () {
      CoilInputSlotScope scope(CoilShape shape, double fieldRadius) =>
          CoilInputSlotScope(
            size: CoilSize.compact,
            radii: shape.pointer,
            fieldRadius: fieldRadius,
            fieldHeight: 36,
            minInset: 4,
            child: const SizedBox(),
          );
      expect(scope(CoilShape.rounded, 8).radiusFor(28), 4);
      expect(scope(CoilShape.pill, 20).radiusFor(28), 14);
      expect(scope(CoilShape.sharp, 1).radiusFor(28), isNull);
      // A 36 button grows the field to 44: 8 − 4.
      expect(scope(CoilShape.rounded, 8).radiusFor(36), 4);
    });
  });
}
