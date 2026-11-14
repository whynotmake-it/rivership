import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

import '../util.dart';

const _tile = Size(100, 40);

Key _key(String id) => ValueKey(id);

RenderBox _box(WidgetTester tester, String id) =>
    tester.renderObject<RenderBox>(find.byKey(_key(id)));

/// Where item [id] is laid out, in global coordinates.
Offset _layout(WidgetTester tester, String id) =>
    _box(tester, id).localToGlobal(Offset.zero);

/// Where item [id] is painted, in global coordinates: its layout position
/// plus the translation of its reorder layer.
Offset _painted(WidgetTester tester, String id) {
  final box = _box(tester, id);
  final transform = (box.debugLayer as TransformLayer?)?.transform;
  final translation = transform?.getTranslation();
  return box.localToGlobal(Offset.zero) +
      (translation == null
          ? Offset.zero
          : Offset(translation.x, translation.y));
}

bool _flying(WidgetTester tester, String id) =>
    (_painted(tester, id) - _layout(tester, id)).distance > 0.01;

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]),
  ),
);

Widget _item(
  String id,
  int index, {
  Object? scope,
  bool enabled = true,
  Motion motion = MotionReorder.defaultMotion,
  Size size = _tile,
  bool repaintBoundary = true,
  Key? key,
  Widget? child,
}) => MotionReorder(
  key: key ?? _key(id),
  flightKey: index,
  scope: scope,
  enabled: enabled,
  motion: motion,
  repaintBoundary: repaintBoundary,
  child:
      child ??
      SizedBox.fromSize(
        size: size,
        child: const ColoredBox(color: Color(0xFF888888)),
      ),
);

/// A list of [items] laid out by [layout], which `reorder` reorders.
class _List extends StatefulWidget {
  const _List({
    required this.items,
    required this.layout,
    super.key,
  });

  final List<String> items;
  final Widget Function(BuildContext context, List<String> items) layout;

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  late List<String> items = [...widget.items];

  void reorder(List<String> next) => setState(() => items = next);

  @override
  Widget build(BuildContext context) => widget.layout(context, items);
}

Widget _column(BuildContext context, List<String> items) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [for (final (i, id) in items.indexed) _item(id, i)],
);

ListView _builder(
  List<String> items, {
  ScrollController? controller,
  Widget Function(String id, int index)? itemBuilder,
}) => ListView.builder(
  controller: controller,
  itemCount: items.length,
  findChildIndexCallback: (key) {
    final index = items.indexOf((key as ValueKey<String>).value);
    return index < 0 ? null : index;
  },
  itemBuilder: (context, i) =>
      itemBuilder?.call(items[i], i) ?? _item(items[i], i),
);

void main() {
  group('MotionReorder', () {
    testWidgets('a reorder flies each moved item from where it was painted', (
      tester,
    ) async {
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(_List(key: list, items: const ['a', 'b', 'c'], layout: _column)),
      );
      final before = {
        for (final id in ['a', 'b', 'c']) id: _layout(tester, id),
      };

      list.currentState!.reorder(['c', 'a', 'b']);
      await tester.pump();
      // The first frame still paints every item where it was.
      for (final id in ['a', 'b', 'c']) {
        expect(_painted(tester, id), before[id], reason: id);
      }
      expect(_layout(tester, 'c'), before['a']);

      await tester.pump(const Duration(milliseconds: 60));
      final midway = _painted(tester, 'c').dy;
      expect(midway, lessThan(before['c']!.dy));
      expect(midway, greaterThan(before['a']!.dy));

      await tester.pumpAndSettle();
      for (final id in ['a', 'b', 'c']) {
        expect(_flying(tester, id), isFalse, reason: id);
      }
    });

    testWidgets('the first build and new items do not fly', (tester) async {
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(_List(key: list, items: const ['a', 'b'], layout: _column)),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_flying(tester, 'a'), isFalse);

      list.currentState!.reorder(['new', 'a', 'b']);
      await tester.pump();
      expect(_flying(tester, 'new'), isFalse);
      expect(_flying(tester, 'a'), isTrue, reason: 'its index changed');
      await tester.pumpAndSettle();
    });

    testWidgets('a lazy ListView.builder with keys and findChildIndexCallback '
        'flies its items', (tester) async {
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: const ['a', 'b', 'c'],
            layout: (context, items) => _builder(items),
          ),
        ),
      );
      final aBefore = _layout(tester, 'a');

      list.currentState!.reorder(['b', 'c', 'a']);
      await tester.pump();
      expect(_painted(tester, 'a'), aBefore);
      expect(_layout(tester, 'a'), aBefore + const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_flying(tester, 'a'), isTrue);
      await tester.pumpAndSettle();
      expect(_flying(tester, 'a'), isFalse);
    });

    testWidgets('starts from where an item really was after a sibling above '
        'resized without repainting it', (tester) async {
      final list = GlobalKey<_ListState>();
      late StateSetter growA;
      var aHeight = 40.0;
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: const ['a', 'b', 'c'],
            layout: (context, items) => _builder(
              items,
              itemBuilder: (id, i) => _item(
                id,
                i,
                child: id == 'a'
                    ? StatefulBuilder(
                        builder: (context, setState) {
                          growA = setState;
                          return SizedBox(width: 100, height: aHeight);
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      );

      // Only a rebuilds. The list moves c down by moving c's repaint
      // boundary, without painting c.
      growA(() => aHeight = 100);
      await tester.pump();
      final cMoved = _layout(tester, 'c');
      expect(cMoved, const Offset(0, 140));

      list.currentState!.reorder(['c', 'a', 'b']);
      await tester.pump();
      expect(_painted(tester, 'c'), cMoved);
      await tester.pumpAndSettle();
    });

    testWidgets('items mounted below the fold fly on the frame of the '
        'reorder, unseen, and are at rest when scrolled in', (tester) async {
      final column = ScrollController();
      addTearDown(column.dispose);
      final list = GlobalKey<_ListState>();
      final ids = [for (var i = 0; i < 40; i++) '$i'];
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: ids,
            layout: (context, items) => _builder(items, controller: column),
          ),
        ),
      );
      // Show the items further down once, then scroll back. The viewport
      // shows 15 items; the cache extent keeps more mounted below it,
      // without painting them.
      column.jumpTo(160);
      await tester.pump();
      column.jumpTo(0);
      await tester.pump();
      expect(find.byKey(_key('17'), skipOffstage: false), findsOneWidget);

      list.currentState!.reorder(ids.reversed.toList());
      await tester.pumpAndSettle();
      column.jumpTo(400);
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        final finder = find.byKey(_key('$i'));
        if (finder.evaluate().isEmpty) continue;
        expect(_flying(tester, '$i'), isFalse, reason: '$i');
      }
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('an item partly visible at the reorder flies from its first '
        'frame', (tester) async {
      final list = GlobalKey<_ListState>();
      final ids = [for (var i = 0; i < 40; i++) '$i'];
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: ids,
            layout: (context, items) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _builder(items),
            ),
          ),
        ),
      );
      // The viewport is 580 tall, so item 14 is cut off at its middle.
      final before = _layout(tester, '14');
      expect(before, const Offset(0, 580));

      list.currentState!.reorder(
        [...ids]
          ..remove('14')
          ..insert(0, '14'),
      );
      await tester.pump();
      expect(_painted(tester, '14'), before);
      await tester.pump(const Duration(milliseconds: 40));
      final moving = _painted(tester, '14').dy;
      expect(moving, lessThan(before.dy));
      expect(moving, greaterThan(_layout(tester, '14').dy));
      await tester.pumpAndSettle();
    });

    testWidgets('scrolling a board, its column or both never starts a flight', (
      tester,
    ) async {
      final columns = [ScrollController(), ScrollController()];
      final board = ScrollController();
      addTearDown(board.dispose);
      for (final c in columns) {
        addTearDown(c.dispose);
      }
      await tester.pumpWidget(
        _app(
          ListView(
            controller: board,
            scrollDirection: Axis.horizontal,
            children: [
              for (final (c, controller) in columns.indexed)
                SizedBox(
                  width: 500,
                  child: _builder(
                    [for (var i = 0; i < 30; i++) '$c-$i'],
                    controller: controller,
                  ),
                ),
            ],
          ),
        ),
      );

      await tester.drag(find.byKey(_key('0-2')), const Offset(0, -120));
      await tester.pump();
      board.jumpTo(200);
      await tester.pump();
      columns[1].jumpTo(70);
      await tester.pump();
      await tester.drag(find.byKey(_key('1-5')), const Offset(-60, -60));
      await tester.pumpAndSettle();

      for (final id in ['0-4', '0-5', '1-3', '1-6']) {
        expect(_flying(tester, id), isFalse, reason: id);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a reorder in a scrolled board column flies, and scrolling '
        'mid-flight moves the flight with the content', (tester) async {
      final column = ScrollController(initialScrollOffset: 100);
      final board = ScrollController(initialScrollOffset: 50);
      addTearDown(column.dispose);
      addTearDown(board.dispose);
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(
          ListView(
            controller: board,
            scrollDirection: Axis.horizontal,
            children: [
              const SizedBox(width: 300),
              SizedBox(
                width: 300,
                child: _List(
                  key: list,
                  items: [for (var i = 0; i < 20; i++) '$i'],
                  layout: (context, items) =>
                      _builder(items, controller: column),
                ),
              ),
            ],
          ),
        ),
      );
      final before = _layout(tester, '5');

      final items = [for (var i = 0; i < 20; i++) '$i'];
      list.currentState!.reorder(
        [...items]
          ..remove('5')
          ..insert(8, '5'),
      );
      await tester.pump();
      expect(_painted(tester, '5'), before);
      await tester.pump(const Duration(milliseconds: 40));
      final visual = _painted(tester, '5') - _layout(tester, '5');
      expect(visual.dy, lessThan(0));

      // No time passes, so only the scroll moves the item.
      column.jumpTo(130);
      board.jumpTo(80);
      await tester.pump(Duration.zero);
      expect(_painted(tester, '5') - _layout(tester, '5'), visual);
      await tester.pumpAndSettle();
      expect(_flying(tester, '5'), isFalse);
    });

    testWidgets('a reorder in the same frame as a scroll starts from the '
        "item's content position", (tester) async {
      final column = ScrollController();
      addTearDown(column.dispose);
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: [for (var i = 0; i < 20; i++) '$i'],
            layout: (context, items) => _builder(items, controller: column),
          ),
        ),
      );
      final before = _layout(tester, '3');

      column.jumpTo(30);
      list.currentState!.reorder(
        [for (var i = 0; i < 20; i++) '$i']
          ..remove('3')
          ..insert(6, '3'),
      );
      await tester.pump();
      // The content scrolled up by 30, and the item with it.
      expect(_painted(tester, '3'), before - const Offset(0, 30));
      await tester.pumpAndSettle();
    });

    testWidgets('another reorder mid-flight redirects with its velocity', (
      tester,
    ) async {
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(
          _List(key: list, items: const ['a', 'b', 'c', 'd'], layout: _column),
        ),
      );

      list.currentState!.reorder(['b', 'c', 'd', 'a']);
      await tester.pump();
      final samples = <double>[];
      for (var i = 0; i < 20; i++) {
        await tester.pump(fineFrame);
        samples.add(_painted(tester, 'a').dy);
      }
      list.currentState!.reorder(['b', 'a', 'c', 'd']);
      for (var i = 0; i < 5; i++) {
        await tester.pump(fineFrame);
        samples.add(_painted(tester, 'a').dy);
      }
      expectContinuousVelocity(samples, retargetAt: 20);
      await tester.pumpAndSettle();
      expect(_layout(tester, 'a'), const Offset(0, 40));
      expect(_flying(tester, 'a'), isFalse);
    });

    testWidgets('a layout shift mid-flight moves the whole flight', (
      tester,
    ) async {
      final list = GlobalKey<_ListState>();
      late StateSetter growHeader;
      var header = 0.0;
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: const ['a', 'b', 'c'],
            layout: (context, items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatefulBuilder(
                  builder: (context, setState) {
                    growHeader = setState;
                    return SizedBox(height: header);
                  },
                ),
                for (final (i, id) in items.indexed) _item(id, i),
              ],
            ),
          ),
        ),
      );

      list.currentState!.reorder(['c', 'b', 'a']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final visual = _painted(tester, 'a') - _layout(tester, 'a');
      expect(visual.dy, lessThan(0));

      growHeader(() => header = 50);
      await tester.pump(Duration.zero);
      expect(_painted(tester, 'a') - _layout(tester, 'a'), visual);
      await tester.pumpAndSettle();
      expect(_flying(tester, 'a'), isFalse);
    });

    testWidgets('flies on both axes in a grid', (tester) async {
      final list = GlobalKey<_ListState>();
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: const ['a', 'b', 'c', 'd'],
            layout: (context, items) => Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: Wrap(
                  children: [for (final (i, id) in items.indexed) _item(id, i)],
                ),
              ),
            ),
          ),
        ),
      );
      final aBefore = _layout(tester, 'a');
      final dBefore = _layout(tester, 'd');

      list.currentState!.reorder(['d', 'b', 'c', 'a']);
      await tester.pump();
      expect(_painted(tester, 'a'), aBefore);
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _painted(tester, 'a');
      expect(midway.dx, inExclusiveRange(aBefore.dx, dBefore.dx));
      expect(midway.dy, inExclusiveRange(aBefore.dy, dBefore.dy));
      await tester.pumpAndSettle();
      expect(_painted(tester, 'a'), dBefore);
    });

    testWidgets('hit testing stays at the layout position during a flight', (
      tester,
    ) async {
      final taps = <String>[];
      final list = GlobalKey<_ListState>();
      Widget tile(String id, int i) => _item(
        id,
        i,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps.add(id),
          child: SizedBox.fromSize(size: _tile),
        ),
      );
      await tester.pumpWidget(
        _app(
          _List(
            key: list,
            items: const ['a', 'b'],
            layout: (context, items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final (i, id) in items.indexed) tile(id, i)],
            ),
          ),
        ),
      );

      list.currentState!.reorder(['b', 'a']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(_flying(tester, 'a'), isTrue);
      // a is still painted near the top, but b is laid out there.
      await tester.tapAt(const Offset(50, 10));
      expect(taps, ['b']);
      await tester.pumpAndSettle();
    });

    testWidgets('a scope change snaps, and so does turning enabled off '
        'mid-flight', (tester) async {
      var scope = 'x';
      var enabled = true;
      var items = ['a', 'b'];
      late StateSetter set;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Column(
                children: [
                  for (final (i, id) in items.indexed)
                    _item(id, i, scope: scope, enabled: enabled),
                ],
              );
            },
          ),
        ),
      );

      set(() {
        items = ['b', 'a'];
        scope = 'y';
      });
      await tester.pump();
      expect(_flying(tester, 'a'), isFalse);

      set(() => items = ['a', 'b']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(_flying(tester, 'a'), isTrue);
      set(() => enabled = false);
      await tester.pump();
      expect(_flying(tester, 'a'), isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('Motion.instant lands in the frame of the reorder', (
      tester,
    ) async {
      var items = ['a', 'b'];
      late StateSetter set;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Column(
                children: [
                  for (final (i, id) in items.indexed)
                    _item(id, i, motion: const Motion.instant()),
                ],
              );
            },
          ),
        ),
      );

      set(() => items = ['b', 'a']);
      await tester.pump();
      await tester.pump();
      expect(_flying(tester, 'a'), isFalse);
    });

    testWidgets('without a repaint boundary it still flies and settles', (
      tester,
    ) async {
      var items = ['a', 'b'];
      late StateSetter set;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Column(
                children: [
                  for (final (i, id) in items.indexed)
                    _item(id, i, repaintBoundary: false),
                ],
              );
            },
          ),
        ),
      );
      expect(_box(tester, 'a').isRepaintBoundary, isFalse);

      set(() => items = ['b', 'a']);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a GlobalKey move to another column keeps the render object; '
        'it flies from its old spot, or snaps with a scope', (tester) async {
      final keys = {
        for (final id in ['x', 'y', 'z']) id: GlobalObjectKey(id),
      };
      var a = ['x', 'y'];
      var b = ['z'];
      var scoped = false;
      late StateSetter set;
      Widget column(String name, List<String> ids) => SizedBox(
        width: 200,
        child: ListView(
          children: [
            for (final (i, id) in ids.indexed)
              _item(id, i, key: keys[id], scope: scoped ? name : null),
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return ListView(
                scrollDirection: Axis.horizontal,
                children: [column('a', a), column('b', b)],
              );
            },
          ),
        ),
      );
      RenderBox box() => tester.renderObject<RenderBox>(find.byKey(keys['x']!));
      Offset painted() {
        final translation = (box().debugLayer! as TransformLayer).transform!
            .getTranslation();
        return box().localToGlobal(Offset.zero) +
            Offset(translation.x, translation.y);
      }

      final original = box();
      final before = painted();
      set(() {
        a = ['y'];
        b = ['z', 'x'];
      });
      await tester.pump();
      expect(identical(box(), original), isTrue);
      expect(box().localToGlobal(Offset.zero), const Offset(200, 40));
      expect(painted(), before);
      await tester.pumpAndSettle();
      expect(painted(), const Offset(200, 40));

      set(() {
        scoped = true;
        a = ['y'];
        b = ['z', 'x'];
      });
      await tester.pump();
      set(() {
        a = ['x', 'y'];
        b = ['z'];
      });
      await tester.pump();
      expect(painted(), Offset.zero, reason: 'x changed scope, so it snaps');
    });

    testWidgets('a MotionDraggable drop into another column: the landed card '
        'does not fly, its new and old neighbours do', (tester) async {
      final columns = {
        'A': ['a1', 'a2', 'a3'],
        'B': ['b1', 'b2'],
      };
      late StateSetter set;
      Widget column(String name) => SizedBox(
        width: 300,
        child: DragTarget<String>(
          onAcceptWithDetails: (details) => set(() {
            for (final list in columns.values) {
              list.remove(details.data);
            }
            columns[name]!.insert(0, details.data);
          }),
          builder: (context, _, _) {
            final ids = columns[name]!;
            return _builder(
              ids,
              itemBuilder: (id, i) => _item(
                id,
                i,
                scope: name,
                child: MotionDraggable<String>(
                  data: id,
                  child: SizedBox.fromSize(
                    size: _tile,
                    child: const ColoredBox(color: Color(0xFF888888)),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Row(children: [column('A'), column('B')]);
            },
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(50, 20));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(32, 2));
        await tester.pump(frame);
      }
      await gesture.up();
      await tester.pump();
      expect(columns['B'], ['a1', 'b1', 'b2']);
      expect(_flying(tester, 'a1'), isFalse, reason: 'the draggable lands it');
      for (final id in ['a2', 'a3', 'b1', 'b2']) {
        expect(_flying(tester, id), isTrue, reason: id);
      }
      await tester.pumpAndSettle();
      for (final id in ['a1', 'a2', 'b1']) {
        expect(_flying(tester, id), isFalse, reason: id);
      }
    });
  });
}
