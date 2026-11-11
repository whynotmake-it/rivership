import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  final scale = Track<double>(MotionConverter.single, initial: 2);
  final size = Track<Size>(MotionConverter.size, initial: const Size(10, 20));

  group('TrackValueReader', () {
    testWidgets('infers the track type for nullable parameters',
        (tester) async {
      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            scale(
              [const TrackStep.to(2, motion: Motion.linear(Duration.zero))],
            ),
            size([
              const TrackStep.to(
                Size(10, 20),
                motion: Motion.linear(Duration.zero),
              ),
            ]),
          ],
          builder: (context, value, child) => Transform.scale(
            scale: value(scale),
            child: SizedBox.fromSize(size: value(size)),
          ),
        ),
      );

      expect(
        tester
            .widget<Transform>(find.byType(Transform))
            .transform
            .getMaxScaleOnAxis(),
        2,
      );
      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(Size(box.width!, box.height!), const Size(10, 20));
    });
  });
}
