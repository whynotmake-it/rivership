// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// Rounds on the way in, like a value that snaps to whole numbers when it is
/// converted, but presents the exact number.
class _SnappingConverter extends MotionConverter<double> {
  const _SnappingConverter();

  @override
  List<MotionDimension> get dimensions => const [MotionDimension.linear()];

  @override
  List<double> normalize(double value) => [value.roundToDouble()];

  @override
  double denormalize(List<double> values) => values[0];
}

void main() {
  testWidgets('a graceful stop settles at exactly the value it stopped at',
      (tester) async {
    final controller = MotionController<double>(
      vsync: tester,
      motion: const CupertinoMotion.bouncy(),
      converter: const _SnappingConverter(),
      initialValue: 0,
    );
    addTearDown(controller.dispose);
    controller.animateTo(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final stoppedAt = controller.value;
    expect(stoppedAt, isNot(stoppedAt.roundToDouble()));
    controller.stop();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(controller.isAnimating, isFalse);
    expect(controller.value, closeTo(stoppedAt, 1e-6));
  });
}
