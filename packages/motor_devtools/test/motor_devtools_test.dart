// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_devtools/src/session.dart';

void main() {
  testWidgets('discovers and identifies controllers below the wrapper', (
    tester,
  ) async {
    late TrackController controller;
    await tester.pumpWidget(
      MotorDevTools(
        child: _MotionHarness(onReady: (value) => controller = value),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('motor-devtools-launcher')),
      findsOneWidget,
    );
    expect(find.textContaining('1 controllers'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-launcher')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('motor-devtools-peek')), findsOneWidget);
    expect(find.text('Checkout confirmation'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-peek-expand')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('1 tracks'), findsWidgets);
    expect(controller.debugLabel, 'Checkout confirmation');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replays the latest plan with a motion override', (
    tester,
  ) async {
    final subscription = MotorInspectionRegistry.attach(_NoopObserver());
    final controller = TrackController(vsync: tester);
    final track = Track<double>(MotionConverter.single, initial: 0);
    const authored = Motion.linear(Duration(seconds: 1));
    const tuned = Motion.linear(Duration(milliseconds: 100));

    unawaited(controller.animate([track.to(1, motion: authored)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.value(track), closeTo(0.3, 1e-6));

    controller
      ..setMotionOverride(track, tuned)
      ..replay();
    await tester.pump();
    expect(controller.value(track), closeTo(0, 1e-6));
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.value(track), closeTo(1, 1e-6));
    expect(controller.motionOverrides, {track: tuned});

    controller.setMotionOverride(track, null);
    expect(controller.motionOverrides, isEmpty);
    expect(controller.motionOverride, isNull);

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('can be completely disabled at runtime', (tester) async {
    await tester.pumpWidget(
      const MotorDevTools(enabled: false, child: SizedBox()),
    );

    expect(find.byKey(const ValueKey('motor-devtools-launcher')), findsNothing);
    expect(MotorInspectionRegistry.hasObservers, isFalse);
  });

  testWidgets('controls local speed and creates reversible motion overrides', (
    tester,
  ) async {
    late TrackController controller;
    await tester.pumpWidget(
      MotorDevTools(
        child: _MotionHarness(onReady: (value) => controller = value),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('motor-devtools-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-peek-expand')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(
        const ValueKey('motor-controller-Checkout confirmation'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('motor-devtools-timeline')),
      findsWidgets,
    );
    expect(find.text('MOTION STUDIO'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-speed-0.25')));
    await tester.pump();
    expect(controller.playbackSpeed, 0.25);

    final springField = find.byKey(
      const ValueKey('motor-devtools-spring-field'),
    );
    await tester.ensureVisible(springField);
    await tester.tap(springField);
    await tester.pump();
    expect(controller.motionOverrides, isNotEmpty);

    await tester.ensureVisible(
      find.byKey(const ValueKey('motor-devtools-reset-motion')),
    );
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-reset-motion')),
    );
    await tester.pump();
    expect(controller.motionOverrides, isEmpty);

    final curveMode = find.byKey(
      const ValueKey('motor-devtools-mode-curve'),
    );
    await tester.ensureVisible(curveMode);
    await tester.tap(curveMode);
    await tester.pump();
    final easeOut = find.text('Ease out');
    await tester.ensureVisible(easeOut);
    await tester.tap(easeOut);
    await tester.pump();
    expect(controller.motionOverrides, isNotEmpty);

    await tester.pumpWidget(
      MotorDevTools(
        enabled: false,
        child: _MotionHarness(onReady: (_) {}),
      ),
    );
    expect(controller.playbackSpeed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dragging the timeline pauses, scrubs, and resumes playback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MotorDevTools(child: _MotionHarness(onReady: (_) {})),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('motor-devtools-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-peek-expand')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(
        const ValueKey('motor-controller-Checkout confirmation'),
      ),
    );
    await tester.pumpAndSettle();

    final timeline = find.byKey(
      const ValueKey('motor-devtools-full-timeline'),
    );
    final gesture = await tester.startGesture(tester.getCenter(timeline));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compact launcher drags and expands through peek mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MotorDevTools(child: _MotionHarness(onReady: (_) {})),
    );
    await tester.pump();
    final launcher = find.byKey(const ValueKey('motor-devtools-launcher'));
    final before = tester.getTopLeft(launcher);

    await tester.drag(launcher, const Offset(-360, -360));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(launcher);

    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));

    await tester.tap(launcher);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('motor-devtools-peek')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _MotionHarness extends StatefulWidget {
  const _MotionHarness({required this.onReady});

  final ValueChanged<TrackController> onReady;

  @override
  State<_MotionHarness> createState() => _MotionHarnessState();
}

class _MotionHarnessState extends State<_MotionHarness>
    with SingleTickerProviderStateMixin {
  static final opacity = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Card opacity',
  );

  late final TrackController controller;

  @override
  void initState() {
    super.initState();
    controller = TrackController(
      vsync: this,
      debugLabel: 'Checkout confirmation',
    );
    widget.onReady(controller);
    controller.animate([
      opacity.to(
        1,
        motion: const Motion.linear(Duration(seconds: 2)),
        from: 0,
      ),
    ]);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF2F0EA),
    child: SizedBox.expand(),
  );
}

class _NoopObserver implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}
