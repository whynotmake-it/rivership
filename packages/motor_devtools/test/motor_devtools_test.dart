// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_devtools/src/session.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));
final _checkout = find.byKey(
  const ValueKey('motor-controller-Checkout confirmation'),
);

Future<TrackController> _pumpHarness(
  WidgetTester tester, {
  MotorDevToolsController? devTools,
  bool labeled = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late TrackController controller;
  await tester.pumpWidget(
    MotorDevTools(
      controller: devTools,
      child: _MotionHarness(
        labeled: labeled,
        onReady: (value) => controller = value,
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// Lets the devtools' springs settle while the harness keeps playing.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(_launcher);
  await _settle(tester);
  await tester.tap(_checkout);
  await _settle(tester);
}

final _surface = find.byKey(const ValueKey('motor-devtools-surface'));

void main() {
  testWidgets('drags the open window from non-interactive areas', (
    tester,
  ) async {
    await _pumpHarness(tester);
    tester.view.physicalSize = const Size(900, 700);
    await _settle(tester);
    await tester.tap(_launcher);
    await _settle(tester);
    final resting = tester.getRect(_surface);
    expect(resting.right, closeTo(900 - 12, 0.5));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1 controller')),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-30, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final moved = tester.getRect(_surface);
    expect(moved.size, resting.size);
    expect(moved.left, lessThan(resting.left - 200));
    expect(moved.top, lessThan(resting.top - 60));

    await gesture.up();
    await tester.pump();
    expect(tester.getRect(_surface).left, closeTo(moved.left, 1));
    await _settle(tester);
    final settled = tester.getRect(_surface);
    expect(settled.left, closeTo(12, 0.5));
    expect(settled.size, resting.size);
    expect(find.text('1 controller'), findsOneWidget);
  });

  testWidgets('minimizes to the bubble and reopens where it left off', (
    tester,
  ) async {
    await _pumpHarness(tester);
    await _openDetail(tester);
    expect(find.bySemanticsLabel('Minimize Motor devtools'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-minimize')).first,
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('motor-devtools-timeline')), findsNothing);
    expect(tester.getSize(_surface), const Size.square(44));

    await tester.tap(_launcher);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('motor-devtools-timeline')),
      findsOneWidget,
    );
  });

  testWidgets('drags that start on controls keep their own behavior', (
    tester,
  ) async {
    await _pumpHarness(tester);
    await _openDetail(tester);
    final resting = tester.getRect(_surface);

    Future<void> dragFrom(Finder finder, Offset step) async {
      final gesture = await tester.startGesture(tester.getCenter(finder));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(step);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getRect(_surface), resting);
      await gesture.up();
      await _settle(tester);
      expect(tester.getRect(_surface), resting);
    }

    // Mostly vertical, which a window drag would otherwise win.
    await dragFrom(
      find.byKey(const ValueKey('motor-devtools-timeline')),
      const Offset(-4, -12),
    );
    await dragFrom(
      find.byKey(const ValueKey('motor-devtools-minimize')).first,
      const Offset(-10, -12),
    );
    expect(find.text('Checkout confirmation'), findsWidgets);
  });

  testWidgets('lists controllers by debugLabel, without its own', (
    tester,
  ) async {
    await _pumpHarness(tester);

    await tester.tap(_launcher);
    await _settle(tester);

    expect(find.text('Motor'), findsNothing);
    expect(find.text('1 controller'), findsOneWidget);
    expect(find.text('Checkout confirmation'), findsOneWidget);
    expect(find.textContaining('Card opacity'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guesses a name for unlabeled controllers and suggests one', (
    tester,
  ) async {
    await _pumpHarness(tester, labeled: false);

    await tester.tap(_launcher);
    await _settle(tester);
    expect(find.text('MotionHarness'), findsOneWidget);
    await tester.tap(find.text('MotionHarness'));
    await _settle(tester);

    expect(find.textContaining('debugLabel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the bubble follows a drag and settles on the nearest side', (
    tester,
  ) async {
    await _pumpHarness(tester);
    final start = tester.getTopLeft(_launcher);
    expect(start.dx, 390 - 12 - 44);

    final gesture = await tester.startGesture(tester.getCenter(_launcher));
    await gesture.moveBy(const Offset(-100, -100));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, -50));
    await tester.pump();
    final dragged = tester.getCenter(_launcher);
    expect(dragged.dx, closeTo(start.dx + 22 - 150, 1));
    expect(dragged.dy, closeTo(start.dy + 22 - 150, 1));
    await gesture.up();
    await _settle(tester);
    expect(tester.getTopLeft(_launcher).dx, closeTo(start.dx, 0.5));

    await tester.flingFrom(
      tester.getCenter(_launcher),
      const Offset(-120, -60),
      1500,
    );
    await tester.pump();
    final released = tester.getTopLeft(_launcher);
    await _settle(tester);
    final settled = tester.getTopLeft(_launcher);
    expect(settled.dx, closeTo(12, 0.5));
    expect(settled.dy, lessThan(released.dy - 60));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expands into the list, opens a controller, and goes back', (
    tester,
  ) async {
    final devTools = MotorDevToolsController();
    await _pumpHarness(tester, devTools: devTools);

    await tester.tap(_launcher);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final growing = tester.getSize(
      find.byKey(const ValueKey('motor-devtools-panel')),
    );
    await _settle(tester);
    expect(devTools.isOpen, isTrue);
    expect(growing.width, 366);
    expect(_launcher, findsNothing);

    await tester.tap(_checkout);
    await _settle(tester);
    expect(devTools.selectedController?.debugLabel, 'Checkout confirmation');
    expect(
      find.byKey(const ValueKey('motor-devtools-timeline')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('motor-devtools-back')));
    await _settle(tester);
    expect(devTools.selectedController, isNull);
    expect(find.byKey(const ValueKey('motor-devtools-timeline')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-minimize')));
    await _settle(tester);
    expect(devTools.isOpen, isFalse);
    expect(_launcher, findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    devTools.dispose();
  });

  testWidgets('the panel surface follows its content on every frame', (
    tester,
  ) async {
    final devTools = MotorDevToolsController();
    await _pumpHarness(tester, devTools: devTools);
    final surface = find.byKey(const ValueKey('motor-devtools-surface'));
    final panel = find.byKey(const ValueKey('motor-devtools-panel'));

    Future<void> expectInStep(Future<void> Function() change) async {
      await change();
      for (var frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.getRect(surface),
          tester.getRect(panel),
          reason: 'frame $frame',
        );
      }
    }

    await tester.tap(_launcher);
    await _settle(tester);
    await expectInStep(() => tester.tap(_checkout));
    await expectInStep(
      () => tester.tap(find.byKey(const ValueKey('motor-devtools-tracks'))),
    );
    await expectInStep(
      () => tester.tap(
        find.byKey(const ValueKey('motor-devtools-track-Card opacity')),
      ),
    );
    await expectInStep(
      () => tester.tap(find.byKey(const ValueKey('motor-devtools-done'))),
    );
    await expectInStep(
      () => tester.tap(find.byKey(const ValueKey('motor-devtools-back'))),
    );

    await tester.pumpWidget(const SizedBox());
    devTools.dispose();
  });

  testWidgets('pauses, resumes, and replays', (tester) async {
    final controller = await _pumpHarness(tester);
    await _openDetail(tester);
    final playPause = find.byKey(const ValueKey('motor-devtools-play-pause'));

    expect(controller.isAnimating, isTrue);
    await tester.tap(playPause);
    await tester.pump();
    expect(controller.isAnimating, isFalse);
    final paused = controller.value(_MotionHarnessState.opacity);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.value(_MotionHarnessState.opacity), paused);

    await tester.tap(playPause);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value(_MotionHarnessState.opacity), greaterThan(paused));

    await tester.tap(find.byKey(const ValueKey('motor-devtools-replay')));
    await tester.pump();
    expect(controller.value(_MotionHarnessState.opacity), closeTo(0, 1e-6));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dragging the timeline scrubs and resumes on release', (
    tester,
  ) async {
    final controller = await _pumpHarness(tester);
    await _openDetail(tester);
    final timeline = find.byKey(const ValueKey('motor-devtools-timeline'));
    final rect = tester.getRect(timeline);

    final gesture = await tester.startGesture(
      rect.centerRight - const Offset(1, 0),
    );
    await tester.pump();
    await gesture.moveTo(rect.center + const Offset(-40, 0));
    await gesture.moveTo(rect.center);
    await tester.pump();
    expect(controller.isAnimating, isFalse);
    expect(controller.value(_MotionHarnessState.opacity), closeTo(0.5, 0.01));

    await gesture.up();
    await tester.pump();
    expect(controller.isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changes speed and motion for the session only', (tester) async {
    final controller = await _pumpHarness(tester);
    await _openDetail(tester);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-speed-0.25')));
    await tester.pump();
    expect(controller.playbackSpeed, 0.25);

    expect(
      find.byKey(const ValueKey('motor-devtools-motion-Spring')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('motor-devtools-tracks')));
    await _settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-track-Card opacity')),
    );
    await _settle(tester);
    expect(find.text('Authored'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-motion-Spring')),
    );
    await tester.pump();
    expect(controller.motionOverrides.values.single, isA<CupertinoMotion>());
    expect(controller.value(_MotionHarnessState.opacity), closeTo(0, 1e-6));

    final graph = find.byKey(const ValueKey('motor-devtools-spring-graph'));
    await tester.ensureVisible(graph);
    await _settle(tester);
    while (controller.isAnimating) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tapAt(tester.getRect(graph).topRight + const Offset(-1, 1));
    await tester.pump();
    expect(
      controller.isAnimating,
      isFalse,
      reason: 'tuning on the graph does not replay the controller',
    );
    expect(find.textContaining('1.50 s · '), findsWidgets);
    final tuned = controller.motionOverrides.values.single as CupertinoMotion;
    expect(tuned.duration, const Duration(milliseconds: 1500));
    expect(tuned.bounce, closeTo(0.8, 0.02));
    expect(
      find.textContaining(
        'Motion.cupertino(duration: Duration(milliseconds: 1500), bounce: 0.7',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('motor-devtools-reset')));
    await tester.pump();
    expect(controller.motionOverrides, isEmpty);
    expect(find.byKey(const ValueKey('motor-devtools-reset')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-motion-Curve')));
    await tester.pump();
    expect(controller.motionOverrides.values.single, isA<CurvedMotion>());

    await tester.pumpWidget(
      MotorDevTools(
        enabled: false,
        child: _MotionHarness(onReady: (_) {}),
      ),
    );
    expect(controller.playbackSpeed, 1);
    expect(controller.motionOverrides, isEmpty);
    expect(controller.motionOverride, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("offers the app's own motions", (tester) async {
    const brand = Motion.cupertino(
      duration: Duration(milliseconds: 420),
      bounce: 0.3,
    );
    late TrackController controller;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MotorDevTools(
        motions: const {'Brand': brand},
        child: _MotionHarness(onReady: (value) => controller = value),
      ),
    );
    await tester.pump();
    await _openDetail(tester);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-tracks')));
    await _settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-track-Card opacity')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-motion-App')));
    await tester.pump();
    expect(controller.motionOverrides.values.single, brand);
    expect(
      find.byKey(const ValueKey('motor-devtools-app-Brand')),
      findsOneWidget,
    );
    expect(find.text('Brand'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('follows the platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pumpHarness(tester);
    await tester.tap(_launcher);
    await _settle(tester);

    final title = tester.widget<Text>(find.text('1 controller'));
    expect(title.style?.color, const Color(0xFFFAFAFA));
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

    controller.clearMotionOverrides();
    expect(controller.motionOverrides, isEmpty);
    expect(controller.motionOverride, isNull);

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('can be completely disabled at runtime', (tester) async {
    await tester.pumpWidget(
      const MotorDevTools(enabled: false, child: SizedBox()),
    );

    expect(_launcher, findsNothing);
    expect(MotorInspectionRegistry.hasObservers, isFalse);
  });
}

class _MotionHarness extends StatefulWidget {
  const _MotionHarness({required this.onReady, this.labeled = true});

  final ValueChanged<TrackController> onReady;
  final bool labeled;

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
      debugLabel: widget.labeled ? 'Checkout confirmation' : null,
    );
    widget.onReady(controller);
    unawaited(
      controller.animate([
        opacity.to(
          1,
          motion: const Motion.linear(Duration(seconds: 10)),
          from: 0,
        ),
      ]),
    );
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
