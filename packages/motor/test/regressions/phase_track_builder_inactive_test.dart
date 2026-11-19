import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

enum _Phase { idle, pressed }

void main() {
  testWidgets('PhaseTrackBuilder built inactive rests at currentPhase',
      (tester) async {
    final scale = Track<double>(
      MotionConverter.single,
      initial: 1,
      motion: const Motion.linear(Duration(milliseconds: 100)),
    );
    double? captured;
    await tester.pumpWidget(
      PhaseTrackBuilder<_Phase>(
        active: false,
        currentPhase: _Phase.pressed,
        timeline: TrackPhaseTimeline({
          _Phase.idle: [
            scale([const TrackStep.to(1)]),
          ],
          _Phase.pressed: [
            scale([const TrackStep.to(2)]),
          ],
        }),
        builder: (context, value, phase, child) {
          captured = value(scale);
          return const SizedBox();
        },
      ),
    );
    // Docs: "While inactive, the tracks move to where they rest at
    // currentPhase".
    expect(captured, 2);
  });
}
