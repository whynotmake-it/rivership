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

    for (final MapEntry(key: name, value: control)
        in <String, Widget Function(ValueChanged<Object?> changed)>{
          'switch': (changed) => CoilSwitch(value: false, onChanged: changed),
          'checkbox': (changed) =>
              CoilCheckbox(value: false, onChanged: changed),
        }.entries) {
      testWidgets('a tap on the label flips a $name', (tester) async {
        Object? changedTo;
        await tester.pumpWidget(
          _app(
            CoilField(
              label: const Text('Notifications'),
              child: control((value) => changedTo = value),
            ),
          ),
        );
        await tester.tap(find.text('Notifications'));
        await tester.pump();
        expect(changedTo, isTrue);
      });
    }

    testWidgets('an error appearing keeps the control focused and its text', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? error;
      late StateSetter setState;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return CoilField(
                label: const Text('Email'),
                error: error == null ? null : Text(error!),
                child: CoilInput(controller: controller),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(CoilInput));
      await tester.enterText(find.byType(EditableText), 'ada@');
      setState(() => error = 'Enter a full address.');
      await tester.pump();
      expect(find.text('Enter a full address.'), findsOneWidget);
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(controller.text, 'ada@');

      setState(() => error = null);
      await tester.pump();
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
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

    testWidgets('an error gives the input its invalid look', (tester) async {
      // The input in a field with an error looks exactly like an input
      // marked invalid by hand.
      Future<List<int>> render(Widget input) async {
        await tester.pumpWidget(_app(RepaintBoundary(child: input)));
        await tester.pumpAndSettle();
        final box = tester.renderObject<RenderRepaintBoundary>(
          find
              .ancestor(
                of: find.byType(CoilInput),
                matching: find.byType(RepaintBoundary),
              )
              .first,
        );
        final bytes = await tester.runAsync(() async {
          final image = await box.toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List();
        });
        return bytes!;
      }

      final byField = await render(
        const CoilField(
          error: Text('Enter an email address'),
          child: RepaintBoundary(child: CoilInput()),
        ),
      );
      final byHand = await render(const CoilInput(invalid: true));
      final valid = await render(const CoilInput());
      expect(byField, byHand);
      expect(byField, isNot(valid));
    });

    testWidgets('the label reaches a control that replaced the first one', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      Widget field(Widget control) =>
          _FieldHost(control: control, key: const ValueKey('host'));
      await tester.pumpWidget(_app(field(const CoilInput(key: ValueKey(1)))));
      tester
          .state<_FieldHostState>(find.byType(_FieldHost))
          .swap(CoilInput(key: const ValueKey(2), focusNode: focus));
      await tester.pump();
      await tester.tap(find.text('Email'));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });
  });

  group('CoilField layout motion', () {
    const message = 'Enter an address we can send receipts to.';

    Widget app({
      required ValueNotifier<String?> error,
      ValueNotifier<double>? width,
      bool reduceMotion = false,
    }) => WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: withOverlay(
          CoilTheme(
            data: goldenLight,
            child: Align(
              alignment: Alignment.topLeft,
              child: ListenableBuilder(
                listenable: Listenable.merge([error, ?width]),
                builder: (context, _) => SizedBox(
                  width: width?.value ?? 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CoilField(
                        label: const Text('Email'),
                        error: error.value == null ? null : Text(error.value!),
                        child: const CoilInput(),
                      ),
                      const SizedBox(key: Key('below'), height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    double fieldHeight(WidgetTester tester) =>
        tester.getSize(find.byType(CoilField)).height;

    double belowTop(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('below'))).dy;

    testWidgets('an error glides in and out, taking the gap with it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final error = ValueNotifier<String?>(null);
      await tester.pumpWidget(app(error: error));
      await tester.pumpAndSettle();
      final restHeight = fieldHeight(tester);
      final restBelow = belowTop(tester);

      error.value = message;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final growingHeight = fieldHeight(tester);
      final growingBelow = belowTop(tester);
      await tester.pumpAndSettle();
      final shownHeight = fieldHeight(tester);
      final shownBelow = belowTop(tester);
      expect(growingHeight, inExclusiveRange(restHeight, shownHeight));
      expect(growingBelow, inExclusiveRange(restBelow, shownBelow));
      // What follows moved by exactly what the field grew by.
      expect(shownBelow - restBelow, shownHeight - restHeight);
      final node = _fieldNode(tester).getSemanticsData();
      expect(node.label, contains(message));
      expect(node.flagsCollection.isLiveRegion, isTrue);

      error.value = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(fieldHeight(tester), inExclusiveRange(restHeight, shownHeight));
      expect(find.text(message), findsOneWidget, reason: 'it fades out');
      expect(
        _fieldNode(tester).getSemanticsData().label,
        isNot(contains(message)),
        reason: 'a leaving error is not read',
      );
      await tester.pumpAndSettle();
      expect(fieldHeight(tester), restHeight);
      expect(belowTop(tester), restBelow);
      expect(find.text(message), findsNothing);
      semantics.dispose();
    });

    testWidgets('under reduced motion the field jumps to the new layout', (
      tester,
    ) async {
      final error = ValueNotifier<String?>(null);
      await tester.pumpWidget(app(error: error, reduceMotion: true));
      await tester.pumpAndSettle();
      final restHeight = fieldHeight(tester);

      error.value = message;
      await tester.pump();
      final firstFrame = fieldHeight(tester);
      await tester.pumpAndSettle();
      expect(firstFrame, greaterThan(restHeight));
      expect(firstFrame, fieldHeight(tester));
    });

    testWidgets('a change of the available width relayouts at once', (
      tester,
    ) async {
      final error = ValueNotifier<String?>(message);
      final width = ValueNotifier<double>(400);
      await tester.pumpWidget(app(error: error, width: width));
      await tester.pumpAndSettle();
      final wide = fieldHeight(tester);

      // Narrower, so the message wraps onto more lines.
      width.value = 160;
      await tester.pump();
      final firstFrame = fieldHeight(tester);
      await tester.pumpAndSettle();
      expect(firstFrame, greaterThan(wide));
      expect(firstFrame, fieldHeight(tester), reason: 'nothing animated');
    });
  });
}

/// Keeps one field mounted while its control is swapped.
class _FieldHost extends StatefulWidget {
  const _FieldHost({required this.control, super.key});

  final Widget control;

  @override
  State<_FieldHost> createState() => _FieldHostState();
}

class _FieldHostState extends State<_FieldHost> {
  late Widget _control = widget.control;

  void swap(Widget control) => setState(() => _control = control);

  @override
  Widget build(BuildContext context) =>
      CoilField(label: const Text('Email'), child: _control);
}
