import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

void main() {
  testWidgets(
    'the space reserved for a pinned turn follows the anchor even when the '
    'list keeps the same total height',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = _viewport;
      addTearDown(tester.view.reset);
      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      Widget view(List<double> heights) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: _viewport),
          child: TurnScrollView(
            controller: controller,
            itemCount: heights.length,
            itemId: (i) => 'm$i',
            pinnedId: 'm2',
            autoScrollMotion: const Motion.instant(),
            itemBuilder: (context, i) => SizedBox(height: heights[i]),
          ),
        ),
      );

      // A short thread: the pinned prompt (m2) and a short reply (m3) leave
      // most of the viewport reserved.
      await tester.pumpWidget(view([100, 100, 44, 30]));
      await tester.pumpAndSettle();
      final before = controller.position.maxScrollExtent;

      // An item above the prompt grows while the reply shrinks by the same
      // amount: the list is exactly as tall as before, but the prompt moved
      // down, so less of the stage is left to reserve.
      await tester.pumpWidget(view([100, 130, 44, 0.5]));
      await tester.pumpAndSettle();
      expect(
        controller.position.maxScrollExtent,
        greaterThan(before + 20),
        reason: 'reserve was not recomputed after the anchor moved',
      );
    },
  );
}
