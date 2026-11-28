import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

void main() {
  testWidgets(
    'CustomTurnScrollView follows the bottom again after an animated '
    'scrollToBottom',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = _viewport;
      addTearDown(tester.view.reset);
      final controller = TurnScrollController();
      final count = ValueNotifier(30);
      addTearDown(() {
        controller.dispose();
        count.dispose();
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: _viewport),
            child: ValueListenableBuilder<int>(
              valueListenable: count,
              builder: (context, n, _) => CustomTurnScrollView(
                controller: controller,
                followBottom: true,
                autoScrollMotion: const CupertinoMotion.smooth(),
                slivers: [
                  SliverTurnList(
                    itemCount: n,
                    itemId: (i) => 'm$i',
                    itemBuilder: (context, i) => const SizedBox(height: 150),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double distance() =>
          controller.position.maxScrollExtent - controller.position.pixels;
      expect(distance(), closeTo(0, 1));

      await tester.drag(
        find.byType(CustomTurnScrollView),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      expect(distance(), greaterThan(300));

      unawaited(controller.scrollToBottom());
      await tester.pumpAndSettle();
      expect(distance(), closeTo(0, 1));

      count.value = 31;
      await tester.pump();
      expect(distance(), closeTo(0, 1));
    },
  );
}
