import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear = Motion.linear(Duration(milliseconds: 100));

  testWidgets(
      'TrackBuilder built inactive starts at the animation start value (from)',
      (tester) async {
    // Track has an initial, but the animation says to start from 0.
    final t = Track<double>(MotionConverter.single, initial: 5);
    double? shown;
    await tester.pumpWidget(
      TrackBuilder(
        active: false,
        animations: [
          t([const TrackStep.to(1, motion: linear)], from: 0),
        ],
        builder: (context, value, child) {
          shown = value(t);
          return const SizedBox();
        },
      ),
    );
    // Docs: "Built inactive, the tracks start at their start values".
    expect(shown, 0);
  });

  testWidgets('TrackBuilder built inactive with from and no Track.initial',
      (tester) async {
    final t = Track<double>(MotionConverter.single);
    double? shown;
    await tester.pumpWidget(
      TrackBuilder(
        active: false,
        animations: [
          t([const TrackStep.to(1, motion: linear)], from: 0),
        ],
        builder: (context, value, child) {
          shown = value(t);
          return const SizedBox();
        },
      ),
    );
    expect(tester.takeException(), isNull);
    expect(shown, 0);
  });
}
