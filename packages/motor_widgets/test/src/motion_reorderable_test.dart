import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';
import 'package:motor_widgets/src/painted_position.dart';

import '../util.dart';

const _feedback = Key('feedback');
const _size = Size(100, 40);

/// Column A's left edge, and column B's.
const _a = 0.0;
const _b = 400.0;

Finder _child(String id) =>
    find.byKey(ValueKey('child-$id'), skipOffstage: false);

/// Where item [id] is laid out.
Rect _layout(WidgetTester tester, String id) {
  final box = tester.renderObject<RenderBox>(_child(id));
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Where item [id] is painted, including its MotionLayoutItem's flight.
Rect _painted(WidgetTester tester, String id) =>
    paintedGlobalRect(tester.renderObject<RenderBox>(_child(id)));

bool _inOverlay() => find.byKey(_feedback).evaluate().isNotEmpty;

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]),
      ),
    );

/// An item that drags, with its own size. While it is dragged it leaves
/// the layout, and the gap opens in its place.
Widget _card(String id, {Size size = _size}) => MotionDraggable<String>(
  data: id,
  id: id,
  feedback: (context, drag) =>
      const ColoredBox(key: _feedback, color: Color(0xFF000000)),
  childWhenDragging: (context, size) => const SizedBox.shrink(),
  motions: {MotionDraggableTrack.handoffFade: const Motion.instant()},
  child: SizedBox.fromSize(
    key: ValueKey('child-$id'),
    size: size,
    child: const ColoredBox(color: Color(0xFF888888)),
  ),
);

/// A [MotionReorderable] of [items] that opens a gap in front of
/// [MotionDrop.before], laid out by [layout].
///
/// [onInsert] gets the dropped id and its index, [gap] the gap's index
/// among the items without the dragged one, or null while there is none.
Widget _reorderable({
  required List<String> items,
  required Widget Function(String id) item,
  required Widget Function(List<Widget> children) layout,
  FutureOr<void> Function(String id, int index)? onInsert,
  ValueChanged<int?>? gap,
  Widget Function(Size? size)? placeholder,
  MotionDragPoint point = MotionDragPoint.pointer,
}) => MotionReorderable<String>(
  items: items,
  point: point,
  onMove: onInsert == null
      ? null
      : (move) => onInsert(move.data as String, move.index),
  builder: (context, drop) {
    final order = [
      for (final id in items)
        if (id != drop?.item) id,
    ];
    gap?.call(
      drop == null
          ? null
          : drop.before == null
          ? order.length
          : order.indexOf(drop.before!),
    );
    Widget room(MotionDrop<String> drop) => MotionDropGap(
      key: const ValueKey('gap'),
      child:
          placeholder?.call(drop.size) ??
          SizedBox.fromSize(size: drop.size ?? Size.zero),
    );
    return layout([
      for (final id in items) ...[
        if (drop != null && drop.before == id) room(drop),
        MotionReorderableItem(
          key: ValueKey('item-$id'),
          item: id,
          child: item(id),
        ),
      ],
      if (drop != null && drop.before == null) room(drop),
    ]);
  },
);

/// Two zones: A at x 0 and B at x 400, each a Column of 100 x 40 cards in
/// a 200 x 600 box. A drop inserts where the zone says.
class _Board extends StatefulWidget {
  const _Board({
    this.a = const ['x'],
    this.onInsertB,
    this.probe = MotionDragPoint.pointer,
    this.placeholder,
  });

  final List<String> a;

  /// Replaces B's insert. Returns a future for an async insert.
  final FutureOr<void> Function(_BoardState board, String id, int index)?
  onInsertB;

  final MotionDragPoint probe;
  final Widget Function(Size? size)? placeholder;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  late final a = [...widget.a];
  final b = ['b0', 'b1', 'b2', 'b3', 'b4'];

  /// The sizes of cards, by id, when they aren't 100 x 40.
  final sizes = <String, Size>{};
  final inserts = <(String, String, int)>[];
  int? gapA;
  int? gapB;

  void removeFromA(String id) => setState(() => a.remove(id));

  void insert(List<String> to, String id, int index) => setState(() {
    a.remove(id);
    b.remove(id);
    to.insert(index, id);
  });

  Widget _zone(String name, List<String> items) => SizedBox(
    width: 200,
    height: 600,
    child: _reorderable(
      items: items,
      point: widget.probe,
      placeholder: widget.placeholder,
      onInsert: (id, index) {
        inserts.add((name, id, index));
        if (name == 'B' && widget.onInsertB != null) {
          return widget.onInsertB!(this, id, index);
        }
        insert(items, id, index);
      },
      item: (id) => _card(id, size: sizes[id] ?? _size),
      gap: (index) => name == 'A' ? gapA = index : gapB = index,
      layout: (children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _zone('A', a),
      const SizedBox(width: 200),
      _zone('B', b),
    ],
  );
}

/// Picks up the card at [from] and moves it past the drag slop.
Future<TestGesture> _pickUp(WidgetTester tester, Offset from) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump();
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  return gesture;
}

/// Moves [gesture] to [to] in [steps] events, a frame each.
Future<void> _moveTo(
  WidgetTester tester,
  TestGesture gesture,
  Offset from,
  Offset to, {
  int steps = 5,
}) async {
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(frame);
  }
}

_BoardState _board(WidgetTester tester) =>
    tester.state<_BoardState>(find.byType(_Board));

void main() {
  group('MotionReorderable hover', () {
    testWidgets('opens a gap where the card is, and the cards after it fly', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(50, 20));
      final before = {
        for (final id in ['b0', 'b1', 'b2', 'b3']) id: _painted(tester, id),
      };
      // Between b1 (center 60) and b2 (center 100).
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      expect(_board(tester).gapB, 2);
      // Laid out below the gap at once, but painted where they were.
      expect(_layout(tester, 'b2').top, 120);
      expect(_painted(tester, 'b2').top, lessThan(120));
      expect(_painted(tester, 'b0'), before['b0']);
      expect(_painted(tester, 'b1'), before['b1']);
      await tester.pumpAndSettle();
      expect(_painted(tester, 'b2').top, 120);
      expect(_painted(tester, 'b3').top, 160);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('holds still within the band, and moves past it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await tester.pumpAndSettle();
      // b2's center is now at 140; the band is 8.
      await gesture.moveTo(const Offset(450, 146));
      await tester.pumpAndSettle();
      expect(_board(tester).gapB, 2);
      await gesture.moveTo(const Offset(450, 150));
      await tester.pump(frame);
      expect(_board(tester).gapB, 3);
      // And back: b2 is now above the gap, centered at 100.
      await tester.pumpAndSettle();
      await gesture.moveTo(const Offset(450, 94));
      await tester.pumpAndSettle();
      expect(_board(tester).gapB, 3);
      await gesture.moveTo(const Offset(450, 90));
      await tester.pump(frame);
      expect(_board(tester).gapB, 2);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a move back mid-flight keeps the velocity', (tester) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await tester.pumpAndSettle();
      await gesture.moveTo(const Offset(450, 150));
      final samples = <double>[];
      for (var i = 0; i < 6; i++) {
        await tester.pump(fineFrame);
        samples.add(_painted(tester, 'b2').top);
      }
      // b2 flies up into the old gap; send the gap back up mid-flight.
      await gesture.moveTo(const Offset(450, 80));
      for (var i = 0; i < 4; i++) {
        await tester.pump(fineFrame);
        samples.add(_painted(tester, 'b2').top);
      }
      expect(_board(tester).gapB, 2);
      expectContinuousVelocity(samples, retargetAt: 6);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a flick across every card moves the gap once, smoothly', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 10),
      );
      await tester.pumpAndSettle();
      expect(_board(tester).gapB, 0);
      final last = {
        for (final id in _board(tester).b) id: _painted(tester, id).top,
      };
      await gesture.moveTo(const Offset(450, 400));
      await tester.pump(frame);
      expect(_board(tester).gapB, 5);
      for (var i = 0; i < 30; i++) {
        await tester.pump(frame);
        for (final id in _board(tester).b) {
          final top = _painted(tester, id).top;
          expect((top - last[id]!).abs(), lessThan(20), reason: '$id jumped');
          last[id] = top;
        }
      }
      await tester.pumpAndSettle();
      expect(_painted(tester, 'b4').top, 160);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('leaving closes the gap, and coming back reopens it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await tester.pumpAndSettle();
      await _moveTo(
        tester,
        gesture,
        const Offset(450, 90),
        const Offset(300, 90),
      );
      expect(_board(tester).gapB, isNull);
      expect(_layout(tester, 'b2').top, 80);
      await tester.pump(frame);
      await _moveTo(
        tester,
        gesture,
        const Offset(300, 90),
        const Offset(450, 90),
      );
      expect(_board(tester).gapB, 2);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('only the zone under the card shows a gap', (tester) async {
      await tester.pumpWidget(
        _app(const _Board(a: ['x', 'a1', 'a2'])),
      );
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      final board = _board(tester);
      expect(board.gapB, 2);
      // A's own card left it, so A has closed up behind it.
      expect(board.gapA, isNull);
      expect(_layout(tester, 'a1').top, 0);
      await _moveTo(
        tester,
        gesture,
        const Offset(450, 90),
        const Offset(50, 50),
      );
      expect(board.gapB, isNull);
      expect(board.gapA, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('MotionReorderable probe', () {
    // The card is grabbed 15 px from its top, so the pointer is 5 px above
    // the feedback's center.
    for (final (probe, gap) in [
      (MotionDragPoint.feedbackCenter, 2),
      (MotionDragPoint.pointer, 1),
    ]) {
      testWidgets('$probe places the gap by its point', (tester) async {
        await tester.pumpWidget(_app(_Board(probe: probe)));
        final gesture = await _pickUp(tester, const Offset(50, 15));
        // The pointer at 58, the feedback's center at 63; b1's center at 60.
        await _moveTo(
          tester,
          gesture,
          const Offset(50, 15),
          const Offset(450, 58),
        );
        expect(_board(tester).gapB, gap);
        await gesture.up();
        await tester.pumpAndSettle();
      });
    }
  });

  group('MotionReorderable drop', () {
    testWidgets('the card takes the gap, and nothing else moves', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await tester.pumpAndSettle();
      final b2 = _painted(tester, 'b2');
      await gesture.up();
      await tester.pump();
      final board = _board(tester);
      expect(board.inserts, [('B', 'x', 2)]);
      expect(board.b, ['b0', 'b1', 'x', 'b2', 'b3', 'b4']);
      expect(_layout(tester, 'x'), const Rect.fromLTWH(_b, 80, 100, 40));
      for (var i = 0; i < 5; i++) {
        await tester.pump(frame);
        expect(_painted(tester, 'b2'), b2);
      }
      // The landing handed off to the card in the tree.
      expect(_inOverlay(), isFalse);
      await tester.pumpAndSettle();
      expect(_painted(tester, 'x'), const Rect.fromLTWH(_b, 80, 100, 40));
    });

    testWidgets('a card of another size makes the cards after it fly', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final state = _board(tester);
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await tester.pumpAndSettle();
      // x lands 80 tall, twice the gap it opened.
      state.sizes['x'] = const Size(100, 80);
      expect(_board(tester), same(state));
      final b2 = _painted(tester, 'b2');
      await gesture.up();
      await tester.pump();
      expect(_layout(tester, 'b2').top, 160);
      expect(_painted(tester, 'b2').top, closeTo(b2.top, 1));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'b2').top, 160);
    });

    testWidgets('a custom placeholder sizes the gap', (tester) async {
      await tester.pumpWidget(
        _app(
          _Board(
            placeholder: (size) => SizedBox(width: size!.width, height: 4),
          ),
        ),
      );
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 70),
      );
      await tester.pumpAndSettle();
      expect(_board(tester).gapB, 2);
      expect(_layout(tester, 'b2').top, 84);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_layout(tester, 'x').top, 80);
      expect(_painted(tester, 'b2').top, 120);
    });
  });

  group('MotionReorderable own items', () {
    testWidgets('picking one up changes nothing, and a drop reorders', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final before = {
        for (final id in ['b0', 'b2', 'b3', 'b4']) id: _painted(tester, id),
      };
      final gesture = await _pickUp(tester, const Offset(450, 60));
      await tester.pump(frame);
      expect(_board(tester).gapB, 1);
      for (final MapEntry(:key, :value) in before.entries) {
        expect(_painted(tester, key), value, reason: key);
      }
      // Below b3's center (140) plus the band.
      await _moveTo(
        tester,
        gesture,
        const Offset(450, 60),
        const Offset(450, 150),
      );
      expect(_board(tester).gapB, 3);
      await gesture.up();
      await tester.pumpAndSettle();
      final board = _board(tester);
      expect(board.inserts, [('B', 'b1', 3)]);
      expect(board.b, ['b0', 'b2', 'b3', 'b1', 'b4']);
      expect(_painted(tester, 'b1').top, 120);
    });

    for (var i = 0; i < 5; i++) {
      for (final (edge, dy) in [('top', 2.0), ('bottom', 38.0)]) {
        testWidgets('b$i picked up by its $edge edge moves nothing', (
          tester,
        ) async {
          await tester.pumpWidget(_app(const _Board()));
          final others = [
            for (var j = 0; j < 5; j++)
              if (j != i) 'b$j',
          ];
          final before = {for (final id in others) id: _painted(tester, id)};
          // Held still, every frame.
          final gesture = await tester.startGesture(Offset(450, 40.0 * i + dy));
          for (var frameIndex = 0; frameIndex < 10; frameIndex++) {
            await tester.pump(frame);
            expect(_board(tester).gapB, i);
            for (final MapEntry(:key, :value) in before.entries) {
              expect(
                _painted(tester, key),
                value,
                reason: '$key, frame $frameIndex',
              );
            }
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(_board(tester).b, ['b0', 'b1', 'b2', 'b3', 'b4']);
        });
      }
    }

    testWidgets('a rejected drop brings it back and lands on it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Board()));
      final gesture = await _pickUp(tester, const Offset(450, 60));
      await _moveTo(
        tester,
        gesture,
        const Offset(450, 60),
        const Offset(300, 300),
      );
      // Out of the zone, B closes up behind the card.
      expect(_layout(tester, 'b2').top, 40);
      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(_layout(tester, 'b1').top, 40);
      // Still on its way back from the drop point.
      expect(_painted(tester, 'b1').top, greaterThan(100));
      await tester.pumpAndSettle();
      expect(_board(tester).inserts, isEmpty);
      expect(_painted(tester, 'b1').top, 40);
      expect(_painted(tester, 'b2').top, 80);
    });

    testWidgets('screen-reader actions move it', (tester) async {
      await tester.pumpWidget(_app(const _Board()));
      final semantics = tester
          .widgetList<Semantics>(
            find.ancestor(of: _child('b1'), matching: find.byType(Semantics)),
          )
          .firstWhere(
            (s) => s.properties.customSemanticsActions?.isNotEmpty ?? false,
          );
      final actions = semantics.properties.customSemanticsActions!;
      expect(actions.keys.map((action) => action.label), [
        'Move to the start',
        'Move up',
        'Move down',
        'Move to the end',
      ]);
      actions.entries.firstWhere((e) => e.key.label == 'Move down').value();
      await tester.pumpAndSettle();
      expect(_board(tester).b, ['b0', 'b2', 'b1', 'b3', 'b4']);
    });
  });

  group('MotionReorderable async insert', () {
    testWidgets('lands on the gap, then on the card once it arrives', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _app(_Board(onInsertB: (board, id, index) => done.future)),
      );
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(470, 95),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      final board = _board(tester);
      // The landing waits on the gap, in the overlay.
      expect(board.gapB, 2);
      expect(_inOverlay(), isTrue);
      expect(
        tester.getRect(find.byKey(_feedback)),
        const Rect.fromLTWH(_b, 80, 100, 40),
      );
      board.insert(board.b, 'x', 2);
      done.complete();
      await tester.pump();
      await tester.pump();
      expect(board.gapB, isNull);
      expect(_layout(tester, 'x'), const Rect.fromLTWH(_b, 80, 100, 40));
      expect(_layout(tester, 'b2').top, 120);
      await tester.pumpAndSettle();
      expect(_inOverlay(), isFalse);
      expect(_painted(tester, 'x'), const Rect.fromLTWH(_b, 80, 100, 40));
    });

    testWidgets('a future that throws flies the card back', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _app(_Board(onInsertB: (board, id, index) => done.future)),
      );
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      done.completeError(StateError('offline'));
      await tester.pump();
      expect(tester.takeException(), isStateError);
      await tester.pump();
      expect(_board(tester).gapB, isNull);
      expect(_layout(tester, 'b2').top, 80);
      await tester.pumpAndSettle();
      expect(_inOverlay(), isFalse);
      // Back on its source, which never left A.
      expect(_board(tester).a, ['x']);
      expect(_painted(tester, 'x'), const Rect.fromLTWH(_a, 0, 100, 40));
    });

    testWidgets('a future without the item rejects the drop', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _app(
          _Board(
            a: const ['x', 'a1'],
            onInsertB: (board, id, index) => done.future,
          ),
        ),
      );
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(450, 90),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      // The app gave up and removed the item altogether.
      final board = _board(tester)..removeFromA('x');
      done.complete();
      await tester.pump();
      await tester.pump();
      expect(board.gapB, isNull);
      // Nowhere to land: the rejected exit shrinks and fades it.
      expect(_inOverlay(), isTrue);
      await tester.pumpAndSettle();
      expect(_inOverlay(), isFalse);
    });
  });

  group('MotionReorderable in a scrolling list', () {
    testWidgets('counts from the real index, and scrolls near the edge', (
      tester,
    ) async {
      final items = [for (var i = 0; i < 40; i++) 'i$i'];
      final controller = ScrollController(initialScrollOffset: 400);
      addTearDown(controller.dispose);
      int? gap;
      await tester.pumpWidget(
        _app(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.topLeft, child: _card('x')),
              const SizedBox(width: 100),
              SizedBox(
                width: 200,
                height: 400,
                child: _reorderable(
                  items: items,
                  item: (id) => SizedBox.fromSize(
                    key: ValueKey('child-$id'),
                    size: _size,
                  ),
                  gap: (index) => gap = index,
                  layout: (children) => MotionDragToScroll(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: children.length,
                      itemBuilder: (context, i) => children[i],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final gesture = await _pickUp(tester, const Offset(50, 20));
      // i10 is at the top of the viewport; between i11 and i12.
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(250, 90),
      );
      expect(gap, 12);
      // Near the bottom edge, with the pointer still.
      await _moveTo(
        tester,
        gesture,
        const Offset(250, 90),
        const Offset(250, 390),
      );
      final offset = controller.offset;
      final gapThen = gap!;
      for (var i = 0; i < 20; i++) {
        await tester.pump(frame);
      }
      expect(controller.offset, greaterThan(offset));
      expect(gap, greaterThan(gapThen));
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('after shuffles while scrolled, opens the gap where the card '
      'is picked up', (tester) async {
    final items = [for (var i = 0; i < 30; i++) 'i$i'];
    final random = math.Random(1);
    final controller = ScrollController(initialScrollOffset: 600);
    addTearDown(controller.dispose);
    late StateSetter setState;
    int? gap;
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 400,
            child: StatefulBuilder(
              builder: (context, set) {
                setState = set;
                return _reorderable(
                  items: items,
                  onInsert: (id, index) => set(() {
                    items
                      ..remove(id)
                      ..insert(index, id);
                  }),
                  item: _card,
                  gap: (index) => gap = index,
                  layout: (children) => ListView.builder(
                    controller: controller,
                    itemCount: children.length,
                    itemBuilder: (context, i) => children[i],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    // The cards in the cache extent, above and below the viewport, fly
    // unseen.
    for (var i = 0; i < 6; i++) {
      setState(() => items.shuffle(random));
      await tester.pump(frame);
      await tester.pump(frame);
    }
    await tester.pumpAndSettle();
    // Each card, held still, opens the gap where it is.
    for (final y in [20.0, 100.0, 220.0, 300.0, 380.0]) {
      final index = (600 + y) ~/ 40;
      final gesture = await _pickUp(tester, Offset(50, y));
      await tester.pump(frame);
      expect(gap, index, reason: 'at $y');
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('two zones may share ids: each drop lands in its own group', (
    tester,
  ) async {
    final lists = [
      ['a', 'b', 'c'],
      ['a', 'b', 'c'],
    ];
    final errors = <FlutterErrorDetails>[];
    final onError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = onError);
    late StateSetter setState;
    Widget zone(List<String> items) => SizedBox(
      width: 200,
      height: 600,
      child: _reorderable(
        items: items,
        onInsert: (id, index) => setState(() {
          items
            ..remove(id)
            ..insert(index, id);
        }),
        item: _card,
        layout: (children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                zone(lists[0]),
                const SizedBox(width: 200),
                zone(lists[1]),
              ],
            );
          },
        ),
      ),
    );
    // The first zone's a, below its b.
    final gesture = await _pickUp(tester, const Offset(50, 20));
    await _moveTo(tester, gesture, const Offset(50, 20), const Offset(50, 70));
    await gesture.up();
    await tester.pumpAndSettle();
    FlutterError.onError = onError;
    expect(errors, isEmpty);
    expect(lists, [
      ['b', 'a', 'c'],
      ['a', 'b', 'c'],
    ]);
    expect(_inOverlay(), isFalse);
    expect(tester.getTopLeft(_child('a').first), const Offset(0, 40));
  });

  group('MotionReorderable in a wrap', () {
    Widget wrap(List<String> items, {required ValueChanged<int?> gap}) =>
        SizedBox(
          width: 300,
          child: _reorderable(
            items: items,
            item: _card,
            gap: gap,
            layout: (children) => Wrap(children: children),
          ),
        );

    for (final direction in TextDirection.values) {
      testWidgets('finds the row, then the place in it ($direction)', (
        tester,
      ) async {
        // Three tiles to a row: t0 t1 t2 / t3 t4.
        int? gap;
        await tester.pumpWidget(
          _app(
            direction: direction,
            Align(
              alignment: AlignmentDirectional.topStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  wrap(['t0', 't1', 't2', 't3', 't4'], gap: (g) => gap = g),
                  const SizedBox(height: 100),
                  wrap(['x'], gap: (_) {}),
                ],
              ),
            ),
          ),
        );
        final x = tester.getCenter(_child('x'));
        final t4 = tester.getRect(_child('t4'));
        final t0 = tester.getRect(_child('t0'));
        final gesture = await _pickUp(tester, x);
        // Over the leading half of t4, in the second row.
        final leading = direction == TextDirection.ltr
            ? t4.centerLeft + const Offset(10, 0)
            : t4.centerRight - const Offset(10, 0);
        await _moveTo(tester, gesture, x, leading);
        expect(gap, 4);
        // Over the trailing half of the first row's first tile.
        final trailing = direction == TextDirection.ltr
            ? t0.centerRight - const Offset(10, 0)
            : t0.centerLeft + const Offset(10, 0);
        await _moveTo(tester, gesture, leading, trailing);
        expect(gap, 1);
        await gesture.up();
        await tester.pumpAndSettle();
      });
    }
  });

  testWidgets('a plain Draggable opens a gap by its offset', (tester) async {
    int? gap;
    String? inserted;
    await tester.pumpWidget(
      _app(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Draggable<String>(
              data: 'x',
              feedback: SizedBox.shrink(),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              child: SizedBox(
                width: 100,
                height: 40,
                child: ColoredBox(color: Color(0xFF888888)),
              ),
            ),
            const SizedBox(width: 300),
            SizedBox(
              width: 200,
              height: 600,
              child: _reorderable(
                items: const ['b0', 'b1'],
                onInsert: (id, index) => inserted = '$id@$index',
                item: (id) => SizedBox.fromSize(key: ValueKey(id), size: _size),
                gap: (index) => gap = index,
                layout: (children) => Column(children: children),
              ),
            ),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 20));
    await _moveTo(tester, gesture, const Offset(50, 20), const Offset(480, 50));
    expect(gap, 1);
    await gesture.up();
    await tester.pump();
    expect(inserted, 'x@1');
  });

  group('MotionReorderable drops', () {
    testWidgets('a line between neighbors: nothing moves, and the move gets '
        'the neighbors', (tester) async {
      final items = ['a', 'b', 'c', 'd'];
      MotionDrop<String>? seen;
      MotionMove<String>? moved;
      late StateSetter setState;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  child: MotionReorderable<String>(
                    items: items,
                    onMove: (move) => setState(() {
                      moved = move;
                      items
                        ..remove(move.item)
                        ..insert(move.index, move.item!);
                    }),
                    builder: (context, drop) {
                      seen = drop;
                      return Column(
                        children: [
                          for (final id in items)
                            MotionReorderableItem(
                              key: ValueKey(id),
                              item: id,
                              // The default keeps the dragged card's room.
                              child: MotionDraggable<String>(
                                data: id,
                                id: id,
                                child: SizedBox.fromSize(
                                  key: ValueKey('child-$id'),
                                  size: _size,
                                  child: const ColoredBox(
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      final before = {for (final id in items) id: _layout(tester, id)};
      final gesture = await _pickUp(tester, const Offset(50, 20));
      // Between c (center 100) and d (center 140).
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(50, 125),
      );
      expect(seen?.after, 'c');
      expect(seen?.before, 'd');
      for (final id in ['b', 'c', 'd']) {
        expect(_painted(tester, id), before[id], reason: id);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moved?.after, 'c');
      expect(moved?.before, 'd');
      expect(moved?.index, 2);
      expect(items, ['b', 'c', 'a', 'd']);
    });

    testWidgets('foreign data opens a gap of its own and becomes an item', (
      tester,
    ) async {
      final items = ['a', 'b'];
      MotionDrop<String>? seen;
      late StateSetter setState;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A draft that becomes the item 'new'.
                  const MotionDraggable<int>(
                    data: 7,
                    id: 'new',
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: ColoredBox(color: Color(0xFF888888)),
                    ),
                  ),
                  const SizedBox(width: 144),
                  SizedBox(
                    width: 200,
                    height: 400,
                    child: MotionReorderable<String>(
                      items: items,
                      onWillAccept: (data) => data is int,
                      onMove: (move) =>
                          setState(() => items.insert(move.index, 'new')),
                      builder: (context, drop) {
                        seen = drop;
                        return Column(
                          children: [
                            for (final id in items) ...[
                              if (drop != null && drop.before == id)
                                const MotionDropGap(
                                  // The new item's shape, not the draft's.
                                  child: SizedBox(
                                    key: ValueKey('ghost'),
                                    width: 200,
                                    height: 80,
                                  ),
                                ),
                              MotionReorderableItem(
                                key: ValueKey(id),
                                item: id,
                                child: SizedBox.fromSize(
                                  key: ValueKey('child-$id'),
                                  size: _size,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final gesture = await _pickUp(tester, const Offset(28, 28));
      await _moveTo(
        tester,
        gesture,
        const Offset(28, 28),
        const Offset(250, 30),
      );
      expect(seen?.data, 7);
      expect(seen?.item, isNull);
      expect(seen?.before, 'b');
      expect(tester.getSize(find.byKey(const ValueKey('ghost'))).height, 80);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(items, ['a', 'new', 'b']);
    });

    testWidgets('two sliver sections in one scroll view take drags between '
        'them', (tester) async {
      final sections = [
        ['a0', 'a1'],
        ['b0', 'b1'],
      ];
      late StateSetter setState;
      Widget section(List<String> items) => MotionReorderable<String>.sliver(
        items: items,
        onMove: (move) => setState(() {
          for (final other in sections) {
            other.remove(move.item);
          }
          items.insert(move.index, move.item!);
        }),
        builder: (context, drop) => SliverList.list(
          children: [
            for (final id in items) ...[
              if (drop != null && drop.before == id)
                MotionDropGap(child: SizedBox.fromSize(size: _size)),
              MotionReorderableItem(
                key: ValueKey(id),
                item: id,
                child: _card(id),
              ),
            ],
            if (drop != null && drop.before == null)
              MotionDropGap(child: SizedBox.fromSize(size: _size)),
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 600,
                  child: MotionLayoutGroup(
                    child: CustomScrollView(
                      slivers: [
                        section(sections[0]),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                        section(sections[1]),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      // a0 leaves its section, so b0 is at 80 and b1 at 120. Passing b0
      // opens the gap before b1, which the pointer then rests in.
      final gesture = await _pickUp(tester, const Offset(50, 20));
      await _moveTo(
        tester,
        gesture,
        const Offset(50, 20),
        const Offset(50, 150),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sections, [
        ['a1'],
        ['b0', 'a0', 'b1'],
      ]);
      expect(_inOverlay(), isFalse);
    });
  });
}
