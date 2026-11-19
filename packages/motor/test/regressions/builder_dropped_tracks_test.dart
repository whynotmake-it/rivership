import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear = Motion.linear(Duration(milliseconds: 100));

  testWidgets('TrackBuilder stops a looping track dropped on rebuild',
      (tester) async {
    final kept = Track<double>(MotionConverter.single, initial: 0);
    final dropped = Track<double>(MotionConverter.single, initial: 0);
    double? keptValue;
    double? droppedValue;

    Widget build(List<TrackAnimation> animations) => TrackBuilder(
          animations: animations,
          loop: LoopMode.loop,
          builder: (context, value, child) {
            keptValue = value(kept);
            droppedValue = value(dropped);
            return const SizedBox();
          },
        );

    final keptAnimation =
        kept([const TrackStep.to(1, motion: linear)], from: 0);
    await tester.pumpWidget(
      build([
        keptAnimation,
        dropped([const TrackStep.to(1, motion: linear)], from: 0),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(droppedValue, greaterThan(0));

    await tester.pumpWidget(build([keptAnimation]));
    await tester.pump();
    // A forgotten track is back at its initial value and stays there.
    expect(droppedValue, 0);
    final frozen = droppedValue;
    final keptBefore = keptValue;
    await tester.pump(const Duration(milliseconds: 20));
    expect(droppedValue, frozen);
    expect(keptValue, isNot(keptBefore));
  });

  testWidgets('PhaseTrackBuilder stops a looping track dropped on rebuild',
      (tester) async {
    final kept = Track<double>(MotionConverter.single, initial: 0);
    final dropped = Track<double>(MotionConverter.single, initial: 0);
    double? keptValue;
    double? droppedValue;

    Widget build({required bool withDropped}) => PhaseTrackBuilder<int>(
          playing: true,
          timeline: TrackPhaseTimeline(
            {
              0: [
                kept([const TrackStep.to(0, motion: linear)]),
                if (withDropped)
                  dropped([const TrackStep.to(0, motion: linear)]),
              ],
              1: [
                kept([const TrackStep.to(1, motion: linear)]),
                if (withDropped)
                  dropped([const TrackStep.to(1, motion: linear)]),
              ],
            },
            loop: LoopMode.loop,
          ),
          builder: (context, value, phase, child) {
            keptValue = value(kept);
            droppedValue = value(dropped);
            return const SizedBox();
          },
        );

    await tester.pumpWidget(build(withDropped: true));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 50));
    expect(droppedValue, greaterThan(0));

    await tester.pumpWidget(build(withDropped: false));
    await tester.pump();
    // A forgotten track is back at its initial value and stays there.
    expect(droppedValue, 0);
    final frozen = droppedValue;
    final keptBefore = keptValue;
    await tester.pump(const Duration(milliseconds: 30));
    expect(droppedValue, frozen);
    expect(keptValue, isNot(keptBefore));
  });
}
