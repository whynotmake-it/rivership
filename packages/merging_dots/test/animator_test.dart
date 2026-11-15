import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

class _Vsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  const motion = Motion.linear(Duration(milliseconds: 100));

  testWidgets('animates every channel from one grid to the next', (
    tester,
  ) async {
    final animator = DotAnimator<DotGrid>(
      vsync: _Vsync(),
      initial: DotGrid.parse('#.'),
    );
    addTearDown(animator.dispose);
    expect(animator.values.sublist(0, 6), [1, 0, 0, 0, 0, 0]);

    animator.animateTo(DotGrid.parse('.#'), motion: motion);
    expect(animator.isAnimating, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(animator.values[0], closeTo(0.5, 0.01));
    expect(animator.values[3], closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 60));
    expect(animator.values.sublist(0, 6), [0, 0, 0, 1, 0, 0]);
    expect(animator.isAnimating, isFalse);
  });

  testWidgets('staggers delay dots by position', (tester) async {
    final animator = DotAnimator<DotGrid>(
      vsync: _Vsync(),
      initial: DotGrid.parse('...'),
    );
    addTearDown(animator.dispose);
    animator.animateTo(
      DotGrid.parse('###'),
      motion: motion,
      stagger: const DotStagger.directional(
        duration: Duration(milliseconds: 100),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(animator.values[0], closeTo(0.5, 0.01));
    expect(animator.values[3], closeTo(0, 0.01));
    expect(animator.values[6], 0);
    await tester.pump(const Duration(milliseconds: 160));
    expect(animator.values[6], 1);
    expect(animator.isAnimating, isFalse);
  });

  testWidgets('a retargeted spring keeps its momentum', (tester) async {
    const spring = Motion.smoothSpring(duration: Duration(milliseconds: 400));
    final animator = DotAnimator<DotCloud>(
      vsync: _Vsync(),
      initial: const DotCloud([Dot(0, 0, 1)]),
    );
    addTearDown(animator.dispose);
    animator.animateTo(const DotCloud([Dot(100, 0, 1)]), motion: spring);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = animator.values[0];
    await tester.pump(const Duration(milliseconds: 16));
    final speed = (animator.values[0] - before) / 0.016;
    expect(speed, greaterThan(100));

    // Retarget to where it already is: momentum carries it past.
    animator.animateTo(
      DotCloud([Dot(animator.values[0], 0, 1)]),
      motion: spring,
    );
    final at = animator.values[0];
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      animator.values[0] - at,
      closeTo(speed * 0.016, speed * 0.016 * 0.3),
    );
    await tester.pumpAndSettle();
    expect(animator.values[0], closeTo(at, 0.01));
  });

  testWidgets('clouds grow new dots and shrink removed ones', (tester) async {
    final animator = DotAnimator<DotCloud>(
      vsync: _Vsync(),
      initial: const DotCloud([Dot(10, 10, 4)]),
    );
    addTearDown(animator.dispose);
    animator.animateTo(
      const DotCloud([Dot(20, 10, 4), Dot(50, 50, 8)]),
      motion: motion,
    );
    expect(animator.dotCount, 2);
    expect(animator.values.sublist(3, 6), [50, 50, 0]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(animator.values[5], closeTo(4, 0.1));
    await tester.pumpAndSettle();

    animator.animateTo(const DotCloud([Dot(20, 10, 4)]), motion: motion);
    expect(animator.dotCount, 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(animator.values.sublist(3, 5), [50, 50]);
    expect(animator.values[5], closeTo(4, 0.1));
    await tester.pumpAndSettle();
    expect(animator.dotCount, 1);
  });

  testWidgets('plays sequences with holds and loops', (tester) async {
    final frames = <int>[];
    final animator = DotAnimator<DotGrid>(
      vsync: _Vsync(),
      initial: DotGrid.parse('#.'),
    )..onFrame = frames.add;
    addTearDown(animator.dispose);
    animator.play(
      DotSequence([
        DotKeyframe(
          DotGrid.parse('#.'),
          hold: const Duration(milliseconds: 50),
        ),
        DotKeyframe(DotGrid.parse('.#')),
      ], motion: motion),
    );
    expect(frames, [0]);
    // Frame 0 holds until 50 ms, frame 1 moves until 150 ms, then the loop
    // moves back to frame 0 until 250 ms, exactly on time.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(frames, [0, 1]);
    await tester.pump(const Duration(milliseconds: 85));
    expect(animator.values[3], closeTo(0.95, 0.01));
    await tester.pump(const Duration(milliseconds: 10));
    expect(frames, [0, 1, 0]);
    expect(animator.values[3], closeTo(0.95, 0.01));
    await tester.pump(const Duration(milliseconds: 100));
    expect(animator.values[0], 1);

    animator.pause();
    expect(animator.isAnimating, isFalse);
    animator.resume();
    expect(animator.isAnimating, isTrue);
    animator.jumpTo(DotGrid.parse('##'));
    expect(animator.isAnimating, isFalse);
  });

  test('ping pong plays the frames backwards', () {
    final sequence = DotSequence(
      [for (var i = 0; i < 3; i++) DotKeyframe(DotGrid.filled(1, 1, i / 2))],
      loop: LoopMode.pingPong,
    );
    expect(sequence.next(1, 1), (2, 1));
    expect(sequence.next(2, 1), (1, -1));
    expect(sequence.next(0, -1), (1, 1));
    expect(
      DotSequence(sequence.frames, loop: LoopMode.none).next(2, 1),
      isNull,
    );
  });

  testWidgets('a frame of a 64 x 64 grid is cheap', (tester) async {
    final animator = DotAnimator<DotGrid>(
      vsync: _Vsync(),
      initial: DotGrid(64, 64),
    );
    addTearDown(animator.dispose);
    animator.animateTo(
      DotGrid.filled(64, 64),
      motion: const Motion.bouncySpring(duration: Duration(seconds: 10)),
      stagger: const DotStagger.radial(duration: Duration(seconds: 1)),
    );
    await tester.pump();
    final watch = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    watch.stop();
    animator.jumpTo(DotGrid(64, 64));
    // About 1ms per frame in a JIT test, pump included.
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  testWidgets('short steps keep their timing', (tester) async {
    final frames = <int>[];
    final animator = DotAnimator<DotGrid>(
      vsync: _Vsync(),
      initial: DotGrid.parse('#...'),
    )..onFrame = frames.add;
    addTearDown(animator.dispose);
    // Four 30 ms steps, filmed at 60 Hz: steps don't line up with frames.
    animator.play(
      DotSequence([
        for (var i = 0; i < 4; i++)
          DotKeyframe(DotGrid.generate(4, 1, (c, _) => c == i ? 1 : 0)),
      ], motion: const Motion.linear(Duration(milliseconds: 30))),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 480 ms is 16 steps. Rounding each step up to a frame would only
    // have made 15 (32 ms each), and fewer with slower frames.
    expect(frames.length, inInclusiveRange(16, 17));
    animator.jumpTo(DotGrid(4, 1));
  });
}
