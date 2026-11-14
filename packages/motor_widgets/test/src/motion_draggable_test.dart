import 'dart:async';

import 'package:fixed_ticker/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

import '../util.dart';

const _feedback = Key('feedback');
const _itemSize = Size(80, 40);

/// Where the item sits in column B, below the column's top padding.
const _inB = Offset(400, 200);

Finder _child(String id) => find.byKey(ValueKey('child-$id'));

/// Whether the child of item [id] is shown, rather than kept hidden.
bool _isShown(WidgetTester tester, String id) => tester
    .widget<Visibility>(
      find.ancestor(of: _child(id), matching: find.byType(Visibility)).first,
    )
    .visible;

Rect _feedbackRect(WidgetTester tester) =>
    tester.getRect(find.byKey(_feedback));

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

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  late final a = [...widget.items];
  final b = <String>[];
  int accepted = 0;
  double bTop = 200;

  void moveB(double top) => setState(() => bTop = top);

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
                children: [for (final id in b) _item(id)],
              ),
            ),
          ),
        ),
      ],
    );
  }
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
}
