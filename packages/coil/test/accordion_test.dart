import 'dart:ui' show SemanticsRole, Tristate;

import 'package:coil/coil.dart';
import 'package:coil_cli/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart' show CupertinoMotion;

import 'src/ink_centering.dart';
import 'src/test_icons.dart';

const _panelText = 'Orders ship within two business days.';

List<CoilAccordionItem<String>> _items({bool disableLast = false}) => [
  const CoilAccordionItem(
    value: 'shipping',
    label: Text('Shipping'),
    semanticLabel: 'Shipping',
    leading: TestIcon(TestGlyph.home),
    panel: Text(_panelText),
  ),
  const CoilAccordionItem(
    value: 'returns',
    label: Text('Returns'),
    semanticLabel: 'Returns',
    panel: Text('Return anything within 30 days.'),
  ),
  CoilAccordionItem(
    value: 'support',
    label: const Text('Support'),
    semanticLabel: 'Support',
    enabled: !disableLast,
    panel: const Text('Write to us any time.'),
  ),
];

/// A page with a Navigator (Tab traversal needs one) and a button after the
/// accordion, so Tab can leave it.
Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
  CoilThemeData theme = CoilThemeData.light,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: theme.copyWith(tier: tier),
        child: navigator!,
      ),
    ),
  ),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(key: const ValueKey('target'), child: child),
            CoilButton(onPressed: () {}, child: const Text('After')),
          ],
        ),
      ),
    ),
  ),
);

final _target = find.byKey(const ValueKey('target'));

/// A single-mode accordion that applies its own changes.
class _Single extends StatefulWidget {
  const _Single({
    this.initial,
    this.collapsible = true,
    this.variant = CoilAccordionVariant.plain,
    this.disableLast = false,
    this.onChanged,
    this.motion,
  });

  final String? initial;
  final bool collapsible;
  final CoilAccordionVariant variant;
  final bool disableLast;
  final ValueChanged<String?>? onChanged;
  final CoilMotion? motion;

  @override
  State<_Single> createState() => _SingleState();
}

class _SingleState extends State<_Single> {
  late String? value = widget.initial;

  @override
  Widget build(BuildContext context) => CoilAccordion<String>.single(
    items: _items(disableLast: widget.disableLast),
    value: value,
    collapsible: widget.collapsible,
    variant: widget.variant,
    motion: widget.motion,
    onChanged: (next) {
      widget.onChanged?.call(next);
      setState(() => value = next);
    },
  );
}

Finder _trigger(String label) => find.ancestor(
  of: find.text(label).last,
  matching: find.byType(CoilInteraction),
);

/// Whether [label]'s panel shows (its text is in the semantics tree).
bool _isOpen(WidgetTester tester, String label) {
  final trigger = tester.getSemantics(_trigger(label));
  return trigger.getSemanticsData().flagsCollection.isExpanded ==
      Tristate.isTrue;
}

/// The trigger (or button) label holding focus.
String? get _focusedLabel {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  for (final text in ['Shipping', 'Returns', 'Support', 'After']) {
    final inside = find.descendant(
      of: find.byElementPredicate((e) => identical(e, context)),
      matching: find.text(text),
    );
    if (inside.evaluate().isNotEmpty) return text;
  }
  return null;
}

Set<WidgetState> _states(WidgetTester tester, String label) => tester
    .widget<CoilInteractionDetector>(
      find.descendant(
        of: _trigger(label),
        matching: find.byType(CoilInteractionDetector),
      ),
    )
    .states
    .value;

void main() {
  inkCenteringTests({
    'accordion/trigger': (ink) => SizedBox(
      width: 200,
      child: CoilAccordion<int>.single(
        items: const [
          CoilAccordionItem(
            value: 0,
            label: Text('HEH'),
            semanticLabel: 'HEH',
            panel: Text(''),
          ),
        ],
        value: null,
        onChanged: (_) {},
        // Only the label may ink: no chevron.
        indicator: const SizedBox.square(dimension: 12),
        style: ink
            ? null
            : const CoilAccordionStyle(
                label: WidgetStatePropertyAll(Color(0x00000000)),
              ),
      ),
    ),
  });

  group('pattern', () {
    for (final direction in TextDirection.values) {
      for (final variant in CoilAccordionVariant.values) {
        testWidgets('${variant.name} ${direction.name} is a disclosure', (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(_Single(variant: variant), direction: direction),
          );
          await expectCoilPattern(tester, _target, CoilPattern.disclosure);
        });
      }
    }
  });

  group('state', () {
    testWidgets('single: opening an item closes the open one', (
      tester,
    ) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        _app(_Single(initial: 'shipping', onChanged: changes.add)),
      );
      expect(_isOpen(tester, 'Shipping'), isTrue);

      await tester.tap(_trigger('Returns'));
      await tester.pumpAndSettle();
      expect(changes, ['returns']);
      expect(_isOpen(tester, 'Shipping'), isFalse);
      expect(_isOpen(tester, 'Returns'), isTrue);

      await tester.tap(_trigger('Returns'));
      await tester.pumpAndSettle();
      expect(changes, ['returns', null], reason: 'collapsible by default');
      expect(_isOpen(tester, 'Returns'), isFalse);
    });

    testWidgets('single without collapsible keeps one item open', (
      tester,
    ) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        _app(
          _Single(
            initial: 'shipping',
            collapsible: false,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(_trigger('Shipping'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(_isOpen(tester, 'Shipping'), isTrue);
    });

    testWidgets('multiple: items open and close independently', (
      tester,
    ) async {
      var values = <String>{'shipping'};
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => CoilAccordion<String>.multiple(
              items: _items(),
              values: values,
              onChanged: (next) => setState(() => values = next),
            ),
          ),
        ),
      );
      await tester.tap(_trigger('Support'));
      await tester.pumpAndSettle();
      expect(values, {'shipping', 'support'});
      expect(_isOpen(tester, 'Shipping'), isTrue);
      expect(_isOpen(tester, 'Support'), isTrue);

      await tester.tap(_trigger('Shipping'));
      await tester.pumpAndSettle();
      expect(values, {'support'});
    });

    // The web original ignores its own state as soon as `onValueChange` is
    // passed, so an accordion that only listens for changes never opens
    // (research 01 §7). coil keeps no state of its own: it reports every
    // change and shows exactly the value it is given.
    testWidgets('regression: onChanged never freezes the open item', (
      tester,
    ) async {
      final changes = <String?>[];
      await tester.pumpWidget(_app(_Single(onChanged: changes.add)));
      for (var i = 0; i < 3; i++) {
        await tester.tap(_trigger('Returns'));
        await tester.pumpAndSettle();
        expect(_isOpen(tester, 'Returns'), isTrue, reason: 'round $i opens');
        await tester.tap(_trigger('Returns'));
        await tester.pumpAndSettle();
        expect(_isOpen(tester, 'Returns'), isFalse, reason: 'round $i closes');
      }
      expect(changes, ['returns', null, 'returns', null, 'returns', null]);

      // A parent that ignores the change keeps what it passes.
      final ignored = <String?>[];
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(
          CoilAccordion<String>.single(
            items: _items(),
            value: 'shipping',
            onChanged: ignored.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_trigger('Returns'));
      await tester.pumpAndSettle();
      expect(ignored, ['returns']);
      expect(_isOpen(tester, 'Shipping'), isTrue);
      expect(_isOpen(tester, 'Returns'), isFalse);
    });

    testWidgets('a reorder keeps an open item open, without replaying it', (
      tester,
    ) async {
      var items = _items();
      late StateSetter setItems;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setItems = setState;
              return CoilAccordion<String>.single(
                items: items,
                value: 'shipping',
                onChanged: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.ancestor(
        of: find.text(_panelText),
        matching: find.byType(CoilCollapsible),
      );
      final open = tester.getSize(panel).height;

      setItems(() => items = items.reversed.toList());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(_isOpen(tester, 'Shipping'), isTrue);
      expect(tester.getSize(panel).height, open);
      expect(
        tester.getTopLeft(_trigger('Shipping')).dy,
        greaterThan(tester.getTopLeft(_trigger('Support')).dy),
        reason: 'the item moved',
      );
    });

    testWidgets('a null onChanged disables every trigger', (tester) async {
      await tester.pumpWidget(
        _app(
          CoilAccordion<String>.single(
            items: _items(),
            value: null,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(_trigger('Returns'));
      await tester.pumpAndSettle();
      expect(_isOpen(tester, 'Returns'), isFalse);
      expect(
        tester
            .getSemantics(_trigger('Returns'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
    });
  });

  group('keyboard', () {
    testWidgets('every trigger is a tab stop', (tester) async {
      await tester.pumpWidget(_app(const _Single()));
      final reached = <String?>[];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached.add(_focusedLabel);
      }
      expect(reached, ['Shipping', 'Returns', 'Support', 'After']);
    });

    testWidgets('Up and Down move and wrap, Home and End jump, '
        'disabled triggers are skipped', (tester) async {
      await tester.pumpWidget(_app(const _Single(disableLast: true)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedLabel, 'Shipping');

      Future<String?> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
        return _focusedLabel;
      }

      expect(await press(LogicalKeyboardKey.arrowDown), 'Returns');
      expect(await press(LogicalKeyboardKey.arrowDown), 'Shipping');
      expect(await press(LogicalKeyboardKey.arrowUp), 'Returns');
      expect(await press(LogicalKeyboardKey.home), 'Shipping');
      expect(await press(LogicalKeyboardKey.end), 'Returns');
    });

    testWidgets('Enter and Space toggle the focused item', (tester) async {
      await tester.pumpWidget(_app(const _Single()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_isOpen(tester, 'Shipping'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_isOpen(tester, 'Shipping'), isFalse);
    });
  });

  testWidgets('semantics: an expandable button that names its panel', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Single(initial: 'shipping')));
    final trigger = tester.getSemantics(_trigger('Shipping'));
    final data = trigger.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isExpanded, Tristate.isTrue);
    expect(data.label, contains('Shipping'));

    final panel = find.semantics.byPredicate(
      (n) =>
          n.getSemanticsData().role == SemanticsRole.region &&
          n.getSemanticsData().label == 'Shipping',
    );
    expect(
      panel,
      findsOne,
      reason: 'the open panel is labelled by its trigger',
    );
    final panelId = panel.evaluate().single.getSemanticsData().identifier;
    expect(data.controlsNodes, {panelId});

    expect(
      find.semantics.byPredicate(
        (n) => n.getSemanticsData().role == SemanticsRole.region,
      ),
      findsOne,
      reason: 'closed panels are hidden from screen readers',
    );
    handle.dispose();
  });

  group('touch and mouse', () {
    testWidgets('touch shows a press fill and leaves nothing lit', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Single(), tier: CoilTier.touch));
      final gesture = await tester.startGesture(
        tester.getCenter(_trigger('Returns')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(_states(tester, 'Returns'), {WidgetState.pressed});
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_states(tester, 'Returns'), isEmpty);
      expect(_isOpen(tester, 'Returns'), isTrue);
    });

    testWidgets('a mouse hovers, and a click shows no focus ring', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Single()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(_trigger('Returns')));
      await tester.pump();
      expect(_states(tester, 'Returns'), {WidgetState.hovered});
      await mouse.down(tester.getCenter(_trigger('Returns')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(_states(tester, 'Returns'), isNot(contains(WidgetState.focused)));
    });
  });

  group('motion', () {
    double panelHeight(WidgetTester tester) =>
        tester.getSize(find.byType(CoilCollapsible).first).height;

    testWidgets('the panel springs open', (tester) async {
      await tester.pumpWidget(_app(const _Single()));
      await tester.tap(_trigger('Shipping'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final midway = panelHeight(tester);
      await tester.pumpAndSettle();
      expect(midway, inExclusiveRange(0, panelHeight(tester)));
    });

    testWidgets('reduced motion snaps the panel open', (tester) async {
      await tester.pumpWidget(_app(const _Single(), reduceMotion: true));
      await tester.tap(_trigger('Shipping'));
      await tester.pump();
      await tester.pump();
      final open = panelHeight(tester);
      await tester.pumpAndSettle();
      expect(open, greaterThan(0));
      expect(panelHeight(tester), open);
    });

    testWidgets('a motion override applies to the next animation', (
      tester,
    ) async {
      const slow = CoilMotion(
        standard: CupertinoMotion(duration: Duration(seconds: 2)),
      );
      await tester.pumpWidget(_app(const _Single(motion: slow)));
      await tester.tap(_trigger('Shipping'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final slowHeight = panelHeight(tester);
      await tester.pumpAndSettle();
      final full = panelHeight(tester);
      expect(slowHeight, lessThan(full * 0.6), reason: 'the 2 s spring');
    });
  });

  testWidgets('style: theme override, then instance style', (tester) async {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);
    Color panelColor() => DefaultTextStyle.of(
      tester.element(find.text(_panelText)),
    ).style.color!;

    final themed = CoilThemeData.light.withComponentStyle(
      const CoilAccordionStyle(panelTextStyle: TextStyle(color: red)),
    );
    await tester.pumpWidget(
      _app(const _Single(initial: 'shipping'), theme: themed),
    );
    expect(panelColor(), red);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(
        CoilAccordion<String>.single(
          items: _items(),
          value: 'shipping',
          onChanged: (_) {},
          style: const CoilAccordionStyle(
            panelTextStyle: TextStyle(color: blue),
          ),
        ),
        theme: themed,
      ),
    );
    expect(panelColor(), blue);
  });
}

/// One accordion per state, side by side: rest, hover (mouse), focus
/// (keyboard), pressed (a held touch) and disabled. "Shipping" is open in
/// each; the state is on "Returns".
