// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets('Motion.instant lands on its target after one frame',
      (tester) async {
    final controller = MotionController<double>(
      motion: const Motion.instant(),
      vsync: tester,
      converter: MotionConverter.single,
      initialValue: 0,
    );
    addTearDown(controller.dispose);

    var completed = false;
    controller.animateTo(10).then((_) => completed = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.value, 10);
    expect(controller.isAnimating, isFalse);
    expect(completed, isTrue);
  });
}
