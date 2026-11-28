import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turns/scroll.dart';

/// Where a scrollbar thumb's top edge sits, as a fraction of the track.
double _thumbTop(ScrollPosition p) =>
    (p.pixels - p.minScrollExtent) /
    (p.maxScrollExtent - p.minScrollExtent + p.viewportDimension);

void main() {
  testWidgets('scrolling steadily up through history never moves the '
      'scrollbar thumb down', (tester) async {
    const size = Size(400, 800);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final controller = TurnScrollController();
    addTearDown(controller.dispose);

    // Rows of very different heights, as in a real chat, under sticky day
    // headers: the extent of everything not yet built has to be estimated.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: size),
          child: TurnScrollView<int>.sectioned(
            controller: controller,
            itemCount: 600,
            itemId: (i) => i,
            sectionId: (i) => i ~/ 25,
            sectionHeaderBuilder: (context, details) =>
                SizedBox(height: 28, child: Text('Day ${details.section}')),
            itemBuilder: (context, i) =>
                SizedBox(height: 40.0 + (i * 7919 % 5) * 30),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position = controller.position;
    var thumb = _thumbTop(position);
    var steps = 0;
    while (position.pixels > position.minScrollExtent && steps++ < 2000) {
      position.jumpTo(
        (position.pixels - 90).clamp(position.minScrollExtent, 0),
      );
      await tester.pump();
      final next = _thumbTop(position);
      expect(
        next,
        lessThanOrEqualTo(thumb + 0.001),
        reason: 'thumb moved down at step $steps while scrolling up',
      );
      thumb = next;
    }
    expect(position.pixels, position.minScrollExtent);
  });
}
