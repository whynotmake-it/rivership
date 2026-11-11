import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_devtools/src/session.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));
final _panel = find.byKey(const ValueKey('motor-devtools-panel'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<TrackController> _pump(
  WidgetTester tester, {
  MotorDevToolsController? devTools,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  late TrackController controller;
  await tester.pumpWidget(
    MotorDevTools(
      controller: devTools,
      child: _Harness(onReady: (value) => controller = value),
    ),
  );
  await tester.pump();
  return controller;
}

/// Opens a track's motion editor on a curve, which shows a slider.
Future<void> _openCurveEditor(WidgetTester tester) async {
  await tester.tap(_launcher);
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('motor-controller-Checkout')));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('motor-devtools-tracks')));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('motor-devtools-track-Opacity')));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('motor-devtools-motion-Curve')));
  await _settle(tester);
}

List<SemanticsNode> _controls(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  bool visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isButton || data.flagsCollection.isSlider) {
      nodes.add(node);
    }
    node.visitChildren(visit);
    return true;
  }

  visit(tester.getSemantics(_panel));
  return nodes;
}

void main() {
  testWidgets('every control has one label', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await _openCurveEditor(tester);

    final labels = [
      for (final node in _controls(tester)) node.getSemanticsData().label,
    ];
    expect(labels, isNotEmpty);
    expect(labels, contains('Back'));
    expect(labels, contains('Replay'));
    expect(labels, contains('Duration'));
    for (final label in labels) {
      expect(label.trim(), isNotEmpty, reason: 'a control without a label');
      expect(label, isNot(contains('\n')), reason: '"$label" is read twice');
    }
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('the duration slider steps with actions and arrow keys', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = await _pump(tester);
    await _openCurveEditor(tester);
    final slider = find.bySemanticsLabel('Duration');
    await tester.ensureVisible(slider);
    await _settle(tester);
    Duration duration() =>
        (controller.motionOverrides.values.single as CurvedMotion).duration;
    expect(duration(), const Duration(milliseconds: 500));
    expect(tester.getSemantics(slider).value, '500 ms');
    expect(tester.getSemantics(slider).increasedValue, '570 ms');

    tester.semantics.increase(find.semantics.byLabel('Duration'));
    await tester.pump();
    expect(duration(), const Duration(milliseconds: 570));
    expect(tester.getSemantics(slider).value, '570 ms');

    for (var i = 0; i < 2; i++) {
      tester.semantics.decrease(find.semantics.byLabel('Duration'));
      await tester.pump();
    }
    expect(duration(), const Duration(milliseconds: 430));

    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byKey(const ValueKey('motor-devtools-duration')),
              matching: find.byType(CustomPaint),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(duration(), const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(duration(), const Duration(milliseconds: 430));

    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('Escape closes the panel', (tester) async {
    final devTools = MotorDevToolsController();
    addTearDown(devTools.dispose);
    await _pump(tester, devTools: devTools);
    await tester.tap(_launcher);
    await _settle(tester);
    expect(devTools.isOpen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(devTools.isOpen, isFalse);
    expect(_panel, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('enter activates a focused control', (tester) async {
    final devTools = MotorDevToolsController();
    addTearDown(devTools.dispose);
    await _pump(tester, devTools: devTools);
    await tester.tap(_launcher);
    await _settle(tester);
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byKey(const ValueKey('motor-devtools-minimize')),
              matching: find.byType(GestureDetector),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(devTools.isOpen, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large text scales up to a limit without overflowing', (
    tester,
  ) async {
    await _pump(tester, textScale: 3);
    await _openCurveEditor(tester);
    expect(tester.takeException(), isNull);
    final text = tester.widget<RichText>(
      find.descendant(of: _panel, matching: find.byType(RichText)).first,
    );
    expect(text.textScaler.scale(10), closeTo(13, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });
}

class _Harness extends StatefulWidget {
  const _Harness({required this.onReady});

  final ValueChanged<TrackController> onReady;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  static final opacity = Track<double>(
    MotionConverter.single,
    initial: 0,
    debugLabel: 'Opacity',
  );

  late final TrackController controller;

  @override
  void initState() {
    super.initState();
    controller = TrackController(vsync: this, debugLabel: 'Checkout');
    widget.onReady(controller);
    unawaited(
      controller.animate([
        opacity([
          const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 10))),
        ], from: 0),
      ]),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
