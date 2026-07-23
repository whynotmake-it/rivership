// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  snapTest(
    'Motor DevTools rendered state matrix',
    devices: {Devices.ios.iPhone16},
    settings: const SnaptestSettings.rendered(
      pathPrefix: '.snaptest/motor_devtools/',
    ),
    (tester) => _exerciseStateMatrix(
      tester,
      (name) async => snap(
        name: 'rendered $name',
        settings: const SnaptestSettings.rendered(
          pathPrefix: '.snaptest/motor_devtools/',
        ),
      ),
    ),
  );

  snapTest(
    'Motor DevTools golden state matrix',
    devices: {Devices.ios.iPhone16},
    (tester) => _exerciseStateMatrix(
      tester,
      (name) async => snap.golden(name: name),
    ),
  );
}

Future<void> _exerciseStateMatrix(
  WidgetTester tester,
  Future<void> Function(String name) capture,
) async {
  final devToolsController = MotorDevToolsController();
  late _TimelineFixture fixture;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MotorDevTools(
        controller: devToolsController,
        child: child!,
      ),
      home: _TimelineHarness(onReady: (value) => fixture = value),
    ),
  );
  await tester.pump();
  fixture.controller.pause();
  fixture.controller.scrubTo(const Duration(milliseconds: 350));
  await tester.pump();

  await capture('motor devtools 01 compact');

  await tester.tap(
    find.byKey(const ValueKey('motor-devtools-launcher')),
  );
  await tester.pumpAndSettle();
  await capture('motor devtools 02 one track peek');

  final peekTimeline = find.byKey(
    const ValueKey('motor-devtools-peek-timeline'),
  );
  final timelineRect = tester.getRect(peekTimeline);
  final stripStart = timelineRect.left + 78;
  final stripEnd = timelineRect.right - 2;
  final stripWidth = stripEnd - stripStart;
  final gesture = await tester.startGesture(
    Offset(stripEnd, timelineRect.center.dy),
  );
  await tester.pump();
  await gesture.moveTo(
    Offset(stripStart + stripWidth * 0.25, timelineRect.center.dy),
  );
  await tester.pump();
  expect(fixture.controller.value(fixture.primary), closeTo(0.25, 0.02));
  await gesture.up();
  fixture.controller.pause();
  await tester.pump();
  await capture('motor devtools 03 scrub backward');

  final forwardGesture = await tester.startGesture(
    Offset(stripStart + stripWidth * 0.25, timelineRect.center.dy),
  );
  await tester.pump();
  await forwardGesture.moveTo(
    Offset(stripStart + stripWidth * 0.75, timelineRect.center.dy),
  );
  await tester.pump();
  expect(fixture.controller.value(fixture.primary), greaterThan(0.7));
  expect(fixture.controller.value(fixture.primary), lessThan(0.9));
  await forwardGesture.up();
  fixture.controller.pause();
  await tester.pump();
  await capture('motor devtools 04 scrub forward');

  devToolsController.open();
  await tester.pumpAndSettle();
  await capture('motor devtools 05 controller list');

  devToolsController.showController(fixture.controller);
  await tester.pumpAndSettle();
  await capture('motor devtools 06 full timeline');

  final springField = find.byKey(
    const ValueKey('motor-devtools-spring-field'),
  );
  await tester.ensureVisible(springField);
  await tester.pumpAndSettle();
  await capture('motor devtools 07 spring field');

  final curveMode = find.byKey(
    const ValueKey('motor-devtools-mode-curve'),
  );
  await tester.tap(curveMode);
  await tester.pumpAndSettle();
  await capture('motor devtools 08 curve lab');

  await tester.pumpWidget(const SizedBox());
  devToolsController.dispose();
}

class _TimelineHarness extends StatefulWidget {
  const _TimelineHarness({required this.onReady});

  final ValueChanged<_TimelineFixture> onReady;

  @override
  State<_TimelineHarness> createState() => _TimelineHarnessState();
}

class _TimelineHarnessState extends State<_TimelineHarness>
    with SingleTickerProviderStateMixin {
  static final primary = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Primary progress',
  );
  static final secondary = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Secondary progress',
  );

  late final TrackController controller;

  @override
  void initState() {
    super.initState();
    controller = TrackController(
      vsync: this,
      debugLabel: 'Verification timeline',
    );
    widget.onReady(
      _TimelineFixture(
        controller: controller,
        primary: primary,
      ),
    );
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
        ],
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
  Widget build(BuildContext context) => const Material(
    color: Color(0xFFF4F4F5),
    child: Center(
      child: Text(
        'Preview surface',
        style: TextStyle(
          color: Color(0xFF18181B),
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _TimelineFixture {
  const _TimelineFixture({
    required this.controller,
    required this.primary,
  });

  final TrackController controller;
  final Track<double> primary;
}
