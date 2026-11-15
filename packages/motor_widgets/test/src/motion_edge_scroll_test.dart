import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_widgets/motor_widgets.dart';

import '../util.dart';

const _item = Size(100, 40);

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]),
  ),
);

Widget _box([Size size = _item]) => SizedBox.fromSize(
  size: size,
  child: const ColoredBox(color: Color(0xFF888888)),
);

/// A card at the top left, which drags.
const _card = MotionDraggable<String>(data: 'card', child: _Card());

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => _box();
}

/// The card at the top left, and a 200 x 400 list at x 200 of [count]
/// items, each inside an edge scroll.
Widget _list(
  ScrollController controller, {
  int count = 40,
  MotionEdgeScrollSettings settings = const MotionEdgeScrollSettings(),
  MotionDragProbe probe = MotionDragProbe.pointer,
}) => _app(
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(
        width: 200,
        child: Align(alignment: .topLeft, child: _card),
      ),
      SizedBox(
        width: 200,
        height: 400,
        child: ListView.builder(
          controller: controller,
          itemCount: count,
          itemBuilder: (context, i) => MotionEdgeScroll(
            settings: settings,
            probe: probe,
            child: _box(),
          ),
        ),
      ),
    ],
  ),
);

/// Picks up the card and moves it to [to] in a few events.
Future<TestGesture> _dragTo(
  WidgetTester tester,
  Offset to, {
  Offset from = const Offset(50, 20),
}) async {
  final gesture = await tester.startGesture(from);
  for (var i = 1; i <= 4; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 4)!);
    await tester.pump(frame);
  }
  return gesture;
}

/// How far [controller] scrolls over [frames] frames.
Future<double> _scrolled(
  WidgetTester tester,
  ScrollController controller, {
  int frames = 10,
}) async {
  final start = controller.offset;
  for (var i = 0; i < frames; i++) {
    await tester.pump(frame);
  }
  return controller.offset - start;
}

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  testWidgets('scrolls faster the deeper the drag is in the band', (
    tester,
  ) async {
    await tester.pumpWidget(_list(controller));
    // The band is the bottom 64 px of the viewport, from 336 to 400.
    final gesture = await _dragTo(tester, const Offset(300, 352));
    await _scrolled(tester, controller);
    final shallow = await _scrolled(tester, controller);
    await gesture.moveTo(const Offset(300, 392));
    await _scrolled(tester, controller);
    final deep = await _scrolled(tester, controller);
    expect(shallow, greaterThan(0));
    expect(deep, greaterThan(shallow * 4));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('starts from rest when the drag enters the band', (
    tester,
  ) async {
    await tester.pumpWidget(_list(controller));
    final gesture = await _dragTo(tester, const Offset(300, 300));
    expect(controller.offset, 0);
    await gesture.moveTo(const Offset(300, 399));
    final steps = <double>[];
    var last = controller.offset;
    for (var i = 0; i < 12; i++) {
      await tester.pump(frame);
      steps.add(controller.offset - last);
      last = controller.offset;
    }
    // The speed springs up: the first frames move little, and each moves
    // more than the one before until it is near the top speed.
    expect(steps.first, lessThan(steps.last / 4));
    for (var i = 2; i < 6; i++) {
      expect(steps[i], greaterThanOrEqualTo(steps[i - 1]));
    }
    // 1500 px/s at the edge is 24 px a frame.
    expect(steps.last, closeTo(24, 3));
    await gesture.up();
  });

  testWidgets('holding still keeps scrolling, up to the end, and stops', (
    tester,
  ) async {
    await tester.pumpWidget(_list(controller, count: 20));
    final gesture = await _dragTo(tester, const Offset(300, 395));
    final first = await _scrolled(tester, controller);
    final second = await _scrolled(tester, controller);
    expect(first, greaterThan(0));
    expect(second, greaterThan(first));
    // 20 items of 40 in 400: the end is at 400.
    for (var i = 0; i < 60; i++) {
      await tester.pump(frame);
      expect(controller.offset, lessThanOrEqualTo(400));
    }
    expect(controller.offset, 400);
    // Nothing more to do: no frames while the drag rests at the end.
    expect(tester.binding.hasScheduledFrame, isFalse);
    // Back toward the top edge, it scrolls back.
    await gesture.moveTo(const Offset(300, 2));
    expect(await _scrolled(tester, controller), lessThan(0));
    await gesture.up();
  });

  testWidgets('stops when the drag ends', (tester) async {
    await tester.pumpWidget(_list(controller));
    final gesture = await _dragTo(tester, const Offset(300, 395));
    await _scrolled(tester, controller);
    await gesture.up();
    await tester.pump(frame);
    final offset = controller.offset;
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
  });

  testWidgets('a drag beside the viewport does not scroll it', (tester) async {
    await tester.pumpWidget(_list(controller));
    final gesture = await _dragTo(tester, const Offset(100, 395));
    expect(await _scrolled(tester, controller), 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a drag far past the end keeps scrolling at full speed', (
    tester,
  ) async {
    await tester.pumpWidget(_list(controller));
    // The list ends at y 400; the drag is 150 below it.
    final gesture = await _dragTo(tester, const Offset(300, 550));
    await _scrolled(tester, controller);
    final far = await _scrolled(tester, controller);
    expect(far, greaterThan(0));
    // As fast as right at the edge.
    await gesture.moveTo(const Offset(300, 400));
    await _scrolled(tester, controller);
    expect(
      await _scrolled(tester, controller),
      // The speed's spring has nearly settled.
      moreOrLessEquals(far, epsilon: far * 0.02),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a scrolling list keeps scrolling while the drag leaves it '
      'sideways past its edge', (tester) async {
    await tester.pumpWidget(_list(controller));
    final gesture = await _dragTo(tester, const Offset(300, 395));
    expect(await _scrolled(tester, controller), greaterThan(0));
    // Below the list and beside it.
    await gesture.moveTo(const Offset(100, 550));
    expect(await _scrolled(tester, controller), greaterThan(0));
    // Back beside it, within its length: it springs to a stop.
    await gesture.moveTo(const Offset(100, 200));
    await _scrolled(tester, controller, frames: 30);
    expect(await _scrolled(tester, controller), lessThan(0.5));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a drag past the end beside a resting list does not start it', (
    tester,
  ) async {
    await tester.pumpWidget(_list(controller));
    final gesture = await _dragTo(tester, const Offset(100, 550));
    expect(await _scrolled(tester, controller), 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('with outside off, a drag that leaves the viewport stops '
      'scrolling it', (tester) async {
    await tester.pumpWidget(
      _list(
        controller,
        settings: const MotionEdgeScrollSettings(outside: false),
      ),
    );
    final gesture = await _dragTo(tester, const Offset(300, 395));
    expect(await _scrolled(tester, controller), greaterThan(0));
    // Far below the list: it springs to a stop.
    await gesture.moveTo(const Offset(300, 550));
    await _scrolled(tester, controller, frames: 30);
    expect(await _scrolled(tester, controller), lessThan(0.5));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('probe', () {
    // The card is grabbed 15 px from its top, so its center is 5 px below
    // the pointer.
    for (final (probe, scrolls) in [
      (MotionDragProbe.pointer, false),
      (MotionDragProbe.feedbackCenter, true),
    ]) {
      testWidgets('$probe', (tester) async {
        await tester.pumpWidget(
          _list(
            controller,
            probe: probe,
            settings: const MotionEdgeScrollSettings(extent: 20),
          ),
        );
        // The pointer at 378 is outside the band (380 to 400); the card's
        // center, at 383, is inside.
        final gesture = await _dragTo(
          tester,
          const Offset(300, 378),
          from: const Offset(50, 15),
        );
        final scrolled = await _scrolled(tester, controller);
        expect(scrolled > 0, scrolls);
        await gesture.up();
        await tester.pumpAndSettle();
      });
    }
  });

  testWidgets('a long list scrolls by its viewport, not its content', (
    tester,
  ) async {
    // The edge scroll wraps the whole content, 1600 px tall.
    await tester.pumpWidget(
      _app(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 200,
              child: Align(alignment: .topLeft, child: _card),
            ),
            SizedBox(
              width: 200,
              height: 400,
              child: SingleChildScrollView(
                controller: controller,
                child: MotionEdgeScroll(
                  child: Column(
                    children: [for (var i = 0; i < 40; i++) _box()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final gesture = await _dragTo(tester, const Offset(300, 395));
    expect(await _scrolled(tester, controller), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a short list scrolls the page around it, also over its empty space',
    (tester) async {
      final inner = ScrollController();
      addTearDown(inner.dispose);
      await tester.pumpWidget(
        _app(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 200,
                child: Align(alignment: .topLeft, child: _card),
              ),
              SizedBox(
                width: 200,
                height: 400,
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      // Two items in a 400 px viewport: it can't scroll.
                      SizedBox(
                        height: 400,
                        child: ListView(
                          controller: inner,
                          children: [
                            for (var i = 0; i < 2; i++)
                              MotionEdgeScroll(child: _box()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 800),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      // Over the short list's empty space, at the page's bottom edge.
      final gesture = await _dragTo(tester, const Offset(300, 395));
      expect(await _scrolled(tester, controller), greaterThan(0));
      expect(inner.offset, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a board: lanes scroll near their ends, the board near its '
      'sides', (tester) async {
    final lanes = [ScrollController(), ScrollController()];
    for (final lane in lanes) {
      addTearDown(lane.dispose);
    }
    // A 400 px wide board of two 300 px lanes, from x 200.
    await tester.pumpWidget(
      _app(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 200,
              child: Align(alignment: .topLeft, child: _card),
            ),
            SizedBox(
              width: 400,
              height: 400,
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final lane in lanes)
                      SizedBox(
                        width: 300,
                        height: 400,
                        child: ListView.builder(
                          controller: lane,
                          itemCount: 40,
                          itemBuilder: (context, i) =>
                              MotionEdgeScroll(child: _box()),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // Near the first lane's bottom, away from the board's sides.
    final gesture = await _dragTo(tester, const Offset(350, 395));
    await _scrolled(tester, controller);
    expect(lanes[0].offset, greaterThan(0));
    expect(lanes[1].offset, 0);
    expect(controller.offset, 0);
    // Near the board's right edge, in the middle of the second lane.
    await gesture.moveTo(const Offset(595, 200));
    final board = await _scrolled(tester, controller);
    expect(board, greaterThan(0));
    expect(lanes[1].offset, 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a nested DragTarget still receives the drop', (tester) async {
    String? accepted;
    await tester.pumpWidget(
      _app(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 200,
              child: Align(alignment: .topLeft, child: _card),
            ),
            SizedBox(
              width: 200,
              height: 400,
              child: ListView(
                controller: controller,
                children: [
                  MotionEdgeScroll(
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) => accepted = details.data,
                      builder: (context, _, _) => _box(const Size(200, 200)),
                    ),
                  ),
                  for (var i = 0; i < 20; i++) _box(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final gesture = await _dragTo(tester, const Offset(300, 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(accepted, 'card');
  });
}
