// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets('a sliced curve settles on its target', (tester) async {
    final controller = MotionController<double>(
      motion: const Motion.linear(Duration(seconds: 1)).sliced(to: 0.5),
      vsync: tester,
      converter: MotionConverter.single,
      initialValue: 0,
    );
    addTearDown(controller.dispose);
    controller.animateTo(1000);
    // 60 fps frames; in 1.x the frame at 0.5 s showed exactly 1000.
    await tester.pumpAndSettle(const Duration(microseconds: 16667));
    expect(controller.isAnimating, isFalse);
    // Actual: 998.0. _TrimmedSimulation.settlesAt/isDone are a
    // tolerance.time (1 ms) before the end, and playback samples there.
    expect(controller.value, 1000);
  });
}
