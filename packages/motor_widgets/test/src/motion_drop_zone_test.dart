import 'dart:async';

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

/// Where item [id] is painted, including its MotionReorder's flight.
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

/// An item that drags, with its own size.
Widget _card(String id, {Size size = _size}) => MotionDraggable<String>(
  data: id,
  feedback: const ColoredBox(key: _feedback, color: Color(0xFF000000)),
  motions: {MotionDraggableTrack.handoffFade: const Motion.instant()},
  child: SizedBox.fromSize(
    key: ValueKey('child-$id'),
    size: size,
    child: const ColoredBox(color: Color(0xFF888888)),
  ),
);

/// Two zones: A at x 0 and B at x 400, each a Column of 100 x 40 cards in
/// a 200 x 600 box. A drop inserts where the zone says.
class _Board extends StatefulWidget {
  const _Board({
    this.a = const ['x'],
    this.onInsertB,
    this.probe = MotionDragProbe.pointer,
    this.placeholder,
  });

  final List<String> a;

  /// Replaces B's insert. Returns a future for an async insert.
  final FutureOr<void> Function(_BoardState board, String id, int index)?
  onInsertB;

  final MotionDragProbe probe;
  final MotionDropPlaceholderBuilder? placeholder;

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
    child: MotionDropZone<String>(
      items: items,
      probe: widget.probe,
      placeholderBuilder: widget.placeholder,
      onInsert: (id, index) {
        inserts.add((name, id, index));
        if (name == 'B' && widget.onInsertB != null) {
          return widget.onInsertB!(this, id, index);
        }
        insert(items, id, index);
      },
      builder: (context, slots) {
        if (name == 'A') {
          gapA = slots.gapIndex;
        } else {
          gapB = slots.gapIndex;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < slots.length; i++)
              slots.build(
                i,
                (context, id) => _card(id, size: sizes[id] ?? _size),
              ),
          ],
        );
      },
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
  group('MotionDropZone hover', () {
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

  group('MotionDropZone probe', () {
    // The card is grabbed 15 px from its top, so the pointer is 5 px above
    // the feedback's center.
    for (final (probe, gap) in [
      (MotionDragProbe.feedbackCenter, 2),
      (MotionDragProbe.pointer, 1),
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

  group('MotionDropZone drop', () {
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
            placeholder: (context, size) =>
                SizedBox(width: size.width, height: 4),
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

  group('MotionDropZone own items', () {
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

  group('MotionDropZone async insert', () {
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

  group('MotionDropZone in a scrolling list', () {
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
                child: MotionDropZone<String>(
                  items: items,
                  builder: (context, slots) {
                    gap = slots.gapIndex;
                    return ListView.builder(
                      controller: controller,
                      itemCount: slots.length,
                      findChildIndexCallback: slots.indexOfKey,
                      itemBuilder: (context, i) => slots.build(
                        i,
                        (context, id) => SizedBox.fromSize(
                          key: ValueKey('child-$id'),
                          size: _size,
                        ),
                      ),
                    );
                  },
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

  group('MotionDropZone in a wrap', () {
    Widget wrap(List<String> items, {required ValueChanged<int?> gap}) =>
        SizedBox(
          width: 300,
          child: MotionDropZone<String>(
            items: items,
            builder: (context, slots) {
              gap(slots.gapIndex);
              return Wrap(
                children: [
                  for (var i = 0; i < slots.length; i++)
                    slots.build(i, (context, id) => _card(id)),
                ],
              );
            },
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
              child: MotionDropZone<String>(
                items: const ['b0', 'b1'],
                onInsert: (id, index) => inserted = '$id@$index',
                builder: (context, slots) {
                  gap = slots.gapIndex;
                  return Column(
                    children: [
                      for (var i = 0; i < slots.length; i++)
                        slots.build(
                          i,
                          (context, id) =>
                              SizedBox.fromSize(key: ValueKey(id), size: _size),
                        ),
                    ],
                  );
                },
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
}
