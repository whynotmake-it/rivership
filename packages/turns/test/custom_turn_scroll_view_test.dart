import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate(this.label, {required this.height});

  final String label;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(
    key: ValueKey('header:$label'),
    height: height,
    child: Align(alignment: Alignment.centerLeft, child: Text(label)),
  );

  @override
  bool shouldRebuild(_HeaderDelegate oldDelegate) =>
      label != oldDelegate.label || height != oldDelegate.height;
}

void main() {
  testWidgets(
    'CustomTurnScrollView composes SliverPersistentHeader app bar, multiple '
    'SliverMainAxisGroup sections with SliverTurnList, offscreen scrollTo '
    'across sections, exact jumpToBottom, and SliverTurnStage pinning',
    (tester) async {
      const viewport = Size(390, 800);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = viewport;
      addTearDown(tester.view.reset);

      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      final pinned = ValueNotifier<Object?>(null);
      addTearDown(pinned.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(
              size: viewport,
              padding: EdgeInsets.only(top: 20, bottom: 16),
            ),
            child: ValueListenableBuilder<Object?>(
              valueListenable: pinned,
              builder: (context, pin, _) => CustomTurnScrollView(
                controller: controller,
                pinnedId: pin,
                initialAtBottom: false,
                applyTopPadding: false,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 80),
                pinMotion: const CupertinoMotion.smooth(),
                slivers: [
                  // Pinned app-bar-like header sliver (height 68).
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HeaderDelegate('AppBar', height: 68),
                  ),
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _HeaderDelegate('Archive', height: 40),
                      ),
                      SliverTurnList(
                        itemCount: 30,
                        itemId: (i) => 'a$i',
                        itemSpacing: 12,
                        itemBuilder: (context, i) => SizedBox(
                          key: ValueKey('box:a$i'),
                          height: 90,
                          child: Text('a$i'),
                        ),
                      ),
                    ],
                  ),
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _HeaderDelegate('Yesterday', height: 40),
                      ),
                      SliverTurnList(
                        itemCount: 30,
                        itemId: (i) => 'y$i',
                        itemSpacing: 12,
                        itemBuilder: (context, i) => SizedBox(
                          key: ValueKey('box:y$i'),
                          height: 110,
                          child: Text('y$i'),
                        ),
                      ),
                    ],
                  ),
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _HeaderDelegate('Today', height: 40),
                      ),
                      SliverTurnList(
                        itemCount: 30,
                        itemId: (i) => 't$i',
                        itemSpacing: 12,
                        itemBuilder: (context, i) => SizedBox(
                          key: ValueKey('box:t$i'),
                          height: 100,
                          child: Text('t$i'),
                        ),
                      ),
                    ],
                  ),
                  if (pin != null)
                    SliverTurnStage(
                      anchorSliver: const SliverToBoxAdapter(
                        child: TurnScrollItem(
                          id: 'u_new',
                          child: SizedBox(
                            key: ValueKey('box:u_new'),
                            height: 44,
                            child: Text('u_new'),
                          ),
                        ),
                      ),
                      afterSliver: const SliverToBoxAdapter(
                        child: TurnScrollItem(
                          id: 'a_new',
                          child: SizedBox(
                            key: ValueKey('box:a_new'),
                            height: 60,
                            child: Text('a_new'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially at top: Today section is completely offscreen/unmounted.
      expect(find.byKey(const ValueKey('box:a0')), findsOneWidget);
      expect(find.byKey(const ValueKey('box:t20')), findsNothing);

      // Unknown item returns false immediately.
      expect(await controller.scrollTo('missing'), isFalse);

      // Offscreen animated scrollTo across 3 SliverMainAxisGroups to 't20'.
      // Lands below pinned AppBar (68) + pinned Today header (40) = 108.
      final toT20 = controller.scrollTo('t20');
      await tester.pumpAndSettle();
      expect(await toT20, isTrue);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('box:t20'))).dy,
        closeTo(108, 2),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('header:AppBar'))).dy,
        closeTo(0, 1),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('header:Today'))).dy,
        closeTo(68, 1),
      );

      // Offscreen instant scrollTo back up to 'a5' in section 1.
      // Lands cleanly below pinned AppBar (68) + pinned Archive header (40).
      final toA5 = controller.scrollTo('a5', animate: false);
      await tester.pumpAndSettle();
      expect(await toA5, isTrue);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('box:a5'))).dy,
        closeTo(108, 2),
      );

      // Interrupted scrollTo returns false.
      final interrupted = controller.scrollTo('t25');
      await tester.pump(const Duration(milliseconds: 32));
      controller.cancelAutoScroll();
      await tester.pump();
      expect(await interrupted, isFalse);

      // Exact jumpToBottom across all 3 SliverTurnLists lands at bottom of t29
      // (800 - (16 safe + 80 padding) = 704).
      final toBottom = controller.jumpToBottom();
      await tester.pumpAndSettle();
      expect(await toBottom, isTrue);
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('box:t29'))).dy,
        closeTo(704, 2),
      );

      // Activate SliverTurnStage pin: u_new pins cleanly to effectiveTop (68)
      // and controller.isPinActive flips true.
      pinned.value = 'u_new';
      await tester.pumpAndSettle();
      expect(controller.isPinActive.value, isTrue);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('box:u_new'))).dy,
        closeTo(68, 2),
      );
    },
  );
}
