import 'dart:async';

import 'package:fixed_ticker/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';
import 'package:motor_widgets/src/painted_position.dart';

import '../util.dart';

const _feedback = Key('feedback');
const _itemSize = Size(80, 40);

/// Where the item sits in column B, below the column's top padding.
const _inB = Offset(400, 200);

/// Item [id]'s child, also while a list keeps it built out of view.
Finder _child(String id) =>
    find.byKey(ValueKey('child-$id'), skipOffstage: false);

/// Whether the child of item [id] is shown, rather than kept hidden.
bool _isShown(WidgetTester tester, String id) => tester
    .widget<Visibility>(
      find.ancestor(of: _child(id), matching: find.byType(Visibility)).first,
    )
    .visible;

Rect _feedbackRect(WidgetTester tester) =>
    tester.getRect(find.byKey(_feedback));

/// Where item [id] is painted: as the feedback while that flies in the
/// overlay, else as the child, including a MotionReorder's paint offset.
Rect _paintedRect(WidgetTester tester, String id) {
  final feedback = find.byKey(_feedback);
  if (feedback.evaluate().isNotEmpty) return tester.getRect(feedback);
  return paintedGlobalRect(tester.renderObject<RenderBox>(_child(id)));
}

bool _inOverlay() => find.byKey(_feedback).evaluate().isNotEmpty;

/// Two columns: A at x 0, B at x 400. B is a plain [DragTarget] that moves
/// what is dropped on it into B, or removes it when [consume] is set.
class _Board extends StatefulWidget {
  const _Board({
    this.items = const ['x'],
    this.consume = false,
    this.transitions,
    this.feedbackBuilder,
    this.onLanded,
    this.onDragStarted,
    this.axis,
    this.longPress = false,
    this.tagOf,
    this.bItems = const [],
    this.reorderB = false,
    super.key,
  });

  final List<String> items;
  final bool consume;
  final MotionDraggableTransitions? transitions;
  final MotionDraggableFeedbackBuilder? feedbackBuilder;
  final VoidCallback? onLanded;
  final VoidCallback? onDragStarted;
  final Axis? axis;
  final bool longPress;
  final Object Function(String id)? tagOf;
  final List<String> bItems;

  /// Wraps column B's items in [MotionReorder]s keyed by index.
  final bool reorderB;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  late final a = [...widget.items];
  late final b = [...widget.bItems];
  int accepted = 0;
  double bTop = 200;

  void moveB(double top) => setState(() => bTop = top);

  void reverseB() => setState(() => b.setAll(0, b.reversed.toList()));

  void removeFromA(String id) => setState(() => a.remove(id));

  Widget _item(String id) {
    final child = SizedBox.fromSize(
      key: ValueKey('child-$id'),
      size: _itemSize,
      child: const ColoredBox(color: Color(0xFF888888)),
    );
    const feedback = ColoredBox(key: _feedback, color: Color(0xFF000000));
    return widget.longPress
        ? MotionLongPressDraggable<String>(
            key: ValueKey(id),
            data: id,
            feedback: feedback,
            onDragStarted: widget.onDragStarted,
            onLanded: widget.onLanded,
            child: child,
          )
        : MotionDraggable<String>(
            key: ValueKey(id),
            data: id,
            tag: widget.tagOf?.call(id),
            axis: widget.axis,
            feedback: feedback,
            transitions: widget.transitions,
            feedbackBuilder: widget.feedbackBuilder,
            onDragStarted: widget.onDragStarted,
            onLanded: widget.onLanded,
            onDragCompleted: () => accepted++,
            child: child,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final id in a) _item(id)],
          ),
        ),
        const SizedBox(width: 200),
        SizedBox(
          width: 200,
          height: 600,
          child: DragTarget<String>(
            onAcceptWithDetails: (details) => setState(() {
              a.remove(details.data);
              if (!widget.consume) b.add(details.data);
            }),
            builder: (context, candidates, rejected) => Padding(
              padding: EdgeInsets.only(top: bTop),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, id) in b.indexed)
                    if (widget.reorderB)
                      MotionReorder(
                        key: ValueKey('reorder-$id'),
                        flightKey: index,
                        child: _item(id),
                      )
                    else
                      _item(id),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _header = Key('header');

/// Column A at x 0 and a scrolling column B at x 400, both in
/// [MotionReorder]s keyed by index. B's list is the viewport from y 200 to
/// 320, with a header stacked over its top 20 px. Dropping on B appends.
class _ScrollBoard extends StatefulWidget {
  const _ScrollBoard({
    this.b = const ['y'],
    this.insertFirst = false,
    this.boardWidth,
    this.transitions,
    this.handoff = MotionDragHandoff.onEnter,
    this.handoffFade = const Motion.instant(),
    super.key,
  });

  /// The fade of the overlay copy after a hand-off. Instant by default, so
  /// the hand-off tests see the flight leave the overlay at once.
  final Motion handoffFade;

  /// The cards' transitions.
  final MotionDraggableTransitions? transitions;

  /// The cards' hand-off.
  final MotionDragHandoff handoff;

  /// Column B's items.
  final List<String> b;

  /// Whether a drop on B inserts at the top instead of appending.
  final bool insertFirst;

  /// The width of a horizontally scrolling viewport around the board, or
  /// null for none.
  final double? boardWidth;

  @override
  State<_ScrollBoard> createState() => _ScrollBoardState();
}

class _ScrollBoardState extends State<_ScrollBoard> {
  final a = ['x'];
  late final b = [...widget.b];
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Widget _card(String id, int index) => MotionReorder(
    key: ValueKey('reorder-$id'),
    flightKey: index,
    child: MotionDraggable<String>(
      key: ValueKey(id),
      data: id,
      transitions: widget.transitions,
      handoff: widget.handoff,
      motions: {MotionDraggableTrack.handoffFade: widget.handoffFade},
      feedback: const ColoredBox(key: _feedback, color: Color(0xFF000000)),
      child: SizedBox.fromSize(
        key: ValueKey('child-$id'),
        size: _itemSize,
        child: const ColoredBox(color: Color(0xFF888888)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final board = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final (i, id) in a.indexed) _card(id, i)],
          ),
        ),
        const SizedBox(width: 200),
        SizedBox(
          width: 200,
          height: 600,
          child: DragTarget<String>(
            onAcceptWithDetails: (details) => setState(() {
              a.remove(details.data);
              widget.insertFirst
                  ? b.insert(0, details.data)
                  : b.add(details.data);
            }),
            builder: (context, candidates, rejected) => Padding(
              padding: const EdgeInsets.only(top: 200),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 120,
                  child: Stack(
                    children: [
                      ListView(
                        controller: scroll,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final (i, id) in b.indexed)
                            Align(
                              key: ValueKey('slot-$id'),
                              alignment: Alignment.topLeft,
                              child: _card(id, i),
                            ),
                        ],
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 20,
                        child: ColoredBox(
                          key: _header,
                          color: Color(0xFFFF0000),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final width = widget.boardWidth;
    if (width == null) return board;
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: 600,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 600, child: board),
        ),
      ),
    );
  }
}

/// The first render box that a pointer at [position] hits.
RenderObject? _topHit(WidgetTester tester, Offset position) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, position, tester.view.viewId);
  return result.path.firstOrNull?.target as RenderObject?;
}

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]),
);

/// Drags from the center of the item in column A by [by], in steps.
Future<TestGesture> _drag(WidgetTester tester, Offset by) async {
  final gesture = await tester.startGesture(const Offset(40, 20));
  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(by / steps.toDouble());
    await tester.pump(frame);
  }
  return gesture;
}

void main() {
  group('MotionDraggable', () {
    testWidgets('works with a plain DragTarget and lays the feedback out at '
        "the child's size", (tester) async {
      var started = 0;
      final board = GlobalKey<_BoardState>();
      await tester.pumpWidget(
        _app(_Board(key: board, onDragStarted: () => started++)),
      );

      final gesture = await _drag(tester, const Offset(400, 280));
      expect(started, 1);
      expect(_feedbackRect(tester).size, _itemSize);
      expect(_isShown(tester, 'x'), isFalse, reason: 'childWhenDragging');

      await gesture.up();
      expect(board.currentState!.accepted, 1);
      expect(board.currentState!.b, ['x']);
      await tester.pumpAndSettle();
    });

    testWidgets('an accepted drop flies to where the item now lives', (
      tester,
    ) async {
      var landed = 0;
      await tester.pumpWidget(_app(_Board(onLanded: () => landed++)));

      final gesture = await _drag(tester, const Offset(400, 280));
      await gesture.up();
      final drop = _feedbackRect(tester).topLeft;
      expect(drop, const Offset(400, 280));

      // The drop rebuilds the item in column B, hidden while the feedback
      // flies to it.
      await tester.pump();
      expect(tester.getTopLeft(_child('x')), _inB);
      expect(_isShown(tester, 'x'), isFalse);

      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 150));
      final midway = _feedbackRect(tester).topLeft;
      expect(midway.dy, lessThan(drop.dy));
      expect(midway.dy, greaterThan(_inB.dy));

      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
      expect(_isShown(tester, 'x'), isTrue);
      expect(landed, 1);
    });

    testWidgets('follows a destination that moves while it lands', (
      tester,
    ) async {
      final board = GlobalKey<_BoardState>();
      await tester.pumpWidget(_app(_Board(key: board)));

      final gesture = await _drag(tester, const Offset(400, 280));
      await gesture.up();
      await tester.pump();
      await tester.pump(frame);
      final before = _feedbackRect(tester).top;

      // The destination jumps 100 px down mid-flight; the flight moves with
      // it instead of finishing its old path.
      board.currentState!.moveB(300);
      await tester.pump();
      await tester.pump(frame);
      expect(_feedbackRect(tester).top, greaterThan(before + 50));

      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
      expect(tester.getTopLeft(_child('x')), const Offset(400, 300));
    });

    testWidgets('follows where a reordering destination is painted', (
      tester,
    ) async {
      final board = GlobalKey<_BoardState>();
      await tester.pumpWidget(
        _app(_Board(key: board, bItems: const ['y'], reorderB: true)),
      );

      // x lands below y, at 240.
      final gesture = await _drag(tester, const Offset(400, 280));
      await gesture.up();
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(fineFrame);
      }

      // Swap the column while x is still landing: x's layout jumps to the
      // top at once, while MotionReorder paints it flying there.
      board.currentState!.reverseB();
      final tops = <double>[_paintedRect(tester, 'x').top];
      for (var i = 0; i < 400; i++) {
        await tester.pump(fineFrame);
        tops.add(_paintedRect(tester, 'x').top);
      }
      await tester.pumpAndSettle();

      final steps = [
        for (var i = 1; i < tops.length; i++) (tops[i] - tops[i - 1]).abs(),
      ];
      // An item is 40 px tall: following the layout would jump that far in
      // one frame.
      expect(
        steps.reduce((a, b) => a > b ? a : b),
        lessThan(5),
        reason: '$tops',
      );
      expect(tops.last, moreOrLessEquals(_inB.dy, epsilon: 0.5));
      expect(_paintedRect(tester, 'x').topLeft, _inB);
      expect(_isShown(tester, 'x'), isTrue);
    });

    testWidgets('a rejected drop springs back with the release velocity', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));

      // Fling right, and let go on empty space.
      await tester.timedDragFrom(
        const Offset(40, 20),
        const Offset(250, 0),
        const Duration(milliseconds: 200),
      );
      final released = _feedbackRect(tester).left;
      await tester.pump(frame);
      await tester.pump(frame);
      expect(
        _feedbackRect(tester).left,
        greaterThan(released),
        reason: 'carries on to the right before it turns back',
      );
      expect(_isShown(tester, 'x'), isFalse);

      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
      expect(_isShown(tester, 'x'), isTrue);
      expect(tester.getTopLeft(_child('x')), Offset.zero);
    });

    testWidgets('a drop without a destination exits where it was dropped', (
      tester,
    ) async {
      var landed = 0;
      await tester.pumpWidget(
        _app(_Board(consume: true, onLanded: () => landed++)),
      );

      final gesture = await _drag(tester, const Offset(400, 280));
      await gesture.up();
      final drop = _feedbackRect(tester);
      await tester.pump();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 100));

      // It shrinks around the drop point.
      final shrinking = _feedbackRect(tester);
      expect(shrinking.center.dx, moreOrLessEquals(drop.center.dx, epsilon: 1));
      expect(shrinking.center.dy, moreOrLessEquals(drop.center.dy, epsilon: 1));
      expect(shrinking.width, lessThan(drop.width));

      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
      expect(landed, 1);
    });

    testWidgets('transitions animate the feedback per phase', (tester) async {
      final phases = <(MotionDragPhase, bool)>[];
      final scales = <double>[];
      await tester.pumpWidget(
        _app(
          _Board(
            consume: true,
            transitions: (drag) {
              phases.add((drag.phase, drag.destination != null));
              return switch ((drag.phase, drag.destination)) {
                (MotionDragPhase.dragging, _) => [
                  MotionDraggableTrack.scale([const TrackStep.to(1.5)]),
                ],
                (MotionDragPhase.accepted, null) => [
                  MotionDraggableTrack.rotation([const TrackStep.to(0.5)]),
                ],
                _ => const [],
              };
            },
            feedbackBuilder: (context, drag, feedback) {
              scales.add(drag.value(MotionDraggableTrack.scale));
              return feedback;
            },
          ),
        ),
      );

      final gesture = await _drag(tester, const Offset(400, 280));
      await tester.pump(const Duration(seconds: 1));
      expect(scales.last, moreOrLessEquals(1.5, epsilon: 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(phases, [
        (MotionDragPhase.dragging, false),
        (MotionDragPhase.accepted, false),
      ]);
      // Scale isn't mentioned after the drop, so it went back to rest.
      expect(scales.last, moreOrLessEquals(1, epsilon: 0.01));
    });

    testWidgets('the feedback builder gets the smoothed drag velocity', (
      tester,
    ) async {
      final velocities = <Offset>[];
      await tester.pumpWidget(
        _app(
          _Board(
            feedbackBuilder: (context, drag, feedback) {
              velocities.add(drag.velocity);
              return feedback;
            },
          ),
        ),
      );

      final gesture = await _drag(tester, const Offset(300, 0));
      // 30 px per 16 ms frame is about 1900 px/s.
      expect(velocities.last.dx, greaterThan(1000));
      expect(velocities.last.dy.abs(), lessThan(1));

      // A resting pointer reads as still.
      await tester.pump(const Duration(milliseconds: 500));
      expect(velocities.last.distance, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('axis restricts the feedback', (tester) async {
      await tester.pumpWidget(_app(const _Board(axis: Axis.horizontal)));

      final gesture = await _drag(tester, const Offset(100, 100));
      expect(_feedbackRect(tester).topLeft, const Offset(100, 0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('MotionLongPressDraggable starts after the delay', (
      tester,
    ) async {
      var started = 0;
      await tester.pumpWidget(
        _app(_Board(longPress: true, onDragStarted: () => started++)),
      );

      final gesture = await tester.startGesture(const Offset(40, 20));
      await tester.pump(kLongPressTimeout + frame);
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump(frame);
      expect(started, 1);
      expect(_feedbackRect(tester).topLeft, const Offset(50, 0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('grabbing a landing feedback drags it on from where it is', (
      tester,
    ) async {
      var started = 0;
      final board = GlobalKey<_BoardState>();
      await tester.pumpWidget(
        _app(_Board(key: board, onDragStarted: () => started++)),
      );

      // Rejected: it heads back to column A.
      final first = await _drag(tester, const Offset(250, 300));
      await first.up();
      await tester.pump();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 100));
      final caught = _feedbackRect(tester);

      final second = await tester.startGesture(caught.center);
      await second.moveBy(const Offset(30, 0));
      await tester.pump(frame);
      expect(started, 2);
      final grabbed = _feedbackRect(tester).topLeft;
      expect(grabbed.dx, moreOrLessEquals(caught.left + 30, epsilon: 1));
      expect(grabbed.dy, moreOrLessEquals(caught.top, epsilon: 1));

      // Drop it on B, where it lands.
      final target = _inB + const Offset(40, 20);
      final to = target - (grabbed + caught.size.center(Offset.zero));
      for (var i = 0; i < 10; i++) {
        await second.moveBy(to / 10);
        await tester.pump(frame);
      }
      await second.up();
      await tester.pumpAndSettle();
      expect(board.currentState!.b, ['x']);
      expect(find.byKey(_feedback), findsNothing);
      expect(_isShown(tester, 'x'), isTrue);
    });

    testWidgets('ticks at tickerRate', (tester) async {
      await tester.pumpWidget(
        _app(
          MotionDraggable<String>(
            data: 'x',
            tickerRate: TickerRate.fps(10),
            child: SizedBox.fromSize(
              size: _itemSize,
              child: const ColoredBox(color: Color(0xFF888888)),
            ),
          ),
        ),
      );
      final gesture = await _drag(tester, const Offset(200, 200));
      await gesture.up();
      await tester.pump(frame);
      await tester.pump(frame);
      expect(FixedTicker.hasActiveTimers, isTrue);
      await tester.pumpAndSettleFixedTickers();
    });
  });

  group('MotionDraggable flight', () {
    testWidgets('keeps following the pointer after its source is disposed, '
        'and lands', (tester) async {
      final board = GlobalKey<_BoardState>();
      var landed = 0;
      await tester.pumpWidget(
        _app(_Board(key: board, onLanded: () => landed++)),
      );

      final gesture = await _drag(tester, const Offset(200, 100));
      board.currentState!.removeFromA('x');
      await tester.pump();
      expect(_child('x'), findsNothing);

      // The pointer moves on over B.
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(50, 45));
        await tester.pump(frame);
      }
      expect(_feedbackRect(tester).topLeft, const Offset(400, 280));

      await gesture.up();
      expect(board.currentState!.accepted, 1);
      await tester.pumpAndSettle();
      expect(board.currentState!.b, ['x']);
      expect(find.byKey(_feedback), findsNothing);
      expect(_isShown(tester, 'x'), isTrue);
      expect(landed, 1);
    });

    testWidgets('exits when its rejected source is gone', (tester) async {
      final board = GlobalKey<_BoardState>();
      await tester.pumpWidget(_app(_Board(key: board)));

      final gesture = await _drag(tester, const Offset(250, 300));
      board.currentState!.removeFromA('x');
      await tester.pump();
      await gesture.up();
      final drop = _feedbackRect(tester);
      await tester.pump();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_feedbackRect(tester).width, lessThan(drop.width));
      expect(
        _feedbackRect(tester).center.dx,
        moreOrLessEquals(drop.center.dx, epsilon: 1),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
    });

    testWidgets('exits when a popped route takes its destination along', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      var landed = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Navigator(
            key: navigator,
            onGenerateRoute: (settings) => PageRouteBuilder<void>(
              pageBuilder: (context, _, _) => const SizedBox(),
            ),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => _Board(onLanded: () => landed++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await _drag(tester, const Offset(250, 300));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(_feedback), findsOneWidget);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
      expect(landed, 1);
    });

    testWidgets('goes away quietly when its overlay is unmounted', (
      tester,
    ) async {
      var landed = 0;
      await tester.pumpWidget(_app(_Board(onLanded: () => landed++)));

      final gesture = await _drag(tester, const Offset(250, 300));
      await tester.pumpWidget(const SizedBox());
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(frame);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(landed, 0);
    });

    testWidgets('reports duplicate tags and lands on the nearest', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_Board(items: const ['x', 'y'], tagOf: (_) => 'same')),
      );

      // Drag x, and let go next to y.
      final gesture = await _drag(tester, const Offset(0, 60));
      await gesture.up();
      await tester.pump();
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect('$error', contains('2 MotionDraggables have the tag same'));

      await tester.pumpAndSettle();
      expect(find.byKey(_feedback), findsNothing);
      // Both children are shown again once it has landed.
      expect(_isShown(tester, 'x'), isTrue);
      expect(_isShown(tester, 'y'), isTrue);
    });
  });

  group('MotionDraggable hand-off to MotionReorder', () {
    testWidgets('leaves the overlay once the card center is inside the '
        'destination viewport, with continuous velocity', (tester) async {
      await tester.pumpWidget(_app(const _ScrollBoard()));

      // Drop x above B's viewport: the card is at y 150, its place at 240.
      final gesture = await _drag(tester, const Offset(400, 150));
      await gesture.up();
      expect(_feedbackRect(tester).top, 150);

      final tops = <double>[];
      int? handOff;
      for (var i = 0; i < 300; i++) {
        await tester.pump(fineFrame);
        if (handOff == null && !_inOverlay()) handOff = tops.length;
        tops.add(_paintedRect(tester, 'x').top);
      }
      expect(handOff, isNotNull, reason: 'should hand off');
      // It flew in the overlay until the card was fully inside the viewport,
      // which starts at 200, and handed off before it arrived.
      // It flew in the overlay until the card's center was inside the
      // viewport, which starts at 200, and handed off before it arrived.
      expect(tops[handOff! - 1] + 20, lessThan(200));
      expect(tops[handOff] + 20, greaterThanOrEqualTo(199));
      expect(tops[handOff], lessThan(239));
      expectContinuousVelocity(tops, retargetAt: handOff);

      await tester.pumpAndSettle();
      expect(_paintedRect(tester, 'x').topLeft, const Offset(400, 240));
      expect(_isShown(tester, 'x'), isTrue);
    });

    testWidgets('in the tree, the card is clipped by its list and painted '
        'below what is stacked above the list', (tester) async {
      final board = GlobalKey<_ScrollBoardState>();
      await tester.pumpWidget(_app(_ScrollBoard(key: board)));

      final gesture = await _drag(tester, const Offset(400, 230));
      await gesture.up();
      await tester.pump();
      await tester.pump(fineFrame);
      expect(_inOverlay(), isFalse, reason: 'dropped inside the viewport');

      // Scroll x's place half out of the top of the viewport, to 190, while
      // it still flies.
      board.currentState!.scroll.jumpTo(50);
      await tester.pump(fineFrame);
      expect(tester.getTopLeft(_child('x')).dy, 190);
      expect(_inOverlay(), isFalse);

      final child = tester.renderObject(_child('x'));
      bool isCard(RenderObject? hit) {
        for (var node = hit; node != null; node = node.parent) {
          if (node == child) return true;
        }
        return false;
      }

      // Above the viewport, the list clips it away; under the header, the
      // header is on top; below the header, the card is.
      expect(isCard(_topHit(tester, const Offset(440, 195))), isFalse);
      expect(
        _topHit(tester, const Offset(440, 210)),
        tester.renderObject(find.byKey(_header)),
      );
      expect(isCard(_topHit(tester, const Offset(440, 225))), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a drop on a partly visible column hands off at once and is '
        'clipped by the board', (tester) async {
      // The board shows x 0 to 450; column B spans 400 to 600, so a card
      // there (400 to 480) is never fully visible.
      await tester.pumpWidget(_app(const _ScrollBoard(boardWidth: 450)));

      final gesture = await _drag(tester, const Offset(400, 230));
      await gesture.up();
      await tester.pump();
      expect(_inOverlay(), isTrue, reason: 'the drop frame coasts');
      await tester.pump(fineFrame);
      expect(_inOverlay(), isFalse, reason: 'handed off on the next frame');
      expect(_isShown(tester, 'x'), isTrue);

      final child = tester.renderObject(_child('x'));
      bool isCard(RenderObject? hit) {
        for (var node = hit; node != null; node = node.parent) {
          if (node == child) return true;
        }
        return false;
      }

      // Inside the board it's the card; past the board's edge the board
      // clips it, where the overlay would have painted it on top.
      expect(isCard(_topHit(tester, const Offset(440, 250))), isTrue);
      expect(isCard(_topHit(tester, const Offset(465, 250))), isFalse);
      await tester.pumpAndSettle();
      expect(_paintedRect(tester, 'x').topLeft, const Offset(400, 240));
    });

    testWidgets('a drop whose slot is scrolled above the column flies clipped '
        'by the column', (tester) async {
      final board = GlobalKey<_ScrollBoardState>();
      await tester.pumpWidget(
        _app(
          _ScrollBoard(
            key: board,
            b: const ['y1', 'y2', 'y3', 'y4', 'y5', 'y6'],
            insertFirst: true,
          ),
        ),
      );
      // Scroll so the top of the list is 100 px above the viewport, which
      // starts at 200.
      board.currentState!.scroll.jumpTo(100);
      await tester.pump();

      final gesture = await _drag(tester, const Offset(400, 250));
      await gesture.up();
      await tester.pump();
      // x's slot is at 200 - 100 = 100, above the viewport.
      expect(tester.getTopLeft(_child('x')), const Offset(400, 100));

      double? clippedTop;
      for (var i = 0; i < 200 && _inOverlay(); i++) {
        await tester.pump(fineFrame);
        if (!_inOverlay()) break;
        final card = _feedbackRect(tester);
        if (card.top < 195 && card.bottom > 205) {
          clippedTop = card.top;
          // Above the column's top edge the card is cut away; below it, it
          // can still be grabbed.
          expect(
            _topHit(tester, Offset(440, card.top + 1)),
            isNot(tester.renderObject(find.byKey(_feedback))),
          );
          break;
        }
      }
      expect(clippedTop, isNotNull, reason: 'should cross the top edge');

      // Its center leaves the column's visible area as it flies on toward
      // the slot, and it stays clipped.
      var checkedAbove = false;
      for (var i = 0; i < 200 && _inOverlay(); i++) {
        await tester.pump(fineFrame);
        if (!_inOverlay()) break;
        final card = _feedbackRect(tester);
        if (card.center.dy < 195) {
          expect(
            _topHit(tester, card.center),
            isNot(tester.renderObject(find.byKey(_feedback))),
          );
          checkedAbove = true;
          break;
        }
      }
      expect(checkedAbove, isTrue, reason: 'should fly out above the column');
      await tester.pumpAndSettle();
      expect(_inOverlay(), isFalse);
    });

    testWidgets('the lift carries on in the tree after the hand-off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _ScrollBoard(
            transitions: (drag) => [
              if (drag.phase == MotionDragPhase.dragging)
                MotionDraggableTrack.scale([const TrackStep.to(1.2)]),
            ],
          ),
        ),
      );
      double treeScale() => tester
          .renderObject<RenderPaintedVisuals>(
            find.ancestor(
              of: _child('x'),
              matching: find.byType(PaintedVisuals),
            ),
          )
          .widget
          .scale();

      final gesture = await _drag(tester, const Offset(20, 100));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();
      final lifted = _feedbackRect(tester).width / 80;
      expect(lifted, greaterThan(1.15));

      // Handed off on the next frame: the card in the tree is still lifted
      // and springs down from there.
      await tester.pump(fineFrame);
      expect(_inOverlay(), isFalse);
      expect(treeScale(), moreOrLessEquals(lifted, epsilon: 0.02));
      await tester.pumpAndSettle();
      expect(treeScale(), 1);
    });

    testWidgets('a drop into the same viewport hands off at once', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _ScrollBoard()));

      // Rejected inside column A, which has no scrollable: the overlay is
      // its viewport.
      final gesture = await _drag(tester, const Offset(20, 100));
      await gesture.up();
      await tester.pump();
      await tester.pump(fineFrame);
      expect(_inOverlay(), isFalse);
      expect(_isShown(tester, 'x'), isTrue);
      expect(_paintedRect(tester, 'x').top, greaterThan(50));

      await tester.pumpAndSettle();
      expect(_paintedRect(tester, 'x').topLeft, Offset.zero);
    });

    testWidgets('after a hand-off, the overlay copy fades out on top', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const _ScrollBoard(
            handoffFade: CupertinoMotion.smooth(
              duration: Duration(milliseconds: 150),
            ),
          ),
        ),
      );

      final gesture = await _drag(tester, const Offset(20, 100));
      await gesture.up();
      await tester.pump();
      await tester.pump(fineFrame);
      // Handed off: the card shows in the tree while its copy still sits on
      // top, fading.
      expect(_isShown(tester, 'x'), isTrue);
      expect(_inOverlay(), isTrue);
      await tester.pump(fineFrame);
      final opacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(_feedback),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity, lessThan(1));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_inOverlay(), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('without a MotionReorder, the overlay flight lands', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));

      final gesture = await _drag(tester, const Offset(400, 280));
      await gesture.up();
      final overlayFrames = <bool>[];
      for (var i = 0; i < 20; i++) {
        await tester.pump(frame);
        overlayFrames.add(_inOverlay());
      }
      expect(overlayFrames, everyElement(isTrue));
      await tester.pumpAndSettle();
      expect(_inOverlay(), isFalse);
    });
  });

  group('MotionDraggable.handoff', () {
    // Each drops x at y 150, above B's viewport, which starts at 200; x's
    // place is at 240.
    Future<List<bool>> dropAboveViewport(
      WidgetTester tester,
      MotionDragHandoff handoff,
    ) async {
      await tester.pumpWidget(_app(_ScrollBoard(handoff: handoff)));
      final gesture = await _drag(tester, const Offset(400, 150));
      await gesture.up();
      await tester.pump();
      final inOverlay = <bool>[];
      for (var i = 0; i < 100; i++) {
        await tester.pump(fineFrame);
        inOverlay.add(_inOverlay());
      }
      await tester.pumpAndSettle();
      expect(_paintedRect(tester, 'x').topLeft, const Offset(400, 240));
      return inOverlay;
    }

    testWidgets('onEnter hands off once the card center is in view', (
      tester,
    ) async {
      final inOverlay = await dropAboveViewport(
        tester,
        MotionDragHandoff.onEnter,
      );
      expect(inOverlay.first, isTrue);
      expect(inOverlay.last, isFalse);
    });

    testWidgets('immediate hands off on the frame after the drop', (
      tester,
    ) async {
      final inOverlay = await dropAboveViewport(
        tester,
        MotionDragHandoff.immediate,
      );
      expect(inOverlay, everyElement(isFalse));
    });

    testWidgets('never keeps the whole landing in the overlay', (
      tester,
    ) async {
      final inOverlay = await dropAboveViewport(
        tester,
        MotionDragHandoff.never,
      );
      expect(inOverlay, everyElement(isTrue));
    });
  });
}
