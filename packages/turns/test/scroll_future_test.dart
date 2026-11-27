import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

void main() {
  Future<TurnScrollController> pump(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final controller = TurnScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: TurnScrollView<Object>(
            controller: controller,
            itemCount: 60,
            itemId: (i) => i,
            // A spring that keeps settling well after its duration.
            autoScrollMotion: const Motion.cupertino(
              duration: Duration(milliseconds: 400),
              bounce: 0.3,
            ),
            itemBuilder: (context, i) =>
                SizedBox(height: 60, child: Text('$i')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a flight ends when it looks done, before it settles, and '
      'reports interruptions', (tester) async {
    final controller = await pump(tester);

    var endedAt = -1;
    var settledAt = -1;
    var frame = 0;
    final flight = controller.scrollTo(40);
    unawaited(flight.ended.then((v) => endedAt = v ? frame : -2));
    unawaited(flight.then((v) => settledAt = v ? frame : -2));
    while (settledAt == -1 && frame < 300) {
      await tester.pump(const Duration(milliseconds: 16));
      frame++;
    }
    expect(endedAt, greaterThan(0));
    expect(settledAt, greaterThan(endedAt));

    // A drag during the flight interrupts both.
    final interrupted = controller.scrollToBottom();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.drag(find.byType(TurnScrollView<Object>), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(await interrupted.ended, isFalse);
    expect(await interrupted, isFalse);

    // A jump ends when it lands.
    final jump = controller.scrollTo(5, animate: false);
    await tester.pumpAndSettle();
    expect(await jump.ended, isTrue);
  });
}
