import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';
import 'package:motor_widgets/src/painted_position.dart';

const _tile = Size(100, 40);

Finder _find(String id) => find.byKey(ValueKey(id), skipOffstage: false);

RenderBox _box(WidgetTester tester, String id) =>
    tester.renderObject<RenderBox>(_find(id));

/// Where item [id] is laid out, in global coordinates.
Offset _layout(WidgetTester tester, String id) =>
    _box(tester, id).localToGlobal(Offset.zero);

/// Where item [id] is painted: its layout position plus its flight, and the
/// flights around it.
Offset _painted(WidgetTester tester, String id) {
  final box = _box(tester, id);
  return box.localToGlobal(Offset.zero) +
      (box as PaintOffset).paintOffset +
      paintOffsetAbove(box);
}

bool _flying(WidgetTester tester, String id) =>
    (_painted(tester, id) - _layout(tester, id)).distance > 0.01;

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (_) => Align(alignment: Alignment.topLeft, child: child),
        ),
      ],
    ),
  ),
);

Widget _item(String id, {Size size = _tile}) => MotionLayoutItem(
  key: ValueKey(id),
  id: id,
  child: SizedBox.fromSize(
    size: size,
    child: const ColoredBox(color: Color(0xFF888888)),
  ),
);

/// Builds [build] from its state, which tests change with `update`.
class _Host extends StatefulWidget {
  const _Host(this.build, {super.key});

  final Widget Function(BuildContext context) build;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  void update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => widget.build(context);
}

Future<void> _pumpHost(
  WidgetTester tester,
  Widget Function(BuildContext context) build,
) => tester.pumpWidget(_app(_Host(build, key: _host)));

final _host = GlobalKey<_HostState>();

void _update(VoidCallback change) => _host.currentState!.update(change);

Widget _column(List<String> ids) => MotionLayoutGroup(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final id in ids) _item(id)],
  ),
);

void main() {
  group('MotionLayoutGroup', () {
    testWidgets('a reorder flies each moved item from where it was painted', (
      tester,
    ) async {
      var ids = ['a', 'b', 'c'];
      await _pumpHost(tester, (_) => _column(ids));
      final before = {for (final id in ids) id: _layout(tester, id)};

      _update(() => ids = ['c', 'a', 'b']);
      await tester.pump();
      // The frame of the reorder paints every item where it was.
      for (final id in ids) {
        expect(_painted(tester, id), before[id], reason: id);
      }
      expect(_layout(tester, 'c'), before['a']);

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _painted(tester, 'c').dy;
      expect(midway, lessThan(before['c']!.dy));
      expect(midway, greaterThan(before['a']!.dy));

      await tester.pumpAndSettle();
      for (final id in ids) {
        expect(_flying(tester, id), isFalse, reason: id);
      }
    });

    testWidgets('the first build and new items do not fly', (tester) async {
      var ids = ['a', 'b'];
      await _pumpHost(tester, (_) => _column(ids));
      expect(_flying(tester, 'a'), isFalse);

      _update(() => ids = ['a', 'n', 'b']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_flying(tester, 'n'), isFalse);
      // The insert moved b, so b flies.
      expect(_flying(tester, 'b'), isTrue);
      expect(_flying(tester, 'a'), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('a neighbor that grows moves the items after it, and they '
        'fly', (tester) async {
      var height = 40.0;
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 100, height: height),
              _item('a'),
            ],
          ),
        ),
      );
      final before = _layout(tester, 'a');
      _update(() => height = 100);
      await tester.pump();
      expect(_painted(tester, 'a'), before);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 40));
      expect(_painted(tester, 'a').dy, greaterThan(before.dy));
      expect(_painted(tester, 'a').dy, lessThan(before.dy + 60));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a'), before + const Offset(0, 60));
    });

    testWidgets('a lazy list flies by id, without findChildIndexCallback', (
      tester,
    ) async {
      var ids = [for (var i = 0; i < 10; i++) '$i'];
      await _pumpHost(
        tester,
        (_) => SizedBox(
          width: 200,
          height: 400,
          child: MotionLayoutGroup(
            child: ListView.builder(
              itemCount: ids.length,
              itemBuilder: (context, i) => _item(ids[i]),
            ),
          ),
        ),
      );
      final before = _layout(tester, '0');
      _update(() => ids = [...ids.reversed]);
      await tester.pump();
      // A new element at the bottom, painted where '0' was.
      expect(_layout(tester, '0'), const Offset(0, 360));
      expect(_painted(tester, '0'), before);
      await tester.pumpAndSettle();
      expect(_flying(tester, '0'), isFalse);
    });

    testWidgets('scrolling a list, the board around it, or both never '
        'flies', (tester) async {
      final board = ScrollController();
      final column = ScrollController();
      addTearDown(board.dispose);
      addTearDown(column.dispose);
      await _pumpHost(
        tester,
        (_) => SizedBox(
          width: 300,
          height: 300,
          child: MotionLayoutGroup(
            child: SingleChildScrollView(
              controller: board,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 600,
                height: 300,
                child: Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: 200,
                    child: ListView(
                      controller: column,
                      children: [
                        for (var i = 0; i < 20; i++) _item('$i'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final (b, c) in [(100.0, 0.0), (100.0, 80.0), (300.0, 200.0)]) {
        board.jumpTo(b);
        column.jumpTo(c);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        for (var i = 0; i < 20; i++) {
          if (find.byKey(ValueKey('$i')).evaluate().isEmpty) continue;
          expect(_flying(tester, '$i'), isFalse, reason: '$i at $b, $c');
        }
      }
    });

    testWidgets('a reorder in a scrolled list flies, and items that were '
        'off screen appear at rest', (tester) async {
      final column = ScrollController(initialScrollOffset: 400);
      addTearDown(column.dispose);
      var ids = [for (var i = 0; i < 40; i++) '$i'];
      await _pumpHost(
        tester,
        (_) => SizedBox(
          width: 200,
          height: 400,
          child: MotionLayoutGroup(
            child: ListView.builder(
              controller: column,
              itemCount: ids.length,
              itemBuilder: (context, i) => _item(ids[i]),
            ),
          ),
        ),
      );
      // Swap neighbors: every item on screen moves by one slot.
      _update(
        () => ids = [
          for (var i = 0; i < 40; i += 2) ...['${i + 1}', '$i'],
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_flying(tester, '12'), isTrue);
      await tester.pumpAndSettle();

      // Scrolled in after the reorder, items that moved while off screen
      // are at rest.
      column.jumpTo(800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 40; i++) {
        if (find.byKey(ValueKey('$i')).evaluate().isEmpty) continue;
        expect(_flying(tester, '$i'), isFalse, reason: '$i');
      }
    });

    testWidgets('after the scroll offset is clamped, only moved items fly', (
      tester,
    ) async {
      final column = ScrollController();
      addTearDown(column.dispose);
      var ids = [for (var i = 0; i < 30; i++) '$i'];
      await _pumpHost(
        tester,
        (_) => SizedBox(
          width: 200,
          height: 400,
          child: MotionLayoutGroup(
            child: ListView.builder(
              controller: column,
              physics: const ClampingScrollPhysics(),
              itemCount: ids.length,
              itemBuilder: (context, i) => _item(ids[i]),
            ),
          ),
        ),
      );
      column.jumpTo(column.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // The content shrinks, so layout clamps the offset without telling
      // listeners.
      _update(() => ids = ids.sublist(0, 25));
      await tester.pumpAndSettle();

      // Swap two items: only they fly.
      _update(() => ids = [...ids]..setAll(20, ['21', '20']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 30));
      for (final id in ids) {
        if (find.byKey(ValueKey(id)).evaluate().isEmpty) continue;
        expect(
          _flying(tester, id),
          id == '20' || id == '21',
          reason: id,
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('another move mid-flight redirects with its velocity', (
      tester,
    ) async {
      var ids = ['a', 'b', 'c'];
      await _pumpHost(tester, (_) => _column(ids));
      _update(() => ids = ['c', 'a', 'b']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 40));
      final p1 = _painted(tester, 'c').dy;
      await tester.pump(const Duration(milliseconds: 16));
      final p2 = _painted(tester, 'c').dy;
      final velocity = p2 - p1;
      expect(velocity, lessThan(0));

      // Back down: it keeps moving up a little before it turns.
      _update(() => ids = ['a', 'b', 'c']);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_painted(tester, 'c').dy, lessThan(p2));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'c'), const Offset(0, 80));
    });

    testWidgets('a wrap flies on both axes', (tester) async {
      var ids = ['a', 'b', 'c', 'd'];
      await _pumpHost(
        tester,
        (_) => SizedBox(
          width: 220,
          child: MotionLayoutGroup(
            child: Wrap(children: [for (final id in ids) _item(id)]),
          ),
        ),
      );
      _update(() => ids = ['d', 'b', 'c', 'a']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 40));
      final d = _painted(tester, 'd');
      expect(d.dx, inExclusiveRange(0, 100));
      expect(d.dy, inExclusiveRange(0, 40));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'd'), Offset.zero);
    });

    testWidgets('an item moved to another container of the group flies '
        'there', (tester) async {
      var left = ['a', 'b'];
      var right = <String>[];
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 200,
                child: Column(children: [for (final id in left) _item(id)]),
              ),
              SizedBox(
                width: 200,
                child: Column(children: [for (final id in right) _item(id)]),
              ),
            ],
          ),
        ),
      );
      final before = _layout(tester, 'b');
      _update(() {
        left = ['a'];
        right = ['b'];
      });
      await tester.pump();
      expect(_painted(tester, 'b'), before);
      await tester.pumpAndSettle();
      expect(_painted(tester, 'b'), _layout(tester, 'b'));
      expect(_layout(tester, 'b').dx, greaterThan(before.dx));
    });

    testWidgets('a group that moves takes its items along', (tester) async {
      var top = 0.0;
      await _pumpHost(
        tester,
        (_) => Padding(
          padding: EdgeInsets.only(top: top),
          child: _column(['a', 'b']),
        ),
      );
      _update(() => top = 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_flying(tester, 'a'), isFalse);
      expect(_layout(tester, 'a'), const Offset(0, 100));
    });

    testWidgets('hit testing stays at the layout position during a flight', (
      tester,
    ) async {
      var ids = ['a', 'b'];
      final taps = <String>[];
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          child: Column(
            children: [
              for (final id in ids)
                MotionLayoutItem(
                  key: ValueKey(id),
                  id: id,
                  child: GestureDetector(
                    onTap: () => taps.add(id),
                    child: SizedBox.fromSize(
                      size: _tile,
                      child: const ColoredBox(color: Color(0xFF888888)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      _update(() => ids = ['b', 'a']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(50, 20));
      expect(taps, ['b']);
      await tester.pumpAndSettle();
    });

    testWidgets('while disabled, items jump', (tester) async {
      var ids = ['a', 'b'];
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          enabled: false,
          child: Column(children: [for (final id in ids) _item(id)]),
        ),
      );
      _update(() => ids = ['b', 'a']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_flying(tester, 'a'), isFalse);
      expect(_flying(tester, 'b'), isFalse);
    });

    testWidgets('Motion.instant lands at once', (tester) async {
      var ids = ['a', 'b'];
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          motion: const Motion.instant(),
          child: Column(children: [for (final id in ids) _item(id)]),
        ),
      );
      _update(() => ids = ['b', 'a']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_flying(tester, 'a'), isFalse);
      // It starts after the frame and lands on its first tick, then asks
      // for no more frames.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a group at rest asks for no frames', (tester) async {
      var ids = ['a', 'b'];
      await _pumpHost(tester, (_) => _column(ids));
      expect(tester.binding.hasScheduledFrame, isFalse);
      _update(() => ids = ['b', 'a']);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reports two items with one id', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final onError = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        _app(
          MotionLayoutGroup(
            child: Column(
              children: [
                MotionLayoutItem(
                  id: 'x',
                  child: SizedBox.fromSize(size: _tile),
                ),
                MotionLayoutItem(
                  id: 'x',
                  child: SizedBox.fromSize(size: _tile),
                ),
              ],
            ),
          ),
        ),
      );
      FlutterError.onError = onError;
      expect(errors.map((e) => '${e.exception}'), contains(contains('id x')));
    });

    testWidgets('a column without keys reuses its children, and they still '
        'fly by id', (tester) async {
      var ids = ['a', 'b', 'c'];
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          child: Column(
            children: [
              for (final id in ids)
                MotionLayoutItem(
                  id: id,
                  child: SizedBox.fromSize(
                    key: ValueKey(id),
                    size: _tile,
                    child: const ColoredBox(color: Color(0xFF888888)),
                  ),
                ),
            ],
          ),
        ),
      );
      Offset painted(String id) => paintedGlobalRect(
        tester.renderObject<RenderBox>(find.byKey(ValueKey(id))),
      ).topLeft;
      final before = painted('c');
      _update(() => ids = ['c', 'a', 'b']);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('c'))), Offset.zero);
      expect(painted('c'), before);
      await tester.pumpAndSettle();
      expect(painted('c'), Offset.zero);
    });

    testWidgets('a neighbor that grows on its own pushes items along without '
        'a flight', (tester) async {
      var open = false;
      await _pumpHost(
        tester,
        (_) => MotionLayoutGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MotionSize(
                motion: const CupertinoMotion.smooth(),
                child: SizedBox(width: 100, height: open ? 100 : 40),
              ),
              _item('a'),
            ],
          ),
        ),
      );
      // Only the growing box rebuilds; the item doesn't.
      _update(() => open = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _layout(tester, 'a');
      expect(midway.dy, inExclusiveRange(40, 100));
      expect(_painted(tester, 'a'), midway);
      await tester.pumpAndSettle();
    });

    testWidgets('an item scrolled out of view mid-flight reports where it '
        'would be painted, and rests there', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var ids = [for (var i = 0; i < 30; i++) '$i'];
      await _pumpHost(
        tester,
        (_) => SizedBox(
          width: 200,
          height: 400,
          child: MotionLayoutGroup(
            child: ListView.builder(
              controller: controller,
              itemCount: ids.length,
              itemBuilder: (context, i) => _item(ids[i]),
            ),
          ),
        ),
      );
      // '1' flies from 40 to 320, in view.
      _update(
        () => ids = [...ids]
          ..remove('1')
          ..insert(8, '1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        (_box(tester, '1') as PaintOffset).paintOffset,
        isNot(Offset.zero),
      );
      // Scrolled above the viewport, into the cache extent, it isn't
      // painted while the flight ends.
      controller.jumpTo(400);
      await tester.pumpAndSettle();
      final box = tester.renderObject(_find('1')) as PaintOffset;
      expect(box.paintOffset, Offset.zero);
    });
  });
}
