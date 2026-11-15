import 'package:coil/coil.dart';
import 'package:coil_cli/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_matrix.dart';
import 'src/golden_sheet.dart';
import 'src/test_icons.dart';

Widget _app(
  Widget child, {
  CoilTier tier = CoilTier.pointer,
  CoilThemeData theme = CoilThemeData.light,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: WidgetsApp(
    // A fresh app per pump: the route would keep the first child.
    key: UniqueKey(),
    color: const Color(0xFF000000),
    builder: (context, navigator) => Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: theme.copyWith(tier: tier),
        child: navigator!,
      ),
    ),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: 280, child: child),
        ),
      ),
    ),
  ),
);

CoilCard _card({
  String title = 'Deploy preview',
  VoidCallback? onPressed,
  VoidCallback? onDismissed,
  List<Widget> actions = const [],
  CoilMotion? motion,
  Map<CoilCardTrack<Object>, Motion>? motions,
  CoilCardStyle? style,
  CoilCardVariant variant = CoilCardVariant.stacked,
  Widget? icon,
}) => CoilCard(
  title: Text(title),
  description: const Text('Built 2 minutes ago'),
  icon: icon,
  actions: actions,
  variant: variant,
  onPressed: onPressed,
  onDismissed: onDismissed,
  motion: motion,
  motions: motions,
  style: style,
);

/// The interaction states of the card at [finder].
Set<WidgetState> _states(WidgetTester tester, Finder finder) => tester
    .widget<CoilInteractionDetector>(
      find
          .descendant(
            of: finder,
            matching: find.byType(CoilInteractionDetector),
          )
          .first,
    )
    .states
    .value;

double _dismissOpacity(WidgetTester tester) {
  final button = find.bySemanticsLabel('Dismiss');
  final opacity = tester.widgetList<Opacity>(
    find.ancestor(of: button, matching: find.byType(Opacity)),
  );
  return opacity.fold(1, (o, w) => o * w.opacity);
}

void main() {
  matrixGoldenTest(
    'card',
    (context) => SizedBox(
      width: 520,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Expanded(
            child: CoilCard(
              icon: const TestIcon(TestGlyph.settings),
              title: const Text('Deploy preview'),
              description: const Text('Built 2 minutes ago'),
              actions: [
                CoilButton(
                  onPressed: () {},
                  variant: CoilButtonVariant.ghost,
                  child: const Text('Open'),
                ),
              ],
              onPressed: () {},
              onDismissed: () {},
              child: const Text('main · 3 files'),
            ),
          ),
          Expanded(
            child: CoilCardGroup(
              children: [
                CoilCard(
                  variant: CoilCardVariant.inline,
                  icon: const TestIcon(TestGlyph.home),
                  title: const Text('Home'),
                  description: const Text('Your workspace'),
                  onPressed: () {},
                ),
                CoilCard(
                  variant: CoilCardVariant.inline,
                  icon: const TestIcon(TestGlyph.heart),
                  title: const Text('Saved'),
                  description: const Text('12 items'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    surface: const Size(3400, 2200),
  );

  testWidgets('card states sheet', (tester) async {
    Widget grid() => SizedBox(
      width: 420,
      child: CoilCardGroup(
        layout: CoilCardGroupLayout.separated,
        columns: 2,
        children: [
          for (final (i, name) in ['Alpha', 'Beta', 'Gamma', 'Delta'].indexed)
            CoilCard(
              key: ValueKey(name),
              title: Text(name),
              description: Text('Card ${i + 1}'),
              onPressed: () {},
            ),
        ],
      ),
    );
    Widget divided() => SizedBox(
      width: 260,
      child: CoilCardGroup(
        children: [
          for (final name in ['One', 'Two', 'Three'])
            CoilCard(
              key: ValueKey(name),
              title: Text(name),
              description: const Text('Divided group'),
              onPressed: () {},
            ),
        ],
      ),
    );
    final sheet = await pumpSheet(
      tester,
      ThemedPair(
        title: 'card: separated grid, divided group',
        direction: Axis.vertical,
        builder: (context) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 24,
          children: [grid(), divided()],
        ),
      ),
      surface: const Size(760, 760),
    );
    // The mouse rests on Beta in the light panel; dark stays at rest.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('Beta')).first),
    );
    await settle(tester);
    await expectSheetGolden(tester, sheet, 'goldens/card.png');
  });

  testWidgets('a card with an action is one tab stop (LTR and RTL)', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          direction: direction,
          _card(
            onPressed: () => pressed++,
            actions: [
              CoilButton(
                onPressed: () {},
                variant: CoilButtonVariant.ghost,
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      );
      await expectCoilPattern(
        tester,
        find.byType(CoilCard),
        CoilPattern.card,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      pressed = 0;
      await tester.pump();
      await tester.tap(find.text('Deploy preview'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(pressed, 1, reason: 'a tap anywhere on the card activates it');
    }
  });

  testWidgets('a button inside the card wins over the card', (tester) async {
    var card = 0;
    var open = 0;
    await tester.pumpWidget(
      _app(
        _card(
          onPressed: () => card++,
          actions: [
            CoilButton(
              onPressed: () => open++,
              variant: CoilButtonVariant.ghost,
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 200));
    expect((card, open), (0, 1));
  });

  testWidgets('pointer: the dismiss button shows on hover or focus', (
    tester,
  ) async {
    var dismissed = 0;
    var pressed = 0;
    await tester.pumpWidget(
      _app(_card(onPressed: () => pressed++, onDismissed: () => dismissed++)),
    );
    await tester.pumpAndSettle();
    expect(_dismissOpacity(tester), 0, reason: 'hidden at rest');

    // Hidden, it never takes the card's tap.
    final corner = tester.getCenter(find.bySemanticsLabel('Dismiss'));
    await tester.tapAt(corner);
    await tester.pump(const Duration(milliseconds: 200));
    expect((pressed, dismissed), (1, 0));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byType(CoilCard)));
    await tester.pumpAndSettle();
    expect(_dismissOpacity(tester), 1, reason: 'hovering the card shows it');
    await mouse.moveTo(corner);
    await tester.pumpAndSettle();
    expect(_dismissOpacity(tester), 1, reason: 'it stays while over it');
    await mouse.moveTo(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(_dismissOpacity(tester), 0);

    // Keyboard: Tab to the card, then on to the dismiss button.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_dismissOpacity(tester), 1, reason: 'focus within shows it');
  });

  testWidgets('touch: the dismiss button always shows, with a 44 hit box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tier: CoilTier.touch,
        _card(onPressed: () {}, onDismissed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(_dismissOpacity(tester), 1);
    final button = find.ancestor(
      of: find.bySemanticsLabel('Dismiss'),
      matching: find.byType(CoilButton),
    );
    expect(tester.getSize(button), const Size(44, 44));
  });

  testWidgets('dismissing plays the exit, then calls onDismissed', (
    tester,
  ) async {
    var dismissed = 0;
    var show = true;
    await tester.pumpWidget(
      _app(
        tier: CoilTier.touch,
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (show)
                _card(
                  onDismissed: () => setState(() {
                    dismissed++;
                    show = false;
                  }),
                ),
              const Text('Below'),
            ],
          ),
        ),
      ),
    );
    final before = tester.getTopLeft(find.text('Below')).dy;
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getTopLeft(find.text('Below')).dy;
    expect(dismissed, 0, reason: 'not before the exit has played');
    expect(midway, lessThan(before), reason: 'the height collapses');
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(find.byType(CoilCard), findsNothing);
  });

  testWidgets('reduced motion still dismisses', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      _app(
        tier: CoilTier.touch,
        reducedMotion: true,
        _card(onDismissed: () => dismissed++),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('motion: a slower standard token slows the collapse', (
    tester,
  ) async {
    var dismissed = 0;
    const slow = CoilMotion(
      standard: CupertinoMotion(duration: Duration(milliseconds: 900)),
    );
    await tester.pumpWidget(
      _app(
        tier: CoilTier.touch,
        _card(motion: slow, onDismissed: () => dismissed++),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(dismissed, 0);
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('motions: an instant dismissHeight collapses at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tier: CoilTier.touch,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _card(
              motions: {CoilCardTrack.dismissHeight: const Motion.instant()},
              onDismissed: () {},
            ),
            const Text('Below'),
          ],
        ),
      ),
    );
    final top = tester.getTopLeft(find.byType(CoilCard)).dy;
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(find.text('Below')).dy, top);
  });

  testWidgets('touch presses fill and leave nothing behind', (tester) async {
    await tester.pumpWidget(
      _app(_card(onPressed: () {}, onDismissed: () {})),
    );
    final card = find.byType(CoilCard);
    final touch = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_states(tester, card), contains(WidgetState.pressed));
    await touch.up();
    await tester.pumpAndSettle();
    expect(_states(tester, card), isEmpty);
    expect(
      _dismissOpacity(tester),
      0,
      reason: 'a tap on the pointer tier never reveals the dismiss button',
    );
  });

  testWidgets('style: fallback < theme < instance', (tester) async {
    const themed = Color(0xFF00FF00);
    const instance = Color(0xFFFF0000);
    bool painted(Color color) => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .any((b) => (b.decoration as dynamic).color == color);

    await tester.pumpWidget(_app(_card()));
    expect(painted(CoilThemeData.light.colors.surface(3)), isTrue);

    final theme = CoilThemeData.light.withComponentStyle(
      const CoilCardStyle(surface: themed),
    );
    await tester.pumpWidget(_app(theme: theme, _card()));
    expect(painted(themed), isTrue);

    await tester.pumpWidget(
      _app(
        theme: theme,
        _card(style: const CoilCardStyle(surface: instance)),
      ),
    );
    expect(painted(instance), isTrue);
    expect(painted(themed), isFalse);
  });
}
