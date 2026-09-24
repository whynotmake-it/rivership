import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _looping(String label) => SingleMotionBuilder(
  debugLabel: label,
  from: 0,
  value: 1,
  motion: const Motion.linear(Duration(seconds: 30)),
  builder: (context, value, child) => const SizedBox(height: 4),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool visible,
  required bool enabled,
  List<Widget> children = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MotorDevTools(
      enabled: enabled,
      visible: visible,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [_looping('First'), ...children]),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('hiding the overlay keeps tracking and changes', (tester) async {
    await _pump(tester, visible: true, enabled: true);
    await tester.tap(_launcher);
    await _settle(tester);
    await tester.tap(find.text('First'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-speed-0.5')));
    await tester.pump();

    await _pump(tester, visible: false, enabled: true);
    await _settle(tester);
    expect(_launcher, findsNothing);
    expect(find.text('First'), findsNothing);

    await _pump(tester, visible: true, enabled: true);
    await _settle(tester);
    expect(find.text('Playing  ·  0.5×'), findsOneWidget);
    expect(find.byKey(const ValueKey('motor-devtools-reset-page')), findsOne);
  });

  testWidgets('controllers mounted while hidden show up once shown', (
    tester,
  ) async {
    await _pump(tester, visible: false, enabled: true);
    await _pump(
      tester,
      visible: false,
      enabled: true,
      children: [_looping('Late')],
    );
    await _settle(tester);

    await _pump(
      tester,
      visible: true,
      enabled: true,
      children: [_looping('Late')],
    );
    await tester.tap(_launcher);
    await _settle(tester);
    expect(find.text('2 controllers'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
  });

  testWidgets('hiding resumes what the open page paused', (tester) async {
    await _pump(tester, visible: true, enabled: true);
    await tester.tap(_launcher);
    await _settle(tester);
    await tester.tap(find.text('First'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-play-pause')));
    await tester.pump();
    expect(find.textContaining('Paused'), findsOneWidget);

    await _pump(tester, visible: false, enabled: true);
    await _pump(tester, visible: true, enabled: true);
    await _settle(tester);
    expect(find.textContaining('Paused'), findsNothing);
  });

  testWidgets('disabling stops tracking and undoes changes', (tester) async {
    await _pump(tester, visible: true, enabled: true);
    await tester.tap(_launcher);
    await _settle(tester);
    await tester.tap(find.text('First'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-speed-0.5')));
    await tester.pump();

    await _pump(tester, visible: true, enabled: false);
    expect(_launcher, findsNothing);
    await _pump(tester, visible: true, enabled: true);
    await tester.tap(_launcher);
    await _settle(tester);
    expect(find.textContaining('0.5×'), findsNothing);
  });
}
