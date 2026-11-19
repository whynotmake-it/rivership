// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const delay = Duration(milliseconds: 100);
  const frame = Duration(milliseconds: 16);

  group('a delay keeps the velocity the plan was seeded with', () {
    late Track<double> a;
    late TrackController c;

    setUp(() => a = Track<double>(MotionConverter.single, initial: 0));

    Future<void> create(WidgetTester tester) async {
      c = TrackController(vsync: tester);
      addTearDown(c.dispose);
    }

    testWidgets('withVelocity moves the track once the delay has passed',
        (tester) async {
      await create(tester);
      c.animate([
        a(
          [const TrackStep.to(0, motion: CupertinoMotion.smooth())],
          withVelocity: 10,
        ),
      ]);
      await tester.pump();
      await tester.pump(frame);
      expect(c.value(a), isNot(0), reason: 'moves right away without a delay');
      c
        ..stop(canceled: true)
        ..set([a.value(0)])
        ..animate([
          a(
            [const TrackStep.to(0, motion: CupertinoMotion.smooth())],
            withVelocity: 10,
            delay: delay,
          ),
        ]);
      await tester.pump();
      await tester.pump(delay);
      expect(c.value(a), 0, reason: 'rests during the delay');
      await tester.pump(frame);
      await tester.pump(frame);
      expect(c.value(a), isNot(0));
      c.stop(canceled: true);
    });

    testWidgets('set() with a velocity survives a delayed animation',
        (tester) async {
      await create(tester);
      c
        ..set([a.value(0, velocity: 10)])
        ..animate([
          a(
            [const TrackStep.to(0, motion: CupertinoMotion.smooth())],
            delay: delay,
          ),
        ]);
      await tester.pump();
      await tester.pump(delay);
      await tester.pump(frame);
      await tester.pump(frame);
      expect(c.value(a), isNot(0));
      c.stop(canceled: true);
    });
  });
}
