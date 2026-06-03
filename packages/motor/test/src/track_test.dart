import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

class _FreeTestMotion extends FreeMotion {
  const _FreeTestMotion();

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  }) {
    return _FreeTestSimulation(start: start, velocity: velocity);
  }
}

class _FreeTestSimulation extends Simulation {
  _FreeTestSimulation({
    required this.start,
    required this.velocity,
  });

  final double start;
  final double velocity;

  @override
  double x(double time) => start + velocity * time;

  @override
  double dx(double time) => velocity;

  @override
  bool isDone(double time) => time >= 1;
}

void main() {
  group('Track', () {
    test('uses identity equality', () {
      final first = Track<double>(MotionConverter.single, origin: 0.0);
      final second = Track<double>(MotionConverter.single, origin: 0.0);

      expect(first, same(first));
      expect(first == second, isFalse);
    });

    test('creates target animations', () {
      final track = Track<double>(MotionConverter.single, origin: 0.0);
      final animation = track.to(
        1,
        motion: const Motion.curved(Duration(milliseconds: 300)),
      );

      expect(animation.track, same(track));
      expect(animation.steps, hasLength(1));
      final step = animation.steps.single;
      expect(step, isA<StepTo<double>>());
      expect((step as StepTo<double>).value, equals(1));
      expect(step.motion, isA<CurvedMotion>());
    });

    test('creates multi-step animations', () {
      final track = Track<double>(MotionConverter.single, origin: 0.0);
      final steps = <Step<double>>[
        const Step.hold(Duration(milliseconds: 100)),
        const Step.to(1.0, motion: Motion.linear(Duration(milliseconds: 200))),
      ];

      final animation = track(steps);

      expect(animation.track, same(track));
      expect(animation.steps, same(steps));
    });

    test('creates value snapshots', () {
      final track = Track<double>(MotionConverter.single, origin: 0.0);

      final snapshot = track.value(10);

      expect(snapshot.track, same(track));
      expect(snapshot.value, equals(10));
    });

    test('creates velocity snapshots', () {
      final track = Track<double>(MotionConverter.single, origin: 0.0);

      final snapshot = track.velocity(5.0);

      expect(snapshot.track, same(track));
      expect(snapshot.value, equals(5.0));
    });

    test('creates free-motion animations', () {
      final track = Track<double>(MotionConverter.single, origin: 0.0);

      final animation = track.free(const _FreeTestMotion());

      expect(animation.track, same(track));
      expect(animation.steps, hasLength(1));
      final step = animation.steps.single;
      expect(step, isA<StepFree<double>>());
      expect((step as StepFree<double>).motion, isA<_FreeTestMotion>());
    });
  });

  group('TrackTimeline', () {
    test('owns animations, loop mode, and from overrides', () {
      final opacity = Track<double>(MotionConverter.single, origin: 0.0);
      final scale = Track<double>(MotionConverter.single, origin: 1.0);
      final opacityAnimation = opacity.to(
        1,
        motion: const Motion.curved(Duration(milliseconds: 300)),
      );
      final scaleAnimation = scale.to(
        2,
        motion: const Motion.curved(Duration(milliseconds: 300)),
      );
      final from = opacity.value(0.5);

      final timeline = TrackTimeline(
        [opacityAnimation, scaleAnimation],
        loop: LoopMode.seamless,
        from: [from],
      );

      expect(timeline.animations, [opacityAnimation, scaleAnimation]);
      expect(timeline.loop, LoopMode.seamless);
      expect(timeline.from, [from]);
    });
  });
}
