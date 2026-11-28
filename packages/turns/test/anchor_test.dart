import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

class _Scene {
  _Scene({
    required this.heights,
    this.pinnedId,
    this.keyboard = 0,
    this.followBottom = false,
  });

  /// Heights by item id (`m0`, `m1`, ...), oldest first.
  List<double> heights;
  Object? pinnedId;
  double keyboard;
  bool followBottom;

  _Scene copy() => _Scene(
    heights: List.of(heights),
    pinnedId: pinnedId,
    keyboard: keyboard,
    followBottom: followBottom,
  );
}

class _Harness {
  _Harness(this.tester, this.controller, this._scene);

  final WidgetTester tester;
  final TurnScrollController controller;
  final ValueNotifier<_Scene> _scene;

  _Scene get scene => _scene.value;

  void update(void Function(_Scene s) mutate) {
    final next = scene.copy();
    mutate(next);
    _scene.value = next;
  }

  double get distanceFromBottom =>
      controller.position.maxScrollExtent - controller.position.pixels;

  double top(String id) =>
      tester.getTopLeft(find.byKey(ValueKey('box:$id'))).dy -
      tester.getTopLeft(find.byType(TurnScrollView)).dy;
}

Future<_Harness> _pump(
  WidgetTester tester,
  _Scene initial, {
  Motion motion = const Motion.instant(),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _viewport;
  addTearDown(tester.view.reset);
  final controller = TurnScrollController();
  final scene = ValueNotifier(initial);
  addTearDown(() {
    controller.dispose();
    scene.dispose();
  });
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<_Scene>(
        valueListenable: scene,
        builder: (context, s, _) => MediaQuery(
          data: MediaQueryData(
            size: _viewport,
            viewInsets: EdgeInsets.only(bottom: s.keyboard),
          ),
          child: TurnScrollView(
            controller: controller,
            itemCount: s.heights.length,
            itemId: (i) => 'm$i',
            pinnedId: s.pinnedId,
            followBottom: s.followBottom,
            autoScrollMotion: motion,
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
            itemSpacing: 12,
            itemBuilder: (context, i) => SizedBox(
              key: ValueKey('box:m$i'),
              height: s.heights[i],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(tester, controller, scene);
}

Future<void> _userDrag(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(TurnScrollView), Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'followBottom keeps the bottom in view as content grows or shrinks until '
    'the user scrolls away, and re-arms when they come back',
    (tester) async {
      final h = await _pump(
        tester,
        _Scene(heights: List.filled(30, 80), followBottom: true),
      );
      expect(h.distanceFromBottom, closeTo(0, 1));

      // A new item, an embed growing, then shrinking: always at the bottom.
      h.update((s) => s.heights.add(120));
      await tester.pump();
      expect(h.distanceFromBottom, closeTo(0, 1));
      h.update((s) => s.heights[s.heights.length - 1] = 400);
      await tester.pump();
      expect(h.distanceFromBottom, closeTo(0, 1));
      h.update((s) => s.heights[s.heights.length - 1] = 40);
      await tester.pump();
      expect(h.distanceFromBottom, closeTo(0, 1));

      // The user scrolls up to read: new content must not drag them down.
      await _userDrag(tester, 300);
      final reading = h.controller.position.pixels;
      expect(h.distanceFromBottom, greaterThan(100));
      h.update((s) => s.heights.add(200));
      await tester.pumpAndSettle();
      expect(h.controller.position.pixels, closeTo(reading, 1));

      // Back at the bottom by hand: following again.
      await _userDrag(tester, -2000);
      expect(h.distanceFromBottom, closeTo(0, 1));
      h.update((s) => s.heights.add(150));
      await tester.pump();
      expect(h.distanceFromBottom, closeTo(0, 1));
    },
  );

  testWidgets(
    'without followBottom, growth at the bottom leaves the offset alone',
    (tester) async {
      final h = await _pump(tester, _Scene(heights: List.filled(30, 80)));
      final before = h.controller.position.pixels;
      h.update((s) => s.heights.add(300));
      await tester.pumpAndSettle();
      expect(h.controller.position.pixels, closeTo(before, 1));
      expect(h.distanceFromBottom, greaterThan(100));
    },
  );

  testWidgets(
    'closing the keyboard at the bottom of a pinned turn does not move the '
    'viewport, even after the user dragged and released the pin',
    (tester) async {
      final h = await _pump(
        tester,
        _Scene(
          heights: [...List.filled(8, 90), 44, 30],
          pinnedId: 'm8',
          keyboard: 300,
        ),
      );
      final prompt = h.top('m8');
      await _userDrag(tester, -20);
      expect(h.controller.isPinActive.value, isFalse);
      expect(h.distanceFromBottom, closeTo(0, 1));
      final before = h.top('m8');
      expect(before, closeTo(prompt, 1));

      for (final inset in [220.0, 140.0, 60.0, 0.0]) {
        h.update((s) => s.keyboard = inset);
        await tester.pump(const Duration(milliseconds: 16));
        expect(h.top('m8'), closeTo(before, 1), reason: 'inset $inset');
      }
      await tester.pumpAndSettle();
      expect(h.top('m8'), closeTo(before, 1));
      expect(h.distanceFromBottom, closeTo(0, 1));
    },
  );

  testWidgets(
    'a pinned prompt holds its place when an earlier item grows after the '
    'pin flight settled',
    (tester) async {
      final h = await _pump(
        tester,
        _Scene(heights: [80, 80, 44, 30], pinnedId: 'm2'),
      );
      final settled = h.top('m2');
      h.update((s) => s.heights[0] = 260);
      await tester.pumpAndSettle();
      expect(h.top('m2'), closeTo(settled, 1));
      expect(h.controller.isPinActive.value, isTrue);
    },
  );

  testWidgets(
    'scrollToBottom lands above a keyboard that is still opening',
    (tester) async {
      final h = await _pump(
        tester,
        _Scene(heights: List.filled(40, 80)),
        motion: const CupertinoMotion.smooth(),
      );
      await tester.drag(find.byType(TurnScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(h.distanceFromBottom, greaterThan(400));

      final flight = h.controller.scrollToBottom();
      unawaited(flight);
      // The keyboard slides in over the next frames while the flight runs.
      for (var i = 1; i <= 12; i++) {
        h.update((s) => s.keyboard = 300.0 * i / 12);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(h.distanceFromBottom, closeTo(0, 1));
      // The last item rests above the keyboard.
      final lastBottom = h.top('m39') + 80;
      expect(lastBottom, lessThanOrEqualTo(_viewport.height - 300 + 1));
    },
  );

  testWidgets(
    'a message sent while the keyboard closes flies to the bottom without '
    'leaving a gap above the composer, and a reply mid-flight still lands',
    (tester) async {
      final h = await _pump(
        tester,
        _Scene(heights: List.filled(40, 80), keyboard: 300),
        motion: const CupertinoMotion.smooth(),
      );
      expect(h.distanceFromBottom, closeTo(0, 1));

      void scrollToBottomNextFrame() =>
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => unawaited(h.controller.scrollToBottom()),
          );

      // Send: the message is appended, the app scrolls to it and the keyboard
      // starts to close, all at once.
      h.update((s) => s.heights.add(80));
      scrollToBottomNextFrame();
      for (var frame = 1; frame <= 30; frame++) {
        h.update((s) => s.keyboard = (300.0 - frame * 30).clamp(0, 300));
        if (frame == 5) {
          // A reply arrives while the flight and the keyboard are moving.
          final following = !h.controller.isAwayFromBottom.value;
          h.update((s) => s.heights.add(80));
          if (following) scrollToBottomNextFrame();
        }
        await tester.pump(const Duration(milliseconds: 16));
        // Never scrolled past the bottom: no blank gap under the last message.
        expect(h.distanceFromBottom, greaterThan(-1), reason: 'frame $frame');
      }
      await tester.pumpAndSettle();
      expect(h.distanceFromBottom, closeTo(0, 1));
      // The reply is on screen, above the bottom edge.
      expect(h.top('m41') + 80, lessThanOrEqualTo(_viewport.height + 1));
    },
  );

  testWidgets(
    'an app jumpTo while followBottom is armed stays where the app put it',
    (tester) async {
      final h = await _pump(
        tester,
        _Scene(heights: List.filled(30, 150), followBottom: true),
      );
      expect(h.distanceFromBottom, closeTo(0, 1));

      h.controller.jumpTo(h.controller.position.pixels - 700);
      await tester.pump();
      final before = h.top('m24');
      final pixels = h.controller.position.pixels;

      h.update((s) => s.heights.add(150));
      await tester.pumpAndSettle();
      expect(h.controller.position.pixels, closeTo(pixels, 1));
      expect(h.top('m24'), closeTo(before, 1));
      expect(h.distanceFromBottom, greaterThan(100));

      // Jumping back to the bottom by hand follows again.
      h.controller.jumpTo(h.controller.position.maxScrollExtent);
      await tester.pump();
      h.update((s) => s.heights.add(150));
      await tester.pump();
      expect(h.distanceFromBottom, closeTo(0, 1));
    },
  );
}
