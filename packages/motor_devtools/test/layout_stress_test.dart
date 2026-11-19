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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _frames(tester);
}

Future<void> _drag(WidgetTester tester, Finder finder, Offset by) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  for (var i = 0; i < 8; i++) {
    await gesture.moveBy(by / 8);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _frames(tester);
}

final _surface = find.byKey(const ValueKey('motor-devtools-surface'));

void main() {
  // A phone and a window that fits the whole panel.
  const roomy = [Size(390, 844), Size(1280, 800)];

  // A window too short for the panel, and windows smaller than the panel
  // and the bubble, where controls may be out of reach.
  const cramped = [Size(320, 480), Size(200, 160), Size(80, 60)];

  for (final size in roomy) {
    testWidgets('opens, pages, drags and minimizes at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MotorDevTools(child: _Harness()));
      await _frames(tester, 5);

      await _tap(tester, _launcher);
      expect(find.text('Card deal'), findsOneWidget);
      expect(find.text('Button press ×3'), findsOneWidget);

      await _tap(
        tester,
        find.byKey(const ValueKey('motor-controller-Card deal')),
      );
      expect(_back, findsOneWidget);
      expect(
        find.byKey(const ValueKey('motor-devtools-timeline')),
        findsOneWidget,
      );

      await _tap(tester, find.byKey(const ValueKey('motor-devtools-tracks')));
      await _tap(
        tester,
        find.byKey(const ValueKey('motor-devtools-track-Ace')),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('motor-devtools-motion-Spring')),
      );
      expect(
        find.byKey(const ValueKey('motor-devtools-spring-graph')),
        findsOneWidget,
      );

      final resting = tester.getRect(_surface);
      await _drag(tester, find.text('Card deal'), const Offset(-300, -200));
      expect(tester.getRect(_surface), isNot(resting));
      await _drag(tester, find.text('Card deal'), const Offset(400, 500));

      await _tap(tester, _back);
      expect(_back, findsNothing);
      await _tap(tester, find.text('Button press ×3'));
      expect(_back, findsOneWidget);
      expect(find.text('Card deal'), findsNothing);
      await _tap(tester, _back);
      expect(find.text('Card deal'), findsOneWidget);

      await _tap(tester, _minimize);
      expect(_launcher, findsOneWidget);
      expect(_minimize, findsNothing);
      final bubble = tester.getRect(_surface);
      await _drag(tester, _launcher, const Offset(-500, -300));
      expect(tester.getRect(_surface), isNot(bubble));

      await _tap(tester, _launcher);
      expect(_minimize, findsOneWidget);
      await _tap(tester, _minimize);
      expect(_launcher, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in cramped) {
    testWidgets('does not throw at $size', (tester) async {
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
  }

  for (final size in [...roomy, ...cramped]) {
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
  late final List<TrackController> presses;

  @override
  void initState() {
    super.initState();
    presses = [
      for (var i = 0; i < 3; i++)
        TrackController(vsync: this, debugLabel: 'Button press')
          ..inspectionGroup = 'Button press',
    ];
    for (final press in presses) {
      unawaited(
        press.animate([
          king([
            const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 5))),
          ]),
        ]),
      );
    }
    unawaited(
      deal.play(
        TrackTimeline([
          ace([
            const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 2))),
          ]),
          king([const TrackStep.to(1, motion: Motion.smoothSpring())]),
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
