import 'dart:ui' show SemanticsValidationResult, Tristate;

import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

// The overlay builds its entry once, so every pump mounts a fresh one.
Widget _app(Widget child, {CoilTier tier = CoilTier.pointer}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => KeyedSubtree(
    key: UniqueKey(),
    child: withOverlay(
      CoilTheme(
        data: CoilThemeData.light.copyWith(tier: tier),
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  ),
);

/// The one node a field merges into: the text field's.
SemanticsNode _fieldNode(WidgetTester tester) =>
    tester.getSemantics(find.byType(EditableText));

void main() {
  group('CoilField semantics', () {
    testWidgets('label, description and error are announced with the control', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const CoilField(
            label: Text('Email'),
            description: Text('Only for receipts.'),
            error: Text('Enter an email address like ada@example.com'),
            isRequired: true,
            child: CoilInput(),
          ),
        ),
      );
      final node = _fieldNode(tester);
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.label, contains('Email'));
      expect(data.label, contains('Only for receipts.'));
      expect(
        data.label,
        contains('Enter an email address like ada@example.com'),
      );
      // The marker is visual; the flag says it.
      expect(data.label, isNot(contains('*')));
      expect(data.flagsCollection.isRequired, Tristate.isTrue);
      expect(data.validationResult, SemanticsValidationResult.invalid);
      expect(data.flagsCollection.isLiveRegion, isTrue);
      // The label comes first, then the description, then the error.
      final label = data.label;
      expect(label.indexOf('Email'), lessThan(label.indexOf('Only')));
      expect(label.indexOf('Only'), lessThan(label.indexOf('Enter')));
      // Nothing of the field is left as a separate node.
      expect(find.bySemanticsLabel('Email'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a valid optional field has no flags and no live region', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const CoilField(label: Text('Name'), child: CoilInput())),
      );
      final data = _fieldNode(tester).getSemanticsData();
      expect(data.label, 'Name');
      expect(data.flagsCollection.isRequired, isNot(Tristate.isTrue));
      expect(data.validationResult, SemanticsValidationResult.none);
      expect(data.flagsCollection.isLiveRegion, isFalse);
      semantics.dispose();
    });

    testWidgets('a field set is a container with a header legend', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const CoilFieldSet(
            legend: Text('Shipping'),
            children: [
              CoilField(label: Text('Street'), child: CoilInput()),
              CoilFieldSeparator(label: Text('or')),
              CoilField(label: Text('PO box'), child: CoilInput()),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Shipping')),
        isSemantics(label: 'Shipping', isHeader: true),
      );
      final fields = find.byType(EditableText);
      expect(
        tester.getSemantics(fields.first).getSemanticsData().label,
        'Street',
      );
      expect(
        tester.getSemantics(fields.last).getSemanticsData().label,
        'PO box',
      );
      semantics.dispose();
    });
  });

  group('CoilField behavior', () {
    testWidgets('a tap on the label focuses the input', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          CoilField(
            label: const Text('Email'),
            child: CoilInput(focusNode: focus),
          ),
        ),
      );
      expect(focus.hasFocus, isFalse);
      await tester.tap(find.text('Email'));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
    });

    testWidgets('a disabled control ignores label taps', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          CoilField(
            label: const Text('Email'),
            child: CoilInput(focusNode: focus, enabled: false),
          ),
        ),
      );
      await tester.tap(find.text('Email'));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('responsive fields go horizontal from 448 wide', (
      tester,
    ) async {
      Future<void> pumpAt(double width) => tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => CoilTheme(
            data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
            child: Center(
              child: SizedBox(
                width: width,
                child: const CoilField(
                  label: Text('Name'),
                  orientation: CoilFieldOrientation.responsive,
                  child: CoilInput(),
                ),
              ),
            ),
          ),
        ),
      );
      await pumpAt(400);
      final label = tester.getRect(find.text('Name'));
      final input = tester.getRect(find.byType(CoilInput));
      expect(label.bottom, lessThanOrEqualTo(input.top));

      await pumpAt(480);
      final labelWide = tester.getRect(find.text('Name'));
      final inputWide = tester.getRect(find.byType(CoilInput));
      expect(labelWide.right, lessThan(inputWide.left));
      expect(labelWide.center.dy, closeTo(inputWide.center.dy, 0.5));
    });

    testWidgets('spacing follows the tier', (tester) async {
      for (final (tier, labelGap, messageGap) in [
        (CoilTier.pointer, 6.0, 4.0),
        (CoilTier.touch, 6.0, 6.0),
      ]) {
        await tester.pumpWidget(
          _app(
            const CoilField(
              label: Text('Name'),
              description: Text('As on your ID.'),
              child: CoilInput(),
            ),
            tier: tier,
          ),
        );
        final label = tester.getRect(find.text('Name'));
        final input = tester.getRect(find.byType(CoilInput));
        final description = tester.getRect(find.text('As on your ID.'));
        expect(input.top - label.bottom, labelGap, reason: tier.name);
        expect(description.top - input.bottom, messageGap, reason: tier.name);
      }
    });
  });

  testWidgets('field sheet', (tester) async {
    Widget fields(BuildContext context) => SizedBox(
      width: 320,
      child: CoilFieldSet(
        legend: const Text('Account'),
        description: const Text('Used to sign in.'),
        children: [
          const CoilField(
            label: Text('Name'),
            isRequired: true,
            child: CoilInput(placeholder: Text('Ada Lovelace')),
          ),
          CoilField(
            label: const Text('Email'),
            description: const Text('Only for receipts.'),
            error: const Text('Enter an email address like ada@example.com'),
            child: CoilInput(
              controller: TextEditingController(text: 'ada@'),
            ),
          ),
          const CoilFieldSeparator(label: Text('or')),
          CoilField(
            label: const Text('Notifications'),
            description: const Text('Sent when a build finishes.'),
            orientation: CoilFieldOrientation.horizontal,
            child: CoilSwitch(value: true, onChanged: (_) {}),
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
              title: 'Field · ${tier.name}',
              tier: tier,
              builder: fields,
            ),
        ],
      ),
    );
    await expectSheetGolden(tester, finder, 'goldens/field.png');
  });
}
