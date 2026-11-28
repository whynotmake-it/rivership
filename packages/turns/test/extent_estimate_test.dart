import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

void main() {
  testWidgets(
    'items measured earlier keep their real height in the estimate of what '
    'is below after scrolling away',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = _viewport;
      addTearDown(tester.view.reset);
      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      // A history of short prompts, then a long stretch of tall replies near
      // the end. The mean of what gets measured can't describe both.
      const count = 200;
      const spacing = 12.0;
      const bottomPadding = 20.0;
      final heights = [
        for (var i = 0; i < count; i++)
          if (i < 100) 40.0 else 400.0 + i % 7 * 40,
      ];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: _viewport),
            child: TurnScrollView(
              controller: controller,
              itemCount: count,
              itemId: (i) => 'm$i',
              itemSpacing: spacing,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, bottomPadding),
              autoScrollMotion: const Motion.instant(),
              itemBuilder: (context, i) =>
                  SizedBox(key: ValueKey('box:m$i'), height: heights[i]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Walk back up through the tall replies, then peek at the very top.
      for (var i = count - 4; i >= 100; i -= 2) {
        unawaited(controller.scrollTo('m$i', animate: false));
        await tester.pumpAndSettle();
      }
      unawaited(controller.scrollTo('m0', animate: false));
      await tester.pumpAndSettle();

      // Sit in the tall stretch, with most of it below, unbuilt.
      unawaited(controller.scrollTo('m110', animate: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('box:m199')), findsNothing);

      final top =
          tester.getTopLeft(find.byKey(const ValueKey('box:m110'))).dy -
          tester.getTopLeft(find.byType(TurnScrollView)).dy;
      var below = bottomPadding;
      for (var i = 110; i < count; i++) {
        below += heights[i] + (i < count - 1 ? spacing : 0);
      }
      // What is left to scroll: everything from m110's top down, minus what
      // already fits in the viewport below that top.
      final actual = below - (_viewport.height - top);
      final estimated =
          controller.position.maxScrollExtent - controller.position.pixels;
      expect(
        (estimated - actual).abs() / actual,
        lessThan(0.02),
        reason: 'estimated $estimated left to scroll, actual $actual',
      );
    },
  );
}
