import 'dart:ui' show CheckedState;

import 'package:coil/coil.dart';
import 'package:coil_cli/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  CoilThemeData theme = CoilThemeData.light,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Directionality(
    textDirection: direction,
    child: CoilTheme(
      data: theme.copyWith(tier: tier),
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

/// A checkbox card that keeps its own value.
class _Checkable extends StatefulWidget {
  const _Checkable({
    this.initial = false,
    this.enabled = true,
    this.title = 'Kubernetes',
    this.motions,
  });

  final bool initial;
  final bool enabled;
  final String title;
  final Map<CoilChoiceCardTrack<Object>, Motion>? motions;

  @override
  State<_Checkable> createState() => _CheckableState();
}

class _CheckableState extends State<_Checkable> {
  late bool value = widget.initial;

  @override
  Widget build(BuildContext context) => CoilChoiceCard(
    selected: value,
    enabled: widget.enabled,
    motions: widget.motions,
    title: Text(widget.title),
    description: const Text('Run GPU workloads on a K8s cluster.'),
    control: CoilCheckbox(
      value: value,
      onChanged: widget.enabled
          ? (v) => setState(() => value = v ?? false)
          : null,
    ),
  );
}

/// The card's border and fill as painted.
ShapeDecoration _look(WidgetTester tester, [int index = 0]) =>
    tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(CoilChoiceCard),
                matching: find.byType(DecoratedBox),
              ),
            )
            .where(
              (box) =>
                  box.decoration is ShapeDecoration &&
                  (box.decoration as ShapeDecoration).shape
                      is RoundedSuperellipseBorder,
            )
            .elementAt(index)
            .decoration
        as ShapeDecoration;

Color _border(WidgetTester tester) =>
    (_look(tester).shape as RoundedSuperellipseBorder).side.color;

/// Whether any focus ring in [finder] is showing.
bool _ringShows(WidgetTester tester, Finder finder) => tester
    .widgetList<CoilFocusRing>(
      find.descendant(of: finder, matching: find.byType(CoilFocusRing)),
    )
    .any((ring) => ring.visible);

bool _cardRing(WidgetTester tester) => tester
    .widget<CoilFocusRing>(
      find
          .descendant(
            of: find.byType(CoilChoiceCard),
            matching: find.byType(CoilFocusRing),
          )
          .first,
    )
    .visible;

bool _checkboxRing(WidgetTester tester) => _ringShows(
  tester,
  find.byType(CoilCheckbox),
);

const _cards = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 12,
  children: [
    _Checkable(initial: true),
    _Checkable(title: 'Virtual machine'),
  ],
);

void main() {
  setUp(CoilInputModality.debugReset);

  matrixGoldenTest(
    'choice_card',
    (context) => SizedBox(
      width: 320,
      child: CoilFieldGroup(
        children: [
          CoilChoiceCard(
            selected: true,
            title: const Text('Kubernetes'),
            description: const Text('Run GPU workloads on a K8s cluster.'),
            control: CoilCheckbox(value: true, onChanged: (_) {}),
          ),
          CoilChoiceCard(
            title: const Text('Virtual machine'),
            description: const Text('Access a cluster to run GPU workloads.'),
            control: CoilCheckbox(value: false, onChanged: (_) {}),
          ),
          CoilChoiceCard(
            selected: true,
            title: const Text('Email digests'),
            control: CoilSwitch(value: true, onChanged: (_) {}),
          ),
          const CoilChoiceCard(
            enabled: false,
            title: Text('Bare metal'),
            description: Text('Not available in your region.'),
            control: CoilCheckbox(value: false, onChanged: null),
          ),
        ],
      ),
    ),
  );

  testWidgets('states sheet: rest, hover, keyboard focus, touch press', (
    tester,
  ) async {
    Widget column(BuildContext context) => const SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _Checkable(title: 'Rest'),
          _Checkable(title: 'Hovered'),
          _Checkable(title: 'Keyboard focus'),
          _Checkable(title: 'Selected', initial: true),
        ],
      ),
    );
    final sheet = await pumpSheet(
      tester,
      FocusScope(
        autofocus: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final tier in CoilTier.values)
              ThemedPair(
                title: 'ChoiceCard · ${tier.name}',
                tier: tier,
                builder: column,
              ),
          ],
        ),
      ),
    );
    // Focus the "Keyboard focus" card's checkbox in the first panel, then
    // press a key that does nothing so the keyboard is the last input.
    final keyboardCard = find
        .ancestor(
          of: find.text('Keyboard focus').first,
          matching: find.byType(CoilChoiceCard),
        )
        .first;
    Focus.of(
      tester.element(
        find.descendant(
          of: keyboardCard,
          matching: find.byType(CoilCheckboxIndicator),
        ),
      ),
    ).requestFocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    // The first panel (pointer, light): touch never hovers.
    await mouse.moveTo(tester.getCenter(find.text('Hovered').first));
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/choice_card_states.png');
  });

  testWidgets('a tap anywhere on the card toggles its control', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Checkable()));
    final semantics = tester.ensureSemantics();
    await tester.tap(find.text('Run GPU workloads on a K8s cluster.'));
    await tester.pumpAndSettle();
    expect(tester.widget<CoilCheckbox>(find.byType(CoilCheckbox)).value, true);
    expect(
      tester.widget<CoilChoiceCard>(find.byType(CoilChoiceCard)).selected,
      true,
    );
    // A tap on the checkbox itself toggles once, not twice.
    await tester.tap(find.byType(CoilCheckbox));
    await tester.pumpAndSettle();
    expect(tester.widget<CoilCheckbox>(find.byType(CoilCheckbox)).value, false);
    semantics.dispose();
  });

  testWidgets('a disabled card does nothing', (tester) async {
    await tester.pumpWidget(_app(const _Checkable(enabled: false)));
    await tester.tap(find.text('Kubernetes'));
    await tester.pumpAndSettle();
    expect(tester.widget<CoilCheckbox>(find.byType(CoilCheckbox)).value, false);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Kubernetes')));
    await tester.pumpAndSettle();
    expect(_look(tester).color!.a, 0, reason: 'no hover fill');
  });

  testWidgets('keyboard focus rings the card, not the checkbox', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_cards));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_cardRing(tester), isTrue);
    expect(_checkboxRing(tester), isFalse, reason: 'one ring');

    // Space still toggles the focused checkbox.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoilChoiceCard>(find.byType(CoilChoiceCard).first).selected,
      isFalse,
    );
  });

  testWidgets('a click shows no ring', (tester) async {
    await tester.pumpWidget(_app(_cards));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(tester.getCenter(find.text('Kubernetes')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_ringShows(tester, find.byType(CoilChoiceCard)), isFalse);
  });

  testWidgets('a checkbox outside a card keeps its own ring', (tester) async {
    await tester.pumpWidget(
      _app(CoilCheckbox(value: false, onChanged: (_) {})),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_checkboxRing(tester), isTrue);
  });

  testWidgets('hovering the card fills it and lights the checkbox', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Checkable()));
    final rest = tester.widget<CoilCheckboxIndicator>(
      find.byType(CoilCheckboxIndicator),
    );
    expect(rest.states, isNot(contains(WidgetState.hovered)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(
        find.text('Run GPU workloads on a K8s cluster.'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_look(tester).color, CoilThemeData.light.colors.hover);
    expect(
      tester
          .widget<CoilCheckboxIndicator>(find.byType(CoilCheckboxIndicator))
          .states,
      contains(WidgetState.hovered),
    );
  });

  testWidgets('a touch presses without leaving hover behind', (tester) async {
    await tester.pumpWidget(_app(const _Checkable(), tier: CoilTier.touch));
    final touch = await tester.startGesture(
      tester.getCenter(find.text('Kubernetes')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_look(tester).color, CoilThemeData.light.colors.active);
    await touch.up();
    await tester.pumpAndSettle();
    expect(_look(tester).color!.a, 0, reason: 'no sticky state');
    expect(
      tester
          .widget<CoilCheckboxIndicator>(find.byType(CoilCheckboxIndicator))
          .states,
      isNot(contains(WidgetState.hovered)),
    );
  });

  testWidgets('selected darkens the border', (tester) async {
    await tester.pumpWidget(_app(const _Checkable()));
    final rest = _border(tester);
    expect(rest, CoilThemeData.light.colors.border);
    await tester.tap(find.text('Kubernetes'));
    await tester.pumpAndSettle();
    expect(
      _border(tester),
      CoilThemeData.light.colors.foreground.withValues(alpha: 0.4),
    );
  });

  testWidgets('touch: the checkbox sits on the title line, not in a 44 '
      'hit box', (tester) async {
    await tester.pumpWidget(_app(const _Checkable(), tier: CoilTier.touch));
    final box = tester.getRect(find.byType(CoilCheckboxIndicator));
    final title = tester.getRect(find.text('Kubernetes'));
    expect((box.center.dy - title.center.dy).abs(), lessThan(1.5));
  });

  testWidgets('one semantics node: checkbox, title and description', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Checkable(initial: true)));
    final node = tester.getSemantics(find.byType(CoilCheckbox));
    final data = node.getSemanticsData();
    expect(data.label, contains('Kubernetes'));
    expect(data.label, contains('Run GPU workloads'));
    expect(data.flagsCollection.isChecked, CheckedState.isTrue);
    semantics.dispose();
  });

  testWidgets('follows the checkbox pattern', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(const _Checkable(), direction: direction),
      );
      await expectCoilPattern(
        tester,
        find.byType(CoilChoiceCard),
        CoilPattern.checkbox,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    }
  });

  testWidgets('follows the switch pattern', (tester) async {
    var on = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CoilChoiceCard(
            selected: on,
            title: const Text('Email digests'),
            control: CoilSwitch(
              value: on,
              onChanged: (v) => setState(() => on = v),
            ),
          ),
        ),
      ),
    );
    await expectCoilPattern(
      tester,
      find.byType(CoilChoiceCard),
      CoilPattern.switchControl,
    );
  });

  testWidgets('runtime motions override the fill track', (tester) async {
    final instant = {CoilChoiceCardTrack.fill: const Motion.instant()};
    await tester.pumpWidget(_app(_Checkable(motions: instant)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Kubernetes')));
    await tester.pump();
    await tester.pump();
    expect(_look(tester).color, CoilThemeData.light.colors.hover);
  });

  testWidgets('style: theme override beats fallback, instance beats theme', (
    tester,
  ) async {
    const themeRadius = 3.0;
    const instanceRadius = 5.0;
    Widget card({CoilChoiceCardStyle? style}) => CoilChoiceCard(
      title: const Text('A'),
      style: style,
      control: CoilCheckbox(value: false, onChanged: (_) {}),
    );
    double radius() =>
        ((_look(tester).shape as RoundedSuperellipseBorder).borderRadius
                as BorderRadius)
            .topLeft
            .x;
    final theme = CoilThemeData.light.withComponentStyle(
      const CoilChoiceCardStyle(radius: themeRadius),
    );
    await tester.pumpWidget(_app(card(), theme: theme));
    expect(radius(), themeRadius);
    await tester.pumpWidget(
      _app(
        card(style: const CoilChoiceCardStyle(radius: instanceRadius)),
        theme: theme,
      ),
    );
    expect(radius(), instanceRadius);
  });
}
