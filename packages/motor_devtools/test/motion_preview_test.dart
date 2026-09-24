import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/motion_editor.dart';

void main() {
  Widget preview(Motion motion) => Directionality(
    textDirection: TextDirection.ltr,
    child: MotionPreview(motion: motion),
  );

  for (var ms = 400; ms <= 2400; ms += 200) {
    testWidgets('a preview retuned mid-play stops once disposed ($ms ms)', (
      tester,
    ) async {
      await tester.pumpWidget(
        preview(const Motion.cupertino(duration: Duration(milliseconds: 600))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        preview(
          const Motion.cupertino(
            duration: Duration(milliseconds: 600),
            bounce: 0.3,
          ),
        ),
      );
      // The restart lands while the first run is still playing.
      await tester.pump(const Duration(milliseconds: 150));
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpWidget(const SizedBox());
      for (var t = 0; t < 2000; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
