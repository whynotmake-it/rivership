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
            scale.to(2, motion: const Motion.linear(Duration.zero)),
            size.to(
              const Size(10, 20),
              motion: const Motion.linear(Duration.zero),
            ),
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

    test('wraps a reader function', () {
      final reader =
          TrackValueReader(<T extends Object>(track) => track.initial!);
      double? nullable;
      nullable = reader(scale);
      expect(nullable, 2);
      expect(reader<Size>(size), const Size(10, 20));
    });
  });
}
