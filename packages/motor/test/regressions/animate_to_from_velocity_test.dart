// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets('animateTo(from:) keeps the current velocity, as documented',
      (tester) async {
    final controller = MotionController<double>(
      motion: const CupertinoMotion.smooth(),
      vsync: tester,
      converter: MotionConverter.single,
      initialValue: 0,
    );
    addTearDown(controller.dispose);
    controller.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = controller.velocity;
    expect(before, greaterThan(1));

    // "Animates towards target, while ensuring that any current velocity is
    // maintained. If from is provided, the animation will start from there"
    // -- 1.x used `velocity ?? velocities` here, whatever `from` was.
    controller.animateTo(1, from: 0.5);
    // Actual: 0. _playAnimation's slot.setValue(from) zeroes the velocity
    // before slot.play reads it.
    expect(controller.velocity, closeTo(before, 1e-9));
    controller.stop(canceled: true);
  });
}
