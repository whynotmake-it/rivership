import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cards of mixed heights, front first.
const _heights = [60.0, 110.0, 40.0, 80.0];
const _gap = 10.0;
const _peek = CoilCardStack.defaultPeek;

Widget _app(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  CoilTier tier = CoilTier.pointer,
  double textScale = 1,
}) => WidgetsApp(
  key: UniqueKey(),
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: CoilThemeData.light.copyWith(tier: tier),
        // Something to tap outside the pile.
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(width: 300, height: 600, child: child),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// A plain card of [height] that records taps.
Widget _card(int index, double height, List<int> taps) => GestureDetector(
  key: ValueKey('card $index'),
  behavior: HitTestBehavior.opaque,
  onTap: () => taps.add(index),
  child: SizedBox(height: height, child: Text('card $index')),
);

Finder _cardFinder(int index) => find.byKey(ValueKey('card $index'));

/// A card's rect as painted, its scale included.
Rect _rect(WidgetTester tester, int index) =>
    tester.getRect(_cardFinder(index));

Widget _stack({
  required List<int> taps,
  required CoilCardStackController controller,
  List<double> heights = _heights,
  CoilCardStackAnchor anchor = CoilCardStackAnchor.bottom,
  Widget? leading,
  Widget? trailing,
  double sideWidth = 0,
  Set<int> leaving = const {},
}) => Align(
  alignment: anchor == CoilCardStackAnchor.bottom
      ? Alignment.bottomCenter
      : Alignment.topCenter,
  child: CoilCardStack(
    controller: controller,
    anchor: anchor,
    gap: _gap,
    leading: leading,
    trailing: trailing,
    sideWidth: sideWidth,
    items: [
      for (final (i, h) in heights.indexed)
        CoilCardStackItem(
          key: ValueKey(i),
          leaving: leaving.contains(i),
          child: _card(i, h, taps),
        ),
    ],
  ),
);

void main() {
  late CoilCardStackController controller;
  late List<int> taps;

  setUp(() {
    controller = CoilCardStackController();
    taps = [];
  });
  tearDown(() => controller.dispose());

  for (final anchor in CoilCardStackAnchor.values) {
    final bottom = anchor == CoilCardStackAnchor.bottom;

    /// The far edge (the one that peeks) and near edge of a card, as
    /// distances that grow away from the anchor.
    double far(WidgetTester tester, int i) =>
        bottom ? -_rect(tester, i).top : _rect(tester, i).bottom;
    double near(WidgetTester tester, int i) =>
        bottom ? -_rect(tester, i).bottom : _rect(tester, i).top;

    group('${anchor.name} anchor', () {
      testWidgets('fanned out, mixed heights are spaced by one gap', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(_stack(taps: taps, controller: controller, anchor: anchor)),
        );
        controller.pinned = true;
        await tester.pumpAndSettle();
        for (var i = 0; i < _heights.length; i++) {
          expect(_rect(tester, i).height, _heights[i], reason: 'whole');
        }
        for (var i = 1; i < _heights.length; i++) {
          expect(
            near(tester, i) - far(tester, i - 1),
            closeTo(_gap, 0.01),
            reason: 'gap between card ${i - 1} and $i',
          );
        }
        // The front card sits at the anchor edge of the stack.
        final stack = tester.getRect(find.byType(CoilCardStack));
        expect(
          bottom ? _rect(tester, 0).bottom : _rect(tester, 0).top,
          bottom ? stack.bottom : stack.top,
        );
        // The stack is exactly as tall as the cards and gaps.
        expect(
          stack.height,
          _heights.reduce((a, b) => a + b) + 3 * _gap,
        );
      });

      testWidgets('folded, the peeks are even whatever the heights', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(_stack(taps: taps, controller: controller, anchor: anchor)),
        );
        await tester.pumpAndSettle();
        expect(_rect(tester, 0).height, _heights[0], reason: 'front whole');
        expect(far(tester, 1) - far(tester, 0), closeTo(_peek, 0.01));
        expect(far(tester, 2) - far(tester, 1), closeTo(_peek, 0.01));
        // Each card behind is a step smaller.
        expect(
          _rect(tester, 1).width / _rect(tester, 0).width,
          closeTo(1 - CoilCardStack.defaultPeekScale, 0.001),
        );
        // The pile: the front card and two peeks.
        expect(
          tester.getSize(find.byType(CoilCardStack)).height,
          _heights[0] + 2 * _peek,
        );
      });

      testWidgets('fanned out, a tap lands on the card painted there', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(_stack(taps: taps, controller: controller, anchor: anchor)),
        );
        controller.pinned = true;
        await tester.pumpAndSettle();
        for (var i = _heights.length - 1; i >= 0; i--) {
          final rect = _rect(tester, i);
          for (final point in [
            rect.topCenter + const Offset(0, 1),
            rect.center,
            rect.bottomCenter - const Offset(0, 1),
          ]) {
            await tester.tapAt(point);
            await tester.pump();
          }
        }
        expect(taps, [3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 0, 0]);
      });

      testWidgets('folded, a tap on a peek fans the pile out and presses '
          'nothing; the front card takes its own taps', (tester) async {
        await tester.pumpWidget(
          _app(
            _stack(
              taps: taps,
              controller: controller,
              anchor: anchor,
              heights: const [60, 60, 60],
            ),
            tier: CoilTier.touch,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(_cardFinder(0));
        await tester.pumpAndSettle();
        expect(taps, [0]);
        expect(controller.pinned, isFalse, reason: 'the card took the tap');

        // The strip of card 1 that peeks past the front card.
        final front = _rect(tester, 0);
        await tester.tapAt(
          bottom
              ? front.topCenter - const Offset(0, _peek / 2)
              : front.bottomCenter + const Offset(0, _peek / 2),
        );
        await tester.pumpAndSettle();
        expect(taps, [0], reason: 'the peeking card took nothing');
        expect(controller.pinned, isTrue);
        expect(controller.expanded, isTrue);

        // A tap outside folds it.
        await tester.tapAt(
          bottom ? const Offset(150, 30) : const Offset(150, 590),
        );
        await tester.pumpAndSettle();
        expect(controller.pinned, isFalse);
      });
    });
  }

  testWidgets('a hovering mouse fans the pile out; leaving folds it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_stack(taps: taps, controller: controller)),
    );
    await tester.pumpAndSettle();
    final folded = tester.getSize(find.byType(CoilCardStack)).height;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_cardFinder(0)));
    await tester.pumpAndSettle();
    expect(controller.expanded, isTrue);
    expect(
      tester.getSize(find.byType(CoilCardStack)).height,
      greaterThan(folded),
    );
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CoilCardStack)).height, folded);
  });

  testWidgets('long wrapped text at 2x stays evenly spaced', (tester) async {
    Widget text(int i, String words) => Text(
      words,
      key: ValueKey('card $i'),
      style: const TextStyle(fontSize: 14),
    );
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.bottomCenter,
          child: CoilCardStack(
            controller: controller,
            gap: _gap,
            items: [
              CoilCardStackItem(key: const ValueKey(0), child: text(0, 'One')),
              CoilCardStackItem(
                key: const ValueKey(1),
                child: text(1, 'A long line that wraps ' * 4),
              ),
              CoilCardStackItem(key: const ValueKey(2), child: text(2, 'Two')),
            ],
          ),
        ),
        textScale: 2,
      ),
    );
    controller.pinned = true;
    await tester.pumpAndSettle();
    expect(
      _rect(tester, 1).height,
      greaterThan(_rect(tester, 0).height * 2),
      reason: 'the middle card wraps',
    );
    expect(_rect(tester, 0).top - _rect(tester, 1).bottom, closeTo(_gap, 0.01));
    expect(_rect(tester, 1).top - _rect(tester, 2).bottom, closeTo(_gap, 0.01));

    controller.pinned = false;
    await tester.pumpAndSettle();
    expect(_rect(tester, 0).top - _rect(tester, 1).top, closeTo(_peek, 0.01));
    expect(_rect(tester, 1).top - _rect(tester, 2).top, closeTo(_peek, 0.01));
  });

  testWidgets('a leaving card closes its gap smoothly, at any heights', (
    tester,
  ) async {
    Widget build(Set<int> leaving) => _app(
      _stack(taps: taps, controller: controller, leaving: leaving),
    );
    await tester.pumpWidget(build({}));
    controller.pinned = true;
    await tester.pumpAndSettle();
    final before = _rect(tester, 2).bottom;

    // Not via _app: a new app would start over.
    await tester.pumpWidget(build({1}));
    var last = _rect(tester, 2).bottom;
    for (var f = 0; f < 40; f++) {
      await tester.pump(const Duration(milliseconds: 16));
      final now = _rect(tester, 2).bottom;
      expect((now - last).abs(), lessThan(30), reason: 'no jump');
      last = now;
    }
    await tester.pumpAndSettle();
    // Card 2 now sits right after the front card.
    expect(_rect(tester, 0).top - _rect(tester, 2).bottom, closeTo(_gap, 0.01));
    expect(_rect(tester, 2).bottom, greaterThan(before));
  });

  testWidgets('RTL: the sides swap, the cards stay between them', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        _app(
          _stack(
            taps: taps,
            controller: controller,
            sideWidth: 40,
            leading: const SizedBox.expand(key: ValueKey('leading')),
            trailing: const SizedBox.expand(key: ValueKey('trailing')),
          ),
          direction: direction,
        ),
      );
      await tester.pumpAndSettle();
      final leading = tester.getRect(find.byKey(const ValueKey('leading')));
      final trailing = tester.getRect(find.byKey(const ValueKey('trailing')));
      final front = _rect(tester, 0);
      final ltr = direction == TextDirection.ltr;
      expect(
        ltr ? leading.right : leading.left,
        ltr ? front.left : front.right,
      );
      expect(
        ltr ? trailing.left : trailing.right,
        ltr ? front.right : front.left,
      );
      expect(leading.height, front.height, reason: 'beside the front card');
      expect(leading.bottom, front.bottom);
    }
  });

  testWidgets('Tab visits the cards front first, and focus fans it out', (
    tester,
  ) async {
    final nodes = [for (var i = 0; i < 3; i++) FocusNode()];
    addTearDown(() {
      for (final n in nodes) {
        n.dispose();
      }
    });
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.bottomCenter,
          child: CoilCardStack(
            controller: controller,
            items: [
              for (var i = 0; i < 3; i++)
                CoilCardStackItem(
                  key: ValueKey(i),
                  child: Focus(
                    focusNode: nodes[i],
                    child: SizedBox(height: 40.0 + 30 * (i % 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Focus lands on the front card, then Tab goes back through the pile.
    nodes[0].requestFocus();
    await tester.pumpAndSettle();
    expect(controller.expanded, isTrue, reason: 'focus inside fans it out');
    final order = [nodes.indexWhere((n) => n.hasPrimaryFocus)];
    for (var t = 0; t < 2; t++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      order.add(nodes.indexWhere((n) => n.hasPrimaryFocus));
      expect(controller.expanded, isTrue);
    }
    expect(order, [0, 1, 2]);
  });

  testWidgets('cards past the peeks stay readable unless it never fans', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final expand in CoilCardStackExpand.values) {
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: CoilCardStack(
              expand: expand,
              items: [
                for (var i = 0; i < 5; i++)
                  CoilCardStackItem(
                    key: ValueKey(i),
                    child: Semantics(
                      container: true,
                      label: 'card $i',
                      child: const SizedBox(height: 40),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('card 4'),
        expand == CoilCardStackExpand.auto ? findsOneWidget : findsNothing,
      );
    }
    semantics.dispose();
  });
}
