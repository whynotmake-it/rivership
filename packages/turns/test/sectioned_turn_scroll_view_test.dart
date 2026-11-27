import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

class _SectionedItem {
  const _SectionedItem({
    required this.id,
    required this.section,
    required this.height,
  });

  final String id;
  final DateTime section;
  final double height;
}

String _formatDay(DateTime d) => '${d.year}-${d.month}-${d.day}';

void main() {
  testWidgets(
    'TurnScrollView.sectioned renders inline headers outside TurnScrollItem, '
    'opens O(1) mid-section at #3421 with sticky header pinned, pushes up on '
    'section transitions, hides underlying inline header, and works across '
    'the center seam',
    (tester) async {
      const viewport = Size(390, 800);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = viewport;
      addTearDown(tester.view.reset);

      // 5000 items grouped into 500 sections of 10 items each (typed DateTime).
      // Item 3421 is inside section 342 (items 3420..3429).
      final baseDate = DateTime(2025);
      final items = [
        for (var i = 0; i < 5000; i++)
          _SectionedItem(
            id: 'm$i',
            section: baseDate.add(Duration(days: i ~/ 10)),
            height: 80,
          ),
      ];

      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      // effectiveTop = safe(20) + padding(40) = 60.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(
              size: viewport,
              padding: EdgeInsets.only(top: 20, bottom: 16),
            ),
            child: TurnScrollView<DateTime>.sectioned(
              controller: controller,
              itemCount: items.length,
              itemId: (i) => items[i].id,
              sectionId: (i) => items[i].section,
              initialItemId: 'm3421',
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 80),
              itemSpacing: 20,
              sectionHeaderSpacing: 12,
              pinMotion: const Motion.instant(),
              sectionHeaderBuilder: (context, DateTime day) => SizedBox(
                key: ValueKey('hdr:${_formatDay(day)}'),
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_formatDay(day)),
                ),
              ),
              itemBuilder: (context, i) => SizedBox(
                key: ValueKey('box:${items[i].id}'),
                height: items[i].height,
                child: Text(items[i].id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. O(1) virtualization: neither start nor end was built.
      expect(find.byKey(const ValueKey('box:m0')), findsNothing);
      expect(find.byKey(const ValueKey('box:m4999')), findsNothing);

      // 2. Immediately pins section 342 at topClearance (60) even though item
      //    3420 (section 342's start) was above center, and clears m3421 below
      //    the sticky header (60 + 32 + 12 = 104).
      final day342 = _formatDay(baseDate.add(const Duration(days: 342)));
      final day343 = _formatDay(baseDate.add(const Duration(days: 343)));
      final day341 = _formatDay(baseDate.add(const Duration(days: 341)));

      final stickyDay342 = find.byKey(ValueKey('hdr:$day342'));
      expect(stickyDay342, findsAtLeastNWidgets(1));
      final pinnedTop = tester.getTopLeft(stickyDay342.last).dy;
      expect(pinnedTop, closeTo(60, 1));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('box:m3421'))).dy,
        closeTo(104, 1.5),
      );

      // Sticky overlay ignores pointers by default so dragging directly on it
      // scrolls the list smoothly.
      final pixelsBeforeHeaderDrag = controller.position.pixels;
      await tester.dragFrom(
        tester.getCenter(stickyDay342.last),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(controller.position.pixels, greaterThan(pixelsBeforeHeaderDrag));

      // 3. scrollTo section-start item 'm3430' lands cleanly below the sticky
      //    header (60 + 32 + 12 = 104) while hiding its inline header via
      //    Visibility.maintain so floating pills never double-render.
      final to3430 = controller.scrollTo('m3430', animate: false);
      await tester.pumpAndSettle();
      expect(await to3430, isTrue);

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('box:m3430'))).dy,
        closeTo(104, 1.5),
      );
      final hiddenVisibilities = tester
          .widgetList<Visibility>(find.byType(Visibility))
          .where((v) => !v.visible)
          .toList();
      expect(hiddenVisibilities, isNotEmpty);

      // 4. Push-up transition: back up 16px so day343's inline header sits
      //    halfway into the 32px sticky zone (at y = 60 + 16 = 76).
      controller.jumpTo(controller.position.pixels - 16);
      await tester.pump();
      await tester.pump();

      // Now day342 is active and pushed up by -16px (top at 60 - 16 = 44),
      // flush against day343's visible inline header at 76.
      final day342Headers = find.byKey(ValueKey('hdr:$day342'));
      final day343Headers = find.byKey(ValueKey('hdr:$day343'));
      expect(day342Headers, findsAtLeastNWidgets(1));
      expect(day343Headers, findsOneWidget);
      expect(tester.getTopLeft(day343Headers).dy, closeTo(76, 1.5));
      expect(tester.getTopLeft(day342Headers.last).dy, closeTo(44, 1.5));

      // 5. Scroll UP across the center seam (into items < 3421, i.e., above
      //    center in section 341!): sticky header switches seamlessly to
      //    day341 above center!
      final to3415 = controller.scrollTo('m3415', animate: false);
      await tester.pumpAndSettle();
      expect(await to3415, isTrue);

      final day341Headers = find.byKey(ValueKey('hdr:$day341'));
      expect(day341Headers, findsAtLeastNWidgets(1));
      expect(tester.getTopLeft(day341Headers.last).dy, closeTo(60, 1.5));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('box:m3415'))).dy,
        closeTo(104, 1.5),
      );
    },
  );

  testWidgets(
    'TurnScrollView.sectioned hides sticky overlay while leadingSlivers push '
    'section 0 below topClearance, and supports stickySectionHeaders: false',
    (tester) async {
      const viewport = Size(390, 800);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = viewport;
      addTearDown(tester.view.reset);

      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      Widget buildView({required bool sticky}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: TurnScrollView<String>.sectioned(
            controller: controller,
            itemCount: 20,
            itemId: (i) => 'i$i',
            sectionId: (i) => i < 10 ? 'Older' : 'Today',
            stickySectionHeaders: sticky,
            initialAtBottom: false,
            padding: const EdgeInsets.only(top: 20),
            itemSpacing: 16,
            leadingSlivers: const [
              SliverToBoxAdapter(child: SizedBox(height: 150)),
            ],
            sectionHeaderBuilder: (context, section) => SizedBox(
              key: ValueKey('sec:$section'),
              height: 30,
              child: Text(section),
            ),
            itemBuilder: (context, i) => SizedBox(
              key: ValueKey('item:i$i'),
              height: 80,
              child: Text('i$i'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildView(sticky: true));
      await tester.pumpAndSettle();

      // Leading sliver (150px) pushes 'Older' inline header to y = 170.
      // Only the inline header exists — no sticky overlay yet!
      expect(find.byKey(const ValueKey('sec:Older')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('sec:Older'))).dy,
        closeTo(170, 1),
      );

      // Scroll down 200px so 'Older' passes topClearance (20): sticky overlay
      // pins 'Older' at y = 20.
      controller.jumpTo(200);
      await tester.pump();
      await tester.pump();
      final olderHeaders = find.byKey(const ValueKey('sec:Older'));
      expect(tester.getTopLeft(olderHeaders.last).dy, closeTo(20, 1));

      // Disable sticky headers: no sticky overlay rendered.
      await tester.pumpWidget(buildView(sticky: false));
      await tester.pumpAndSettle();
      expect(find.byType(Visibility), findsNothing);
    },
  );
}
