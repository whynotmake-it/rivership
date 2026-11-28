import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

/// Counts how often the state of each item is created, so a test can tell a
/// remount from a rebuild.
final _mounts = <String, int>{};

class _Probe extends StatefulWidget {
  const _Probe(this.id);

  final String id;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _mounts.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('box:${widget.id}'),
    height: 60,
    child: Text(widget.id),
  );
}

const _viewport = Size(390, 800);

Future<void> _pump(WidgetTester tester, Widget view) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _viewport;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: _viewport),
        child: view,
      ),
    ),
  );
}

void main() {
  setUp(_mounts.clear);

  testWidgets(
    'item state survives a sectioned prepend, a mid-list insert and a pin '
    'being set and cleared',
    (tester) async {
      Widget view(
        List<String> ids, {
        Object? pinnedId,
        int perSection = 5,
      }) => TurnScrollView<int>.sectioned(
        itemCount: ids.length,
        itemId: (i) => ids[i],
        sectionId: (i) => int.parse(ids[i].substring(1)) ~/ perSection,
        sectionHeaderBuilder: (context, section, isPinned) =>
            SizedBox(height: 24, child: Text('day $section')),
        pinnedId: pinnedId,
        autoScrollMotion: const Motion.instant(),
        itemBuilder: (context, i) => _Probe(ids[i]),
      );

      // Items 10..24, section starts at 10, 15, 20.
      final ids = [for (var i = 10; i < 25; i++) 'm$i'];
      await _pump(tester, view(ids));
      await tester.pumpAndSettle();
      expect(_mounts['m22'], 1);

      // Prepending older items of the same section makes m10 stop being a
      // section start. It must keep its state.
      final withOlder = [for (var i = 8; i < 25; i++) 'm$i'];
      await _pump(tester, view(withOlder));
      await tester.pumpAndSettle();
      expect(_mounts['m10'], 1, reason: 'prepend must not remount m10');
      expect(_mounts['m20'], 1);

      // Inserting in the middle must not remount the items after it.
      final inserted = [...withOlder]..insert(withOlder.indexOf('m18'), 'x18');
      await _pump(tester, view(inserted));
      await tester.pumpAndSettle();
      expect(_mounts['m22'], 1, reason: 'mid-list insert remounted m22');
      expect(_mounts['m24'], 1);

      // Pinning and unpinning must not rebuild the prompt or the reply.
      await _pump(tester, view(inserted, pinnedId: 'm22'));
      await tester.pumpAndSettle();
      await _pump(tester, view(inserted));
      await tester.pumpAndSettle();
      expect(_mounts['m22'], 1, reason: 'pin/unpin remounted the prompt');
      expect(_mounts['m23'], 1, reason: 'pin/unpin remounted the reply');
    },
  );

  testWidgets('toggling stickySectionHeaders keeps the scroll offset', (
    tester,
  ) async {
    final controller = TurnScrollController();
    addTearDown(controller.dispose);
    Widget view({required bool sticky}) => TurnScrollView<int>.sectioned(
      controller: controller,
      itemCount: 200,
      itemId: (i) => 'm$i',
      sectionId: (i) => i ~/ 10,
      stickySectionHeaders: sticky,
      sectionHeaderBuilder: (context, section, isPinned) =>
          SizedBox(height: 24, child: Text('day $section')),
      autoScrollMotion: const Motion.instant(),
      itemBuilder: (context, i) => _Probe('m$i'),
    );

    await _pump(tester, view(sticky: true));
    await tester.pumpAndSettle();
    unawaited(controller.scrollTo('m120', animate: false));
    await tester.pumpAndSettle();
    final before = controller.position.pixels;
    final mountsBefore = _mounts['m120'];

    await _pump(tester, view(sticky: false));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, closeTo(before, 1));
    expect(_mounts['m120'], mountsBefore);

    await _pump(tester, view(sticky: true));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, closeTo(before, 1));
  });
}
