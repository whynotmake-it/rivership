import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));
final _minimize = find.byKey(const ValueKey('motor-devtools-minimize'));
final _back = find.byKey(const ValueKey('motor-devtools-back'));

/// Pumps [count] frames, so every intermediate layout runs.
Future<void> _frames(WidgetTester tester, [int count = 40]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _tapIfShown(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await tester.tap(finder.first, warnIfMissed: false);
  await _frames(tester);
}

Future<void> _dragIfShown(
  WidgetTester tester,
  Finder finder,
  Offset by,
) async {
  if (finder.evaluate().isEmpty) return;
  final gesture = await tester.startGesture(tester.getCenter(finder.first));
  for (var i = 0; i < 8; i++) {
    await gesture.moveBy(by / 8);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _frames(tester);
}

void main() {
  const sizes = [
    Size(390, 844),
    Size(1280, 800),
    Size(1728, 1117),
    Size(320, 480),
    Size(200, 160),
    Size(80, 60),
  ];

  for (final size in sizes) {
    testWidgets('opens, pages, drags and minimizes at $size without errors', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MotorDevTools(child: _Harness()));
      await _frames(tester, 5);

      await _tapIfShown(tester, _launcher);
      await _tapIfShown(tester, find.textContaining('Card deal'));
      await _tapIfShown(
        tester,
        find.byKey(const ValueKey('motor-devtools-tracks')),
      );
      await _tapIfShown(
        tester,
        find.byKey(const ValueKey('motor-devtools-track-Ace')),
      );
      await _tapIfShown(
        tester,
        find.byKey(const ValueKey('motor-devtools-motion-Spring')),
      );
      await _dragIfShown(
        tester,
        find.text('Card deal'),
        const Offset(-300, -200),
      );
      await _dragIfShown(
        tester,
        find.text('Card deal'),
        const Offset(400, 500),
      );
      await _tapIfShown(tester, _back);
      await _tapIfShown(tester, find.textContaining('Button press'));
      await _tapIfShown(tester, _back);
      await _tapIfShown(tester, _minimize);
      await _dragIfShown(tester, _launcher, const Offset(-500, -300));
      await _tapIfShown(tester, _launcher);
      await _tapIfShown(tester, _minimize);
      await _tapIfShown(tester, _launcher);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('survives resizing to nothing at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MotorDevTools(child: _Harness()));
      await _frames(tester, 5);
      await _tapIfShown(tester, _launcher);
      await _tapIfShown(tester, find.textContaining('Card deal'));

      // Shrink the window while the panel is open, down to nothing, as a
      // desktop window may do while it is resized or minimized.
      for (final next in [
        const Size(300, 200),
        const Size(120, 90),
        const Size(30, 20),
        Size.zero,
        size,
      ]) {
        tester.view.physicalSize = next;
        await _frames(tester, 10);
      }
      await _tapIfShown(tester, _minimize);
      tester.view.physicalSize = Size.zero;
      await _frames(tester, 10);
      tester.view.physicalSize = size;
      await _frames(tester, 10);

      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  static final ace = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Ace',
  );
  static final king = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'King',
  );

  late final deal = TrackController(vsync: this, debugLabel: 'Card deal');
  late final presses = [
    for (var i = 0; i < 3; i++)
      TrackController(vsync: this, debugLabel: 'Button press')
        ..inspectionGroup = 'Button press',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(
      deal.play(
        TrackTimeline([
          ace.to(1, motion: const Motion.linear(Duration(seconds: 2))),
          king.to(1, motion: const Motion.smoothSpring()),
        ], loop: LoopMode.loop),
      ),
    );
  }

  @override
  void dispose() {
    deal.dispose();
    for (final press in presses) {
      press.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
