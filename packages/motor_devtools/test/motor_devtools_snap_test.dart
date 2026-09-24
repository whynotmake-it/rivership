// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:snaptest/snaptest.dart';

const _rendered = SnaptestSettings.rendered(
  pathPrefix: '.snaptest/motor_devtools/',
);

void main() {
  for (final brightness in Brightness.values) {
    snapTest(
      'Motor DevTools rendered ${brightness.name}',
      devices: {Devices.ios.iPhone16},
      settings: _rendered,
      (tester) => _exerciseStateMatrix(
        tester,
        brightness,
        (name) => snap(name: 'rendered $name', settings: _rendered),
      ),
    );
  }

  snapTest(
    'Motor DevTools golden state matrix',
    devices: {Devices.ios.iPhone16},
    (tester) => _exerciseStateMatrix(
      tester,
      Brightness.light,
      (name) => snap.golden(name: name),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _exerciseStateMatrix(
  WidgetTester tester,
  Brightness brightness,
  Future<void> Function(String name) capture,
) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final devTools = MotorDevToolsController();
  late _TimelineFixture fixture;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MotorDevTools(
        controller: devTools,
        motions: const {'Emphasized': Motion.bouncySpring()},
        child: child!,
      ),
      home: _TimelineHarness(onReady: (value) => fixture = value),
    ),
  );
  await tester.pump();
  fixture.controller.pause();
  fixture.controller.scrubTo(const Duration(milliseconds: 350));
  await tester.pump();
  final prefix = brightness == Brightness.dark ? 'dark ' : '';

  await capture('${prefix}motor devtools 01 bubble');

  await tester.tap(find.byKey(const ValueKey('motor-devtools-launcher')));
  await _settle(tester);
  await capture('${prefix}motor devtools 02 controller list');

  await tester.tap(
    find.byKey(const ValueKey('motor-controller-Verification timeline')),
  );
  await _settle(tester);
  await capture('${prefix}motor devtools 03 controller detail');

  await tester.tap(find.byKey(const ValueKey('motor-devtools-tracks')));
  await _settle(tester);
  final timeline = tester.getRect(
    find.byKey(const ValueKey('motor-devtools-timeline')),
  );
  final gesture = await tester.startGesture(timeline.centerLeft);
  await gesture.moveTo(timeline.center + Offset(timeline.width * 0.25, 0));
  await tester.pump();
  await capture('${prefix}motor devtools 04 tracks while scrubbing');
  await gesture.up();
  await tester.pump();

  await tester.tap(
    find.byKey(const ValueKey('motor-devtools-track-Card scale')),
  );
  await _settle(tester);
  await tester.tap(
    find.byKey(const ValueKey('motor-devtools-motion-Spring')),
  );
  await tester.pump();
  fixture.controller
    ..pause()
    ..scrubTo(const Duration(milliseconds: 500));
  await _settle(tester);
  await capture('${prefix}motor devtools 05 motion editor');

  await tester.pumpWidget(const SizedBox());
  devTools.dispose();
}

class _TimelineHarness extends StatefulWidget {
  const _TimelineHarness({required this.onReady});

  final ValueChanged<_TimelineFixture> onReady;

  @override
  State<_TimelineHarness> createState() => _TimelineHarnessState();
}

class _TimelineHarnessState extends State<_TimelineHarness>
    with TickerProviderStateMixin {
  static final primary = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Card scale',
  );
  static final secondary = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Card opacity',
  );
  static final offset = Track<Offset>(
    MotionConverter.offset,
    initial: Offset.zero,
    debugLabel: 'Badge offset',
  );

  late final TrackController controller;
  late final MotionController<double> other;

  @override
  void initState() {
    super.initState();
    controller = TrackController(
      vsync: this,
      debugLabel: 'Verification timeline',
    );
    other = MotionController<double>(
      motion: const Motion.smoothSpring(),
      vsync: this,
      converter: MotionConverter.single,
      initialValue: 0,
      debugLabel: 'Sheet drag',
    );
    TrackController(vsync: this);
    widget.onReady(_TimelineFixture(controller: controller));
    controller.animate([
      primary.to(
        1,
        motion: const Motion.linear(Duration(seconds: 1)),
        from: 0,
      ),
      secondary(
        const [
          TrackStep.hold(Duration(milliseconds: 200)),
          TrackStep.to(
            1,
            motion: Motion.cupertino(
              duration: Duration(milliseconds: 600),
              bounce: 0.2,
            ),
          ),
          TrackStep.sync(token: 'done'),
        ],
        from: 0,
      ),
      offset(
        const [
          TrackStep.to(
            Offset(0, 24),
            motion: Motion.curved(
              Duration(milliseconds: 400),
              Curves.easeOutCubic,
            ),
          ),
          TrackStep.sync(token: 'done'),
          TrackStep.to(Offset.zero, motion: Motion.snappySpring()),
        ],
      ),
    ]);
  }

  @override
  void dispose() {
    controller.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: const Center(
      child: Text(
        'Preview surface',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _TimelineFixture {
  const _TimelineFixture({required this.controller});

  final TrackController controller;
}
