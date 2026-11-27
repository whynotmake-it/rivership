import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

class _TestItem {
  _TestItem(this.id, this.height);

  final String id;
  final double height;
}

class _HarnessState {
  _HarnessState({
    required this.items,
    this.pinnedId,
    this.padding = const EdgeInsets.fromLTRB(16, 48, 16, 80),
    this.safePadding = const EdgeInsets.only(top: 20, bottom: 16),
    this.viewInsets = EdgeInsets.zero,
    this.disableAnimations = false,
    this.tailHeight = 0,
  });

  List<_TestItem> items;
  Object? pinnedId;
  EdgeInsets padding;
  EdgeInsets safePadding;
  EdgeInsets viewInsets;
  bool disableAnimations;
  double tailHeight;
}

Future<({TurnScrollController controller, ValueNotifier<_HarnessState> state})>
_pumpView(
  WidgetTester tester,
  _HarnessState initial, {
  Key? viewKey,
  Size viewportSize = const Size(390, 800),
  double itemSpacing = 20,
  double jumpThreshold = 160,
  Motion? autoScrollMotion,
  Object? initialItemId,
  double initialAlignment = 0,
  bool initialAtBottom = true,
  List<Widget> leadingSlivers = const [],
  Widget Function(BuildContext context, _TestItem item)? customItemBuilder,
  Widget? customTailSliver,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.reset);

  final controller = TurnScrollController();
  final state = ValueNotifier<_HarnessState>(initial);
  addTearDown(() {
    controller.dispose();
    state.dispose();
  });

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: ValueListenableBuilder<_HarnessState>(
            valueListenable: state,
            builder: (context, s, _) => MediaQuery(
              data: MediaQueryData(
                size: viewportSize,
                padding: s.safePadding,
                viewInsets: s.viewInsets,
                disableAnimations: s.disableAnimations,
              ),
              child: TurnScrollView(
                key: viewKey,
                controller: controller,
                itemCount: s.items.length,
                itemId: (i) => s.items[i].id,
                pinnedId: s.pinnedId,
                initialItemId: initialItemId,
                initialAlignment: initialAlignment,
                initialAtBottom: initialAtBottom,
                leadingSlivers: leadingSlivers,
                padding: s.padding,
                itemSpacing: itemSpacing,
                jumpThreshold: jumpThreshold,
                autoScrollMotion:
                    autoScrollMotion ?? const CupertinoMotion.smooth(),
                tailSliver:
                    customTailSliver ??
                    (s.tailHeight > 0
                        ? SliverToBoxAdapter(
                            child: SizedBox(
                              key: const ValueKey('tail'),
                              height: s.tailHeight,
                            ),
                          )
                        : null),
                itemBuilder: (context, index) {
                  final item = s.items[index];
                  if (customItemBuilder != null) {
                    return customItemBuilder(context, item);
                  }
                  return SizedBox(
                    key: ValueKey('box:${item.id}'),
                    height: item.height,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(item.id),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (controller: controller, state: state);
}

void _update(
  ValueNotifier<_HarnessState> state,
  void Function(_HarnessState s) mutate,
) {
  final cur = state.value;
  final next = _HarnessState(
    items: List.of(cur.items),
    pinnedId: cur.pinnedId,
    padding: cur.padding,
    safePadding: cur.safePadding,
    viewInsets: cur.viewInsets,
    disableAnimations: cur.disableAnimations,
    tailHeight: cur.tailHeight,
  );
  mutate(next);
  state.value = next;
}

double _itemTopInViewport(WidgetTester tester, String id) {
  final vpTop = tester.getTopLeft(find.byType(TurnScrollView)).dy;
  return tester.getTopLeft(find.byKey(ValueKey('box:$id'))).dy - vpTop;
}

double _itemBottomInViewport(WidgetTester tester, String id) {
  final vpTop = tester.getTopLeft(find.byType(TurnScrollView)).dy;
  return tester.getBottomLeft(find.byKey(ValueKey('box:$id'))).dy - vpTop;
}

Future<void> _pumpFrames(
  WidgetTester tester,
  int count, {
  Duration dt = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(dt);
  }
}

void main() {
  testWidgets(
    'initial load: short thread starts at effectiveTop, long thread opens at '
    'bottom in O(1), and initialItemId opens mid-list in O(1)',
    (tester) async {
      // Short thread: effectiveTop = safe(20) + padding(48) = 68.
      final short = await _pumpView(
        tester,
        _HarnessState(items: [_TestItem('m0', 40), _TestItem('m1', 60)]),
      );
      expect(_itemTopInViewport(tester, 'm0'), closeTo(68, 0.5));
      expect(_itemTopInViewport(tester, 'm1'), closeTo(68 + 40 + 20, 0.5));
      expect(short.controller.isAwayFromBottom.value, isFalse);

      // Long thread (2000 items): opens at bottom without laying out item 0.
      final longItems = [
        for (var i = 0; i < 2000; i++) _TestItem('h$i', 90),
      ];
      final long = await _pumpView(tester, _HarnessState(items: longItems));
      await tester.pump();
      expect(_itemBottomInViewport(tester, 'h1999'), closeTo(704, 1));
      expect(long.controller.isAwayFromBottom.value, isFalse);
      expect(find.byKey(const ValueKey('box:h0')), findsNothing);

      // O(1) open at initialItemId in middle of 2000 items.
      await _pumpView(
        tester,
        _HarnessState(items: longItems),
        viewKey: const ValueKey('mid-open'),
        initialItemId: 'h1234',
      );
      await tester.pumpAndSettle();
      expect(_itemTopInViewport(tester, 'h1234'), closeTo(68, 2));
      expect(find.byKey(const ValueKey('box:h0')), findsNothing);
      expect(find.byKey(const ValueKey('box:h1999')), findsNothing);
    },
  );

  testWidgets(
    'SliverTurnStage pins short and tall prompts, stays invariant during '
    'streaming inside V_pin, and handles follow-up sends without clamping back',
    (tester) async {
      final items = [for (var i = 0; i < 12; i++) _TestItem('h$i', 90)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
      );
      await tester.pumpAndSettle();

      // Short prompt (44 <= 636 / 2) pins to effectiveTop (68).
      _update(state, (s) {
        s.items
          ..add(_TestItem('u1', 44))
          ..add(_TestItem('a1', 30));
        s.pinnedId = 'u1';
      });
      await tester.pumpAndSettle();

      expect(_itemTopInViewport(tester, 'u1'), closeTo(68, 1));
      expect(
        _itemTopInViewport(tester, 'u1') - _itemBottomInViewport(tester, 'h11'),
        closeTo(20, 0.5),
      );
      final pinnedMaxExtent = controller.position.maxScrollExtent;

      // Grow reply inside V_pin: maxScrollExtent stays invariant.
      for (final h in [80.0, 200.0, 400.0]) {
        _update(state, (s) => s.items[s.items.length - 1] = _TestItem('a1', h));
        await tester.pump();
        expect(
          controller.position.maxScrollExtent,
          closeTo(pinnedMaxExtent, 0.01),
        );
        expect(_itemTopInViewport(tester, 'u1'), closeTo(68, 0.5));
      }

      // Tail sliver sits under last message without shifting maxScrollExtent.
      _update(state, (s) => s.tailHeight = 36);
      await tester.pump();
      final vpTop = tester.getTopLeft(find.byType(TurnScrollView)).dy;
      final tailTop =
          tester.getTopLeft(find.byKey(const ValueKey('tail'))).dy - vpTop;
      expect(tailTop, closeTo(_itemBottomInViewport(tester, 'a1'), 0.5));
      expect(
        controller.position.maxScrollExtent,
        closeTo(pinnedMaxExtent, 0.01),
      );

      // Overflow past V_pin grows monotonically while prompt stays anchored.
      _update(state, (s) {
        s.tailHeight = 0;
        s.items[s.items.length - 1] = _TestItem('a1', 900);
      });
      await tester.pump();
      expect(
        controller.position.maxScrollExtent,
        closeTo(pinnedMaxExtent + (44 + 20 + 900 - 636), 1),
      );
      expect(_itemTopInViewport(tester, 'u1'), closeTo(68, 0.5));
      expect(controller.isAwayFromBottom.value, isTrue);

      // Follow-up send after short reply never clamps backward.
      _update(state, (s) {
        s.items[s.items.length - 1] = _TestItem('a1', 60);
      });
      await tester.pumpAndSettle();
      final pixelsAfterTurn1 = controller.position.pixels;

      _update(state, (s) {
        s.items.add(_TestItem('u2', 44));
        s.pinnedId = 'u2';
      });
      await tester.pump();
      expect(
        controller.position.pixels,
        greaterThanOrEqualTo(pixelsAfterTurn1 - 0.5),
      );
      await tester.pumpAndSettle();
      expect(_itemTopInViewport(tester, 'u2'), closeTo(68, 1));

      // Tall prompt (> V_pin / 2 = 318) pins its bottom to 68 + 318 = 386.
      _update(state, (s) {
        s.items.add(_TestItem('tall', 460));
        s.pinnedId = 'tall';
      });
      await tester.pumpAndSettle();
      expect(_itemBottomInViewport(tester, 'tall'), closeTo(386, 1.5));

      // Clearing pinnedId at bottom keeps last item above effectiveBottom.
      _update(state, (s) => s.pinnedId = null);
      await tester.pumpAndSettle();
      expect(_itemBottomInViewport(tester, 'tall'), closeTo(704, 2));
    },
  );

  testWidgets(
    'prepend pagination preserves 0.0px visual shift and widget State across '
    'aboveCount 0 -> >0 and mid-scroll prepends',
    (tester) async {
      final items = [for (var i = 0; i < 5; i++) _TestItem('curr$i', 90)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
        customItemBuilder: (context, item) => _StatefulTestBox(
          key: ValueKey('stateful:${item.id}'),
          id: item.id,
          height: item.height,
        ),
      );
      await tester.pumpAndSettle();

      final stateBefore = tester.state<_StatefulTestBoxState>(
        find.byKey(const ValueKey('stateful:curr2')),
      )..increment();
      await tester.pump();
      final curr2TopBefore = _itemTopInViewport(tester, 'curr2');

      // Prepend 20 older items (transitions aboveCount 0 -> 20).
      _update(state, (s) {
        s.items = [
          for (var i = 0; i < 20; i++) _TestItem('old$i', 80 + (i % 3) * 25),
          ...s.items,
        ];
      });
      await tester.pump();
      await tester.pump();

      expect(
        _itemTopInViewport(tester, 'curr2'),
        closeTo(curr2TopBefore, 0.01),
      );
      final stateAfter = tester.state<_StatefulTestBoxState>(
        find.byKey(const ValueKey('stateful:curr2')),
      );
      expect(stateAfter, same(stateBefore));
      expect(stateAfter.count, 1);

      // Prepend another 20 items while scrolled up.
      await tester.drag(find.byType(TurnScrollView), const Offset(0, 260));
      await tester.pumpAndSettle();
      final curr0TopBefore = _itemTopInViewport(tester, 'curr0');

      _update(state, (s) {
        s.items = [
          for (var i = 0; i < 20; i++) _TestItem('older$i', 95),
          ...s.items,
        ];
      });
      await tester.pump();
      await tester.pump();
      expect(
        _itemTopInViewport(tester, 'curr0'),
        closeTo(curr0TopBefore, 0.01),
      );
    },
  );

  testWidgets(
    'offscreen scrollTo, scrollToBottom convergence, freeze against streaming '
    'tokens, and user scroll cancellation',
    (tester) async {
      final items = [
        for (var i = 0; i < 80; i++) _TestItem('m$i', i.isEven ? 40 : 320),
      ];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
      );
      await tester.pumpAndSettle();

      // Instant jump far up to unmounted m5 returns true.
      final toM5 = controller.scrollTo('m5', animate: false);
      await tester.pumpAndSettle();
      expect(await toM5, isTrue);
      expect(_itemTopInViewport(tester, 'm5'), closeTo(68, 2));
      expect(controller.isAwayFromBottom.value, isTrue);

      // Unknown item returns false immediately.
      expect(await controller.scrollTo('missing'), isFalse);

      // Animated scroll down to m55 aligned to bottom returns true.
      final toM55 = controller.scrollTo('m55', alignment: 1);
      await tester.pumpAndSettle();
      expect(await toM55, isTrue);
      expect(_itemBottomInViewport(tester, 'm55'), closeTo(704, 2));

      // Jump back to m5, then animated scrollToBottom across 75 variable items.
      final backToM5 = controller.scrollTo('m5', animate: false);
      await tester.pumpAndSettle();
      expect(await backToM5, isTrue);

      final jumpFuture = controller.scrollToBottom();
      await tester.pumpAndSettle();
      expect(await jumpFuture, isTrue);
      expect(_itemBottomInViewport(tester, 'm79'), closeTo(704, 1.5));

      // Freeze against new tokens streaming in after scrollToBottom pressed.
      _update(
        state,
        (s) => s.items[s.items.length - 1] = _TestItem('m79', 900),
      );
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent - 350);
      await tester.pump();
      final bottomAtPress = controller.position.maxScrollExtent;

      final streamJump = controller.scrollToBottom();
      await _pumpFrames(tester, 4);
      _update(
        state,
        (s) => s.items[s.items.length - 1] = _TestItem('m79', 1300),
      );
      await tester.pumpAndSettle();
      expect(await streamJump, isTrue);
      expect(controller.position.pixels, closeTo(bottomAtPress, 2));

      // Mouse wheel during streaming cancels active pin (isPinActive -> false)
      // and never jumps back.
      _update(state, (s) {
        s.items
          ..add(_TestItem('u1', 44))
          ..add(_TestItem('a1', 40));
        s.pinnedId = 'u1';
      });
      await _pumpFrames(tester, 4);
      expect(controller.isPinActive.value, isTrue);

      final center = tester.getCenter(find.byType(TurnScrollView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -240)));
      await tester.pump();
      expect(controller.isPinActive.value, isFalse);
      final pixelsAfterWheel = controller.position.pixels;

      for (var i = 1; i <= 5; i++) {
        _update(
          state,
          (s) => s.items[s.items.length - 1] = _TestItem('a1', 40 + i * 100.0),
        );
        await tester.pump(const Duration(milliseconds: 32));
        expect(controller.position.pixels, closeTo(pixelsAfterWheel, 0.5));
      }
    },
  );

  testWidgets(
    'keyboard viewInsets keeps bottom messages above keyboard while leaving '
    'pinned short prompt rock-solid',
    (tester) async {
      final items = [for (var i = 0; i < 15; i++) _TestItem('h$i', 90)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
      );
      await tester.pumpAndSettle();

      expect(_itemBottomInViewport(tester, 'h14'), closeTo(704, 1));

      _update(state, (s) => s.viewInsets = const EdgeInsets.only(bottom: 290));
      await tester.pump();
      expect(_itemBottomInViewport(tester, 'h14'), closeTo(430, 1.5));

      _update(state, (s) => s.viewInsets = EdgeInsets.zero);
      await tester.pump();
      expect(_itemBottomInViewport(tester, 'h14'), closeTo(704, 1.5));

      _update(state, (s) {
        s.items
          ..add(_TestItem('u1', 44))
          ..add(_TestItem('a1', 60));
        s.pinnedId = 'u1';
      });
      await tester.pumpAndSettle();
      expect(_itemTopInViewport(tester, 'u1'), closeTo(68, 1));

      _update(state, (s) => s.viewInsets = const EdgeInsets.only(bottom: 290));
      await tester.pump();
      expect(_itemTopInViewport(tester, 'u1'), closeTo(68, 1));

      _update(state, (s) => s.viewInsets = EdgeInsets.zero);
      await tester.pump();
      expect(_itemTopInViewport(tester, 'u1'), closeTo(68, 1));
    },
  );

  testWidgets(
    'reduced motion and Motion.instant() settle immediately and '
    'cancelAutoScroll halts mid-flight',
    (tester) async {
      final items = [for (var i = 0; i < 40; i++) _TestItem('m$i', 90)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items, disableAnimations: true),
      );
      await tester.pump();

      final toM3 = controller.scrollTo('m3');
      await tester.pumpAndSettle();
      await toM3;
      expect(_itemTopInViewport(tester, 'm3'), closeTo(68, 2));

      // Re-enable animations and test cancelAutoScroll mid-flight.
      _update(state, (s) => s.disableAnimations = false);
      await tester.pump();
      final startPixels = controller.position.pixels;

      final jumpFuture = controller.scrollToBottom();
      await _pumpFrames(tester, 4);
      controller.cancelAutoScroll();
      await tester.pump();
      expect(await jumpFuture, isFalse);

      expect(controller.position.pixels, greaterThan(startPixels));
      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent - 100),
      );
      expect(
        (controller.position as TurnScrollPosition).isTrackingTarget,
        isFalse,
      );
    },
  );

  testWidgets(
    'TurnScrollNotification reports non-negative leadingExtent/trailingExtent '
    'and distinguishes programmatic scrollTo from user drag',
    (tester) async {
      const viewport = Size(390, 800);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = viewport;
      addTearDown(tester.view.reset);

      final items = [for (var i = 0; i < 40; i++) _TestItem('m$i', 90)];
      final controller = TurnScrollController();
      addTearDown(controller.dispose);
      final received = <TurnScrollNotification>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: viewport),
            child: NotificationListener<TurnScrollNotification>(
              onNotification: (n) {
                received.add(n);
                return false;
              },
              child: TurnScrollView(
                controller: controller,
                itemCount: items.length,
                itemId: (i) => items[i].id,
                itemSpacing: 20,
                autoScrollMotion: const CupertinoMotion.smooth(),
                itemBuilder: (context, i) => SizedBox(
                  key: ValueKey('box:${items[i].id}'),
                  height: items[i].height,
                  child: Text(items[i].id),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      received.clear();

      // Programmatic scrollTo emits isProgrammatic == true with non-negative
      // leadingExtent/trailingExtent (even above center with negative pixels).
      final toM5 = controller.scrollTo('m5');
      await tester.pumpAndSettle();
      expect(await toM5, isTrue);
      expect(received, isNotEmpty);
      expect(received.every((n) => n.isProgrammatic), isTrue);
      expect(received.every((n) => n.leadingExtent >= 0), isTrue);
      expect(received.every((n) => n.trailingExtent >= 0), isTrue);
      expect(received.last.trailingExtent, greaterThan(500));

      // User drag emits isProgrammatic == false and updates leadingExtent.
      received.clear();
      await tester.drag(find.byType(TurnScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(received, isNotEmpty);
      expect(received.every((n) => !n.isProgrammatic), isTrue);
      expect(received.last.leadingExtent, greaterThanOrEqualTo(0));
    },
  );

  testWidgets(
    'leadingSlivers prepend freezes visible items to < 0.5px on both first '
    '(hasAbove false -> true) and subsequent prepends',
    (tester) async {
      // Short initial list (6 < 12) with a 120px leading sliver.
      final items = [for (var i = 0; i < 6; i++) _TestItem('curr$i', 140)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
        initialAtBottom: false,
        leadingSlivers: const [
          SliverToBoxAdapter(
            child: SizedBox(key: ValueKey('leading-banner'), height: 120),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Scroll partway down so curr1/curr2 sit comfortably inside the viewport.
      controller.jumpTo(150);
      await tester.pump();
      final curr2TopBefore1 = _itemTopInViewport(tester, 'curr2');

      // Page 1 prepend: flips hasAbove false -> true (Viewport.center switches
      // from _topKey to _belowKey, moving leadingSlivers above center).
      _update(state, (s) {
        s.items = [
          for (var i = 0; i < 10; i++) _TestItem('p1_$i', 90 + (i % 3) * 20),
          ...s.items,
        ];
      });
      await tester.pump();
      await tester.pump();

      expect(
        (_itemTopInViewport(tester, 'curr2') - curr2TopBefore1).abs(),
        lessThan(0.5),
      );

      // Page 2 prepend: hasAbove stays true -> true.
      final curr2TopBefore2 = _itemTopInViewport(tester, 'curr2');
      _update(state, (s) {
        s.items = [
          for (var i = 0; i < 10; i++) _TestItem('p2_$i', 100),
          ...s.items,
        ];
      });
      await tester.pump();
      await tester.pump();

      expect(
        (_itemTopInViewport(tester, 'curr2') - curr2TopBefore2).abs(),
        lessThan(0.5),
      );
    },
  );

  testWidgets(
    'TurnAnchorConfig controls pinned anchor alignment, trailing floor, and '
    'value equality',
    (tester) async {
      // Value equality, hashCode, copyWith (including clearing nullable field),
      // and toString. Use non-const instances so field equality (not just
      // identical()) is exercised.
      final standardCopy = TurnAnchorConfig(
        minTrailingFraction: double.parse('0.5'),
      );
      final topCopy = TurnAnchorConfig(alignment: double.parse('0'));
      expect(TurnAnchorConfig.standard, equals(standardCopy));
      expect(TurnAnchorConfig.standard.hashCode, equals(standardCopy.hashCode));
      expect(TurnAnchorConfig.top, equals(topCopy));
      expect(TurnAnchorConfig.top.hashCode, equals(topCopy.hashCode));
      expect(TurnAnchorConfig.standard, isNot(equals(TurnAnchorConfig.top)));
      expect(
        TurnAnchorConfig.standard.copyWith(alignment: 0.25),
        equals(
          const TurnAnchorConfig(alignment: 0.25, minTrailingFraction: 0.5),
        ),
      );
      expect(
        TurnAnchorConfig.standard.copyWith(minTrailingFraction: null),
        equals(TurnAnchorConfig.top),
      );
      expect(
        const TurnAnchorConfig(alignment: 0.4).toString(),
        contains('alignment: 0.4'),
      );

      const viewport = Size(390, 800);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = viewport;
      addTearDown(tester.view.reset);

      // Usable viewport = 800 - 60 (top) - 140 (bottom) = 600.
      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      Widget buildView({
        required double anchorHeight,
        required TurnAnchorConfig anchorConfig,
      }) {
        final items = [
          for (var i = 0; i < 8; i++) _TestItem('h$i', 90),
          _TestItem('anchor', anchorHeight),
          _TestItem('reply', 40),
        ];
        return Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: viewport),
            child: TurnScrollView(
              controller: controller,
              itemCount: items.length,
              itemId: (i) => items[i].id,
              pinnedId: 'anchor',
              anchorConfig: anchorConfig,
              padding: const EdgeInsets.only(top: 60, bottom: 140),
              itemSpacing: 16,
              autoScrollMotion: const Motion.instant(),
              itemBuilder: (context, i) => SizedBox(
                key: ValueKey('box:${items[i].id}'),
                height: items[i].height,
                child: Text(items[i].id),
              ),
            ),
          ),
        );
      }

      // 1. TurnAnchorConfig.top -> tall anchor (480) pins flush to topClearance
      //    (60) with no trailing floor override.
      await tester.pumpWidget(
        buildView(anchorHeight: 480, anchorConfig: TurnAnchorConfig.top),
      );
      await tester.pumpAndSettle();
      expect(_itemTopInViewport(tester, 'anchor'), closeTo(60, 1.5));

      // 2. TurnAnchorConfig.standard -> tall anchor (480 > 300) scrolls up so
      //    its bottom rests at topClearance + 300 = 360 (leaving 50% below).
      await tester.pumpWidget(
        buildView(anchorHeight: 480, anchorConfig: TurnAnchorConfig.standard),
      );
      await tester.pumpAndSettle();
      await controller.scrollToBottom(animate: false);
      await tester.pumpAndSettle();
      expect(_itemBottomInViewport(tester, 'anchor'), closeTo(360, 1.5));
      expect(_itemTopInViewport(tester, 'anchor'), closeTo(-120, 1.5));

      // 3. Custom TurnAnchorConfig(alignment: 0.25, minTrailingFraction: 0.5):
      //    - Short anchor (100): 100 + 300 = 400 <= 450, rests at
      //      60 + 150 = 210.
      const customWithFloor = TurnAnchorConfig(
        alignment: 0.25,
        minTrailingFraction: 0.5,
      );
      await tester.pumpWidget(
        buildView(anchorHeight: 100, anchorConfig: customWithFloor),
      );
      await tester.pumpAndSettle();
      await controller.scrollToBottom(animate: false);
      await tester.pumpAndSettle();
      expect(_itemTopInViewport(tester, 'anchor'), closeTo(210, 1.5));

      //    - Taller anchor (200): 200 + 300 = 500 > 450, scrolls up so bottom
      //      rests at 60 + 300 = 360 (top at 160), preserving 50% below.
      await tester.pumpWidget(
        buildView(anchorHeight: 200, anchorConfig: customWithFloor),
      );
      await tester.pumpAndSettle();
      await controller.scrollToBottom(animate: false);
      await tester.pumpAndSettle();
      expect(_itemBottomInViewport(tester, 'anchor'), closeTo(360, 1.5));
      expect(_itemTopInViewport(tester, 'anchor'), closeTo(160, 1.5));

      // 4. TurnAnchorConfig(alignment: 0.4) (minTrailingFraction == null):
      //    no surprise trailing-floor override! Anchor (280) rests at
      //    60 + 0.4 * 600 = 300 even though only 80px (< 50%) remains below.
      await tester.pumpWidget(
        buildView(
          anchorHeight: 280,
          anchorConfig: const TurnAnchorConfig(alignment: 0.4),
        ),
      );
      await tester.pumpAndSettle();
      await controller.scrollToBottom(animate: false);
      await tester.pumpAndSettle();
      expect(_itemTopInViewport(tester, 'anchor'), closeTo(300, 1.5));
    },
  );

  testWidgets(
    'per-call motion on scrollTo and scrollToBottom overrides autoScrollMotion '
    'while still respecting reduced motion',
    (tester) async {
      final items = [for (var i = 0; i < 40; i++) _TestItem('m$i', 90)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
        autoScrollMotion: const Motion.linear(Duration(milliseconds: 1000)),
      );
      await tester.pumpAndSettle();

      // Control check: default view autoScrollMotion (1000ms) is still in
      // flight after 160ms.
      bool? slowArrived;
      final slowFuture = controller.scrollTo('m32').then((v) {
        slowArrived = v;
      });
      await _pumpFrames(tester, 10);
      expect(slowArrived, isNull);
      expect(
        (controller.position as TurnScrollPosition).isTrackingTarget,
        isTrue,
      );
      await tester.pumpAndSettle();
      await slowFuture;
      expect(slowArrived, isTrue);

      // Per-call fast motion (100ms) on scrollToBottom settles well within
      // 160ms (faster than the view's 1000ms autoScrollMotion).
      bool? fastJumpArrived;
      final fastJump = controller
          .scrollToBottom(
            motion: const Motion.linear(Duration(milliseconds: 100)),
          )
          .then((v) {
            fastJumpArrived = v;
          });
      await _pumpFrames(tester, 10);
      expect(fastJumpArrived, isTrue);
      await fastJump;
      expect(_itemBottomInViewport(tester, 'm39'), closeTo(704, 2));

      // Per-call Motion.instant() on scrollTo settles immediately (within
      // 2 frames / 16ms elapsed, far faster than the 1000ms default).
      bool? instantArrived;
      final instantToM30 = controller
          .scrollTo('m30', motion: const Motion.instant())
          .then((v) {
            instantArrived = v;
          });
      await _pumpFrames(tester, 2);
      expect(instantArrived, isTrue);
      await instantToM30;
      expect(_itemTopInViewport(tester, 'm30'), closeTo(68, 2));

      // Reduced motion still jumps instantaneously even with a slow per-call
      // motion.
      _update(state, (s) => s.disableAnimations = true);
      await tester.pump();

      bool? reducedScrollArrived;
      final reducedToM5 = controller
          .scrollTo(
            'm5',
            motion: const Motion.linear(Duration(milliseconds: 1000)),
          )
          .then((v) {
            reducedScrollArrived = v;
          });
      await tester.pump();
      await tester.pump();
      expect(reducedScrollArrived, isTrue);
      await reducedToM5;
      expect(_itemTopInViewport(tester, 'm5'), closeTo(68, 2));

      bool? reducedJumpArrived;
      final reducedJump = controller
          .scrollToBottom(
            motion: const Motion.linear(Duration(milliseconds: 1000)),
          )
          .then((v) {
            reducedJumpArrived = v;
          });
      await tester.pump();
      await tester.pump();
      expect(reducedJumpArrived, isTrue);
      await reducedJump;
      expect(_itemBottomInViewport(tester, 'm39'), closeTo(704, 2));
    },
  );

  testWidgets(
    'isAutoScrolling tracks pinnedId, scrollToBottom, scrollTo, and user '
    'interruption while isAwayFromBottom stays truthful',
    (tester) async {
      final items = [for (var i = 0; i < 30; i++) _TestItem('m$i', 90)];
      final (:controller, :state) = await _pumpView(
        tester,
        _HarnessState(items: items),
        autoScrollMotion: const Motion.linear(Duration(milliseconds: 320)),
      );
      await tester.pumpAndSettle();

      expect(controller.isAwayFromBottom.value, isFalse);
      expect(controller.isAutoScrolling.value, isFalse);

      // 1. Activating pinnedId: isAutoScrolling flips true immediately (and
      //    stays true across stage reservation + pin flight), while
      //    isAwayFromBottom truthfully tracks distance > jumpThreshold so
      //    (isAwayFromBottom && !isAutoScrolling) never flashes during a short
      //    turn pin flight.
      var shownDuringPinFlight = false;
      final merged = Listenable.merge([
        controller.isAwayFromBottom,
        controller.isAutoScrolling,
      ]);
      void checkPinOverlay() {
        if (controller.isAwayFromBottom.value &&
            !controller.isAutoScrolling.value) {
          shownDuringPinFlight = true;
        }
      }

      merged.addListener(checkPinOverlay);
      _update(state, (s) {
        s.items
          ..add(_TestItem('u1', 44))
          ..add(_TestItem('a1', 30));
        s.pinnedId = 'u1';
      });
      await tester.pump();
      expect(controller.isAutoScrolling.value, isTrue);
      expect(controller.isAwayFromBottom.value, isTrue);
      expect(controller.distanceFromBottom.value, greaterThan(160));

      await tester.pumpAndSettle();
      merged.removeListener(checkPinOverlay);
      expect(shownDuringPinFlight, isFalse);
      expect(controller.isAutoScrolling.value, isFalse);
      expect(controller.isAwayFromBottom.value, isFalse);

      // Pin flight with an already-overflowing reply keeps isAutoScrolling true
      // mid-flight and flips it false upon arrival while isAwayFromBottom stays
      // true.
      _update(state, (s) {
        s.items
          ..add(_TestItem('u2', 44))
          ..add(_TestItem('a2', 900));
        s.pinnedId = 'u2';
      });
      await tester.pump();
      expect(controller.isAutoScrolling.value, isTrue);
      expect(controller.isAwayFromBottom.value, isTrue);
      await tester.pumpAndSettle();
      expect(controller.isAutoScrolling.value, isFalse);
      expect(controller.isAwayFromBottom.value, isTrue);

      // Clear pin and settle at bottom before testing scrollTo / scrollToBottom.
      _update(state, (s) => s.pinnedId = null);
      await tester.pumpAndSettle();
      final settleBottom = controller.scrollToBottom(animate: false);
      await tester.pumpAndSettle();
      expect(await settleBottom, isTrue);
      expect(controller.isAwayFromBottom.value, isFalse);
      expect(controller.isAutoScrolling.value, isFalse);

      // 2. scrollTo(olderId) from bottom: isAutoScrolling flips true on frame 0
      //    while isAwayFromBottom truthfully flips true once > jumpThreshold
      //    mid-flight; upon arrival isAutoScrolling flips false and
      //    isAwayFromBottom remains true.
      final toOld = controller.scrollTo('m2');
      expect(controller.isAutoScrolling.value, isTrue);
      await _pumpFrames(tester, 8);
      expect(controller.isAutoScrolling.value, isTrue);
      expect(controller.isAwayFromBottom.value, isTrue);
      expect(controller.distanceFromBottom.value, greaterThan(160));
      await tester.pumpAndSettle();
      expect(await toOld, isTrue);
      expect(controller.isAutoScrolling.value, isFalse);
      expect(controller.isAwayFromBottom.value, isTrue);

      // 3. scrollToBottom() from scrolled-up: isAutoScrolling flips true
      //    immediately on frame 0 while isAwayFromBottom remains truthfully
      //    true; interrupting mid-flight with a user drag while still away from
      //    bottom immediately flips isAutoScrolling back to false.
      final toBottomInterrupted = controller.scrollToBottom();
      expect(controller.isAutoScrolling.value, isTrue);
      expect(controller.isAwayFromBottom.value, isTrue);

      await _pumpFrames(tester, 4);
      expect(controller.isAutoScrolling.value, isTrue);
      expect(controller.isAwayFromBottom.value, isTrue);

      await tester.drag(find.byType(TurnScrollView), const Offset(0, 120));
      expect(controller.isAutoScrolling.value, isFalse);
      expect(controller.isAwayFromBottom.value, isTrue);
      await tester.pumpAndSettle();
      expect(await toBottomInterrupted, isFalse);
      expect(controller.isAutoScrolling.value, isFalse);
      expect(controller.isAwayFromBottom.value, isTrue);

      // Uninterrupted scrollToBottom() flips isAutoScrolling true on frame 0
      // and clears both flags upon arrival.
      final toBottomClean = controller.scrollToBottom();
      expect(controller.isAutoScrolling.value, isTrue);
      await tester.pumpAndSettle();
      expect(await toBottomClean, isTrue);
      expect(controller.isAutoScrolling.value, isFalse);
      expect(controller.isAwayFromBottom.value, isFalse);
    },
  );
}

class _StatefulTestBox extends StatefulWidget {
  const _StatefulTestBox({
    required this.id,
    required this.height,
    super.key,
  });

  final String id;
  final double height;

  @override
  State<_StatefulTestBox> createState() => _StatefulTestBoxState();
}

class _StatefulTestBoxState extends State<_StatefulTestBox> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('box:${widget.id}'),
    height: widget.height,
    child: Align(
      alignment: Alignment.topLeft,
      child: Text('${widget.id}:$count'),
    ),
  );
}
