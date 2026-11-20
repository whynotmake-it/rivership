// What WidgetState.focused means: the control's own node has the primary
// focus, from the keyboard. A focused descendant doesn't ring its container.
import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) =>
      CoilTheme(data: CoilThemeData.light, child: navigator!),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, height: 200, child: child),
    ),
  ),
);

/// The outermost focus ring under [of]: the container's own.
bool _outerRing(WidgetTester tester, Finder of) => tester
    .widget<CoilFocusRing>(
      find.descendant(of: of, matching: find.byType(CoilFocusRing)).first,
    )
    .visible;

void main() {
  setUp(CoilInputModality.debugReset);

  testWidgets('a scroll area rings itself, not when a row inside has focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CoilScrollArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 12; i++)
                CoilButton(
                  onPressed: () {},
                  variant: CoilButtonVariant.ghost,
                  child: Text('Row $i'),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final area = find.byType(CoilScrollArea);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'CoilScrollArea');
    expect(_outerRing(tester, area), isTrue, reason: 'the viewport is focused');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<CoilButton>(),
      isNotNull,
    );
    expect(
      _outerRing(tester, area),
      isFalse,
      reason: 'a row inside has focus, not the viewport',
    );
  });

  testWidgets("a card with an action doesn't ring when its button has "
      'focus', (tester) async {
    await tester.pumpWidget(
      _app(
        CoilCard(
          title: const Text('Deploy preview'),
          onPressed: () {},
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
    final card = find.byType(CoilCard);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_outerRing(tester, card), isTrue, reason: 'the card is focused');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_outerRing(tester, card), isFalse, reason: 'Open is focused');
  });

  testWidgets('a range slider is focused while either thumb is', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            CoilRangeSlider(
              values: const CoilRangeValues(0.2, 0.8),
              onChanged: (_) {},
              statesController: states,
            ),
            CoilButton(onPressed: () {}, child: const Text('After')),
          ],
        ),
      ),
    );
    for (final thumb in ['first', 'second']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(states.value, contains(WidgetState.focused), reason: thumb);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(states.value, isNot(contains(WidgetState.focused)));
  });
}
