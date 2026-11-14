// CoilRadio under CoilRadioGroup.custom: the rows' keyboard model for any
// layout, and radio choice cards.
import 'package:coil/coil.dart';
import 'package:coil/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_matrix.dart';

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: CoilTheme(
      data: CoilThemeData.light.copyWith(tier: tier),
      child: FocusScope(
        autofocus: true,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    ),
  ),
);

const _plans = {
  'hobby': ('Hobby', 'For side projects.'),
  'pro': ('Pro', 'For teams that ship every day.'),
  'enterprise': ('Enterprise', 'SSO, audit logs and support.'),
};

/// Radio choice cards that keep their own value.
class _Plans extends StatefulWidget {
  const _Plans({
    this.initial = 'pro',
    this.disabled = const {},
    this.enabled = true,
  });

  final String initial;
  final Set<String> disabled;
  final bool enabled;

  @override
  State<_Plans> createState() => _PlansState();
}

class _PlansState extends State<_Plans> {
  late String value = widget.initial;

  @override
  Widget build(BuildContext context) => CoilRadioGroup<String>.custom(
    value: value,
    onChanged: widget.enabled ? (v) => setState(() => value = v) : null,
    semanticLabel: 'Plan',
    child: CoilFieldGroup(
      children: [
        for (final MapEntry(key: key, value: (title, description))
            in _plans.entries)
          CoilChoiceCard(
            selected: value == key,
            enabled: widget.enabled && !widget.disabled.contains(key),
            title: Text(title),
            description: Text(description),
            control: CoilRadio(
              value: key,
              enabled: !widget.disabled.contains(key),
            ),
          ),
      ],
    ),
  );
}

String? _selected(WidgetTester tester) => tester
    .widget<CoilRadioGroup<String>>(find.byType(CoilRadioGroup<String>))
    .value;

bool _anyRadioRing(WidgetTester tester) => tester
    .widgetList<CoilFocusRing>(
      find.descendant(
        of: find.byType(CoilRadio<String>),
        matching: find.byType(CoilFocusRing),
      ),
    )
    .any((ring) => ring.visible);

void main() {
  setUp(CoilInputModality.debugReset);

  matrixGoldenTest(
    'choice_card_radio',
    (context) => const SizedBox(width: 320, child: _Plans()),
  );

  testWidgets('follows the radio group pattern', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              const _Plans(),
              // Somewhere for Tab to go after the group.
              CoilButton(onPressed: () {}, child: const Text('After')),
            ],
          ),
          direction: direction,
        ),
      );
      await expectCoilPattern(
        tester,
        find.byType(CoilRadioGroup<String>),
        CoilPattern.radioGroup,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    }
  });

  testWidgets('a tap anywhere on a card selects it', (tester) async {
    await tester.pumpWidget(_app(const _Plans()));
    await tester.tap(find.text('SSO, audit logs and support.'));
    await tester.pumpAndSettle();
    expect(_selected(tester), 'enterprise');
    await tester.tap(find.byType(CoilRadio<String>).first);
    await tester.pumpAndSettle();
    expect(_selected(tester), 'hobby');
  });

  testWidgets('arrows skip a disabled radio', (tester) async {
    await tester.pumpWidget(
      _app(const _Plans(initial: 'hobby', disabled: {'pro'})),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_selected(tester), 'enterprise');
    await tester.tap(find.text('Pro'));
    await tester.pumpAndSettle();
    expect(_selected(tester), 'enterprise', reason: 'a disabled card');
  });

  testWidgets('a disabled group changes nothing', (tester) async {
    await tester.pumpWidget(_app(const _Plans(enabled: false)));
    await tester.tap(find.text('Hobby'));
    await tester.pumpAndSettle();
    expect(_selected(tester), 'pro');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<CoilRadioGroup<String>>(),
      isNull,
      reason: 'disabled radios take no focus',
    );
  });

  testWidgets('keyboard focus rings the card, not the radio', (tester) async {
    await tester.pumpWidget(_app(const _Plans()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final ring = tester.widget<CoilFocusRing>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Pro'),
              matching: find.byType(CoilChoiceCard),
            ),
            matching: find.byType(CoilFocusRing),
          )
          .first,
    );
    expect(ring.visible, isTrue, reason: 'Tab lands on the selected card');
    expect(_anyRadioRing(tester), isFalse);
  });

  testWidgets('a radio on its own shows its ring and a hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CoilRadioGroup<int>.custom(
          value: 1,
          onChanged: (_) {},
          child: const Row(
            children: [CoilRadio(value: 1), CoilRadio(value: 2)],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CoilFocusRing>(find.byType(CoilFocusRing))
          .where((ring) => ring.visible),
      hasLength(1),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(CoilRadio<int>).last),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CoilRadioIndicator>(
            find.descendant(
              of: find.byType(CoilRadio<int>).last,
              matching: find.byType(CoilRadioIndicator),
            ),
          )
          .states,
      contains(WidgetState.hovered),
    );
  });

  testWidgets('a touch selects without leaving hover behind', (tester) async {
    await tester.pumpWidget(_app(const _Plans(), tier: CoilTier.touch));
    await tester.tap(find.text('Hobby'));
    await tester.pumpAndSettle();
    expect(_selected(tester), 'hobby');
    for (final indicator in tester.widgetList<CoilRadioIndicator>(
      find.byType(CoilRadioIndicator),
    )) {
      expect(indicator.states, isNot(contains(WidgetState.hovered)));
    }
  });

  testWidgets('each card is one node: radio, title and description', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Plans()));
    final data = tester
        .getSemantics(find.byType(CoilRadio<String>).at(1))
        .getSemanticsData();
    expect(data.label, contains('Pro'));
    expect(data.label, contains('For teams'));
    expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    semantics.dispose();
  });
}
