// ignore_for_file: unawaited_futures
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets(
      'retargeting a Color keeps its velocity like the same move on a double',
      (tester) async {
    const motion = CupertinoMotion.smooth();
    final color = MotionController<Color>(
      motion: motion,
      vsync: tester,
      converter: MotionConverter.colorRgb,
      initialValue: const Color(0xFFFFFFFF),
    );
    final single = MotionController<double>(
      motion: motion,
      vsync: tester,
      converter: MotionConverter.single,
      initialValue: 1,
    );
    addTearDown(color.dispose);
    addTearDown(single.dispose);

    color.animateTo(const Color(0xFF000000));
    single.animateTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(color.value.r, closeTo(single.value, 1e-9));

    // Retarget mid-flight; both should keep moving down with their velocity.
    color.animateTo(const Color(0xFF808080));
    single.animateTo(const Color(0xFF808080).r);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final shown = color.value.r;
    final expected = single.value;
    color.stop(canceled: true);
    single.stop(canceled: true);
    // Actual: the Color restarts from rest, because its (negative) velocity
    // went through ColorRgbMotionConverter.denormalize, which clamps to 0..1.
    expect(shown, closeTo(expected, 1e-6));
  });
}
