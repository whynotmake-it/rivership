import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

/// A drawer with a panel on each side, a horizontal carousel in a vertical
/// list as its page, and another carousel in the start panel.
class _Host extends StatefulWidget {
  const _Host({this.initial});

  final CoilDrawerEdge? initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CoilDrawerEdge? open = widget.initial;

  @override
  Widget build(BuildContext context) => CoilDrawer(
    open: open,
    onOpenChanged: (value) => setState(() => open = value),
    start: Column(
      children: [
        const SizedBox(height: 100),
        SizedBox(
          height: 120,
          child: ListView(
            key: const ValueKey('panel carousel'),
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 4; i++)
                SizedBox(width: 200, child: Text('Card $i')),
            ],
          ),
        ),
      ],
    ),
    end: const Center(child: Text('End panel')),
    child: ListView(
      key: const ValueKey('content'),
      children: [
        const SizedBox(height: 200),
        SizedBox(
          height: 200,
          child: ListView(
            key: const ValueKey('carousel'),
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 6; i++)
                SizedBox(width: 300, child: Text('Slide $i')),
            ],
          ),
        ),
        const SizedBox(height: 1200),
      ],
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  CoilDrawerEdge? initial,
  TextDirection direction = TextDirection.ltr,
}) async {
  useScreen(tester, TestScreen.phone);
  await tester.pumpWidget(
    testApp(
      tier: CoilTier.touch,
      home: Directionality(
        textDirection: direction,
        child: _Host(initial: initial),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CoilDrawerEdge? _open(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host)).open;

/// The page's left edge.
double _page(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('content'))).dx;

/// The scroll position of [key]'s scrollable now. Read it fresh: the
/// scrollable replaces its position when the drawer changes its physics.
ScrollPosition _scroll(WidgetTester tester, String key) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// Moves [gesture] by [dx] (and a little [dy] of diagonal noise) in
/// [steps] frames, checking every frame that [check] holds.
Future<void> _move(
  WidgetTester tester,
  TestGesture gesture,
  double dx, {
  int steps = 1,
  double dy = 0,
  void Function(int step)? check,
}) async {
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, dy));
    await tester.pump(const Duration(milliseconds: 16));
    check?.call(i);
  }
}

/// Moves 10 per frame [frames] times, expecting the page to follow the
/// finger exactly each frame while [scroll] stays where it is.
Future<void> _follows(
  WidgetTester tester,
  TestGesture gesture,
  ScrollPosition Function() scroll, {
  required double dx,
  required int frames,
  double dy = 0,
}) async {
  for (var i = 0; i < frames; i++) {
    final page = _page(tester);
    final pixels = scroll().pixels;
    await _move(tester, gesture, dx, dy: dy);
    expect(_page(tester), page + dx, reason: 'frame $i: the page follows');
    expect(scroll().pixels, pixels, reason: "frame $i: it doesn't scroll");
  }
}

void main() {
  group('a drag that opens the drawer from a carousel', () {
    testWidgets('keeps moving the page back and forth until it is closed, '
        'then scrolls the carousel', (tester) async {
      await _pump(tester);
      ScrollPosition carousel() => _scroll(tester, 'carousel');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('carousel'))),
      );
      // Past the slop, the carousel at its start hands over to the drawer.
      await _move(tester, gesture, 40, steps: 4);
      expect(_page(tester), greaterThan(0));
      expect(carousel().pixels, 0);

      await _follows(tester, gesture, carousel, dx: 10, frames: 8);
      // Back toward closed, then open again, then back: the drawer keeps
      // the drag the whole way, with some vertical noise.
      await _follows(tester, gesture, carousel, dx: -10, frames: 5);
      await _follows(tester, gesture, carousel, dx: 10, frames: 3, dy: 2);
      await _follows(tester, gesture, carousel, dx: -10, frames: 4, dy: -2);
      expect(_open(tester), isNull, reason: 'nothing settles mid-drag');

      // All the way closed: the page stops at its rest and the carousel
      // takes over in the same gesture.
      final left = _page(tester);
      await _move(tester, gesture, -left, steps: (left / 10).ceil());
      expect(_page(tester), 0);
      await _move(tester, gesture, -10, steps: 2);
      expect(_page(tester), 0, reason: 'the end panel stays shut');
      final pixels = carousel().pixels;
      await _move(
        tester,
        gesture,
        -50,
        steps: 5,
        check: (step) => expect(_page(tester), 0),
      );
      expect(carousel().pixels, pixels + 50);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
      expect(_page(tester), 0);
    });

    testWidgets('scrolled to its end, it does the same for the end panel', (
      tester,
    ) async {
      await _pump(tester);
      ScrollPosition carousel() => _scroll(tester, 'carousel');
      carousel().jumpTo(carousel().maxScrollExtent);
      await tester.pump();
      final max = carousel().maxScrollExtent;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('carousel'))),
      );
      await _move(tester, gesture, -40, steps: 4);
      expect(_page(tester), lessThan(0));
      await _follows(tester, gesture, carousel, dx: -10, frames: 6);
      await _follows(tester, gesture, carousel, dx: 10, frames: 4);
      await _follows(tester, gesture, carousel, dx: -10, frames: 2);
      final right = -_page(tester);
      await _move(tester, gesture, right, steps: (right / 10).ceil());
      expect(_page(tester), 0);
      await _move(tester, gesture, 10, steps: 2);
      final pixels = carousel().pixels;
      expect(pixels, lessThanOrEqualTo(max));
      await _move(tester, gesture, 50, steps: 5);
      expect(_page(tester), 0);
      expect(carousel().pixels, pixels - 50, reason: 'it scrolls back');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
    });

    testWidgets('right to left, the start panel opens to the right', (
      tester,
    ) async {
      await _pump(tester, direction: TextDirection.rtl);
      ScrollPosition carousel() => _scroll(tester, 'carousel');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('carousel'))),
      );
      // In RTL the carousel starts at the right, so a drag left opens.
      await _move(tester, gesture, -40, steps: 4);
      expect(_page(tester), lessThan(0));
      expect(carousel().pixels, 0);
      await _follows(tester, gesture, carousel, dx: -10, frames: 6);
      await _follows(tester, gesture, carousel, dx: 10, frames: 4);
      await _follows(tester, gesture, carousel, dx: -10, frames: 2);
      final right = -_page(tester);
      await _move(tester, gesture, right, steps: (right / 10).ceil());
      expect(_page(tester), 0);
      await _move(tester, gesture, 10, steps: 2);
      final pixels = carousel().pixels;
      await _move(tester, gesture, 50, steps: 5);
      expect(_page(tester), 0);
      expect(carousel().pixels, pixels + 50);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_open(tester), isNull);
    });
  });

  group('a drag that closes the drawer from a carousel in its panel', () {
    testWidgets('keeps moving the page until it is open again, then scrolls '
        'the carousel', (tester) async {
      await _pump(tester, initial: CoilDrawerEdge.start);
      expect(_page(tester), 320);
      ScrollPosition carousel() => _scroll(tester, 'panel carousel');
      carousel().jumpTo(carousel().maxScrollExtent);
      await tester.pump();
      final max = carousel().maxScrollExtent;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('panel carousel'))),
      );
      // At its end, the carousel hands a closing drag to the drawer.
      await _move(tester, gesture, -40, steps: 4);
      expect(_page(tester), lessThan(320));
      expect(carousel().pixels, max);
      await _follows(tester, gesture, carousel, dx: -10, frames: 6);
      await _follows(tester, gesture, carousel, dx: 10, frames: 4);
      await _follows(tester, gesture, carousel, dx: -10, frames: 2, dy: 2);
      expect(_open(tester), CoilDrawerEdge.start);

      // Back all the way open: then the carousel scrolls again.
      final left = 320 - _page(tester);
      await _move(tester, gesture, left, steps: (left / 10).ceil());
      expect(_page(tester), 320);
      await _move(tester, gesture, 10, steps: 2);
      final pixels = carousel().pixels;
      await _move(tester, gesture, 50, steps: 5);
      expect(_page(tester), 320);
      expect(carousel().pixels, pixels - 50);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_open(tester), CoilDrawerEdge.start);
    });
  });
}
