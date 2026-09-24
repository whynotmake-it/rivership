// ignore_for_file: cascade_invocations

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_devtools/src/session.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(WidgetTester tester, List<Widget> children) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MotorDevTools(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: children),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_launcher);
  await _settle(tester);
}

Widget _builder({String? label}) => SingleMotionBuilder(
  debugLabel: label,
  from: 0,
  value: 1,
  motion: const Motion.linear(Duration(milliseconds: 100)),
  builder: (context, value, child) => const SizedBox(height: 4),
);

Track<double> _track(String? label) =>
    Track<double>(MotionConverter.single, initial: 0, debugLabel: label);

Widget _button() =>
    MotorInspectionScope(group: 'Button press', child: _builder());

void main() {
  late _Observer observer;
  late MotorInspectionSubscription subscription;
  setUp(() {
    observer = _Observer();
    subscription = MotorInspectionRegistry.attach(observer);
  });
  tearDown(() => subscription.dispose());

  testWidgets('puts muted rows last, groups included', (tester) async {
    await _pump(tester, [
      TickerMode(
        enabled: false,
        child: Column(children: [_button(), _button()]),
      ),
      _builder(label: 'Live'),
    ]);
    await _open(tester);

    final group = find.text('Button press ×2');
    expect(
      tester.getTopLeft(find.text('Live')).dy,
      lessThan(
        tester.getTopLeft(group).dy,
      ),
    );
    expect(find.textContaining('Muted'), findsOneWidget);
  });

  testWidgets('hides excluded controllers behind a footer', (tester) async {
    await _pump(tester, [
      _builder(label: 'Shown'),
      MotorInspectionScope(
        inspectable: false,
        child: Column(
          children: [
            _builder(label: 'Spinner'),
            MotorInspectionScope(
              inspectable: true,
              child: _builder(label: 'Opted in'),
            ),
          ],
        ),
      ),
    ]);
    await _open(tester);

    expect(find.text('Shown'), findsOneWidget);
    expect(find.text('Opted in'), findsOneWidget);
    expect(find.text('Spinner'), findsNothing);
    expect(find.text('2 controllers'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-hidden')));
    await _settle(tester);
    expect(find.text('Spinner'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("a controller's own setting beats its scope", (tester) async {
    await _pump(tester, [
      MotorInspectionScope(
        inspectable: false,
        child: _builder(label: 'Pulse'),
      ),
    ]);
    observer.byLabel('Pulse').inspectable = true;
    await _open(tester);

    expect(find.text('Pulse'), findsOneWidget);
    expect(find.byKey(const ValueKey('motor-devtools-hidden')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows a group as one row that opens its members', (
    tester,
  ) async {
    await _pump(tester, [_button(), _button(), _button()]);
    await _open(tester);

    expect(find.text('Button press ×3'), findsOneWidget);
    await tester.tap(find.text('Button press ×3'));
    await _settle(tester);

    expect(find.text('Members'), findsOneWidget);
    expect(find.textContaining('SingleMotionBuilder'), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('motor-devtools-back')));
    await _settle(tester);
    expect(find.text('Button press ×3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('group motion and speed stick to members that join later', (
    tester,
  ) async {
    await _pump(tester, [_button(), _button()]);
    await _open(tester);
    await tester.tap(find.text('Button press ×2'));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('motor-devtools-speed-0.25')));
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-track-All tracks')),
    );
    await _settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('motor-devtools-motion-Spring')),
    );
    await tester.pump();

    await tester.pumpWidget(
      MotorDevTools(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [_button(), _button(), _button()]),
        ),
      ),
    );
    await tester.pump();

    final members = observer.registered
        .where((c) => c.inspectionGroup == 'Button press')
        .toList();
    expect(members, hasLength(3));
    for (final member in members) {
      final track = member.inspectPlayback().tracks.single.track;
      expect(member.motionOverride?.call(track), isA<CupertinoMotion>());
      expect(member.playbackSpeed, 0.25);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('group overrides match tracks by label, else all tracks', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    final scale = _track('scale');
    final opacity = _track('opacity');
    final size = _track('size');
    final unlabeled = _track(null);
    const tuned = Motion.linear(Duration(milliseconds: 50));

    final byLabel = groupMotionResolver(controller, {'scale': tuned});
    expect(byLabel(scale), tuned);
    expect(byLabel(opacity), isNull);

    final other = TrackController(vsync: tester);
    final fallback = groupMotionResolver(other, {'scale': tuned});
    expect(fallback(size), tuned);
    expect(fallback(unlabeled), tuned);

    final all = groupMotionResolver(controller, {null: tuned});
    expect(all(opacity), tuned);

    controller.dispose();
    other.dispose();
  });

  testWidgets('merges same-name controllers and folds idle ones', (
    tester,
  ) async {
    await _pump(tester, [
      _builder(label: 'Pulse'),
      _builder(label: 'Pulse'),
      _builder(label: 'Pulse'),
      SingleMotionBuilder(
        debugLabel: 'Never played',
        value: 1,
        motion: const Motion.smoothSpring(),
        builder: (context, value, child) => const SizedBox(),
      ),
    ]);
    await _settle(tester);
    await _open(tester);

    expect(find.text('Pulse ×3'), findsOneWidget);
    expect(find.text('Pulse 1'), findsNothing);
    await tester.tap(find.text('Pulse ×3'));
    await _settle(tester);
    expect(find.text('Pulse 1'), findsOneWidget);

    expect(find.text('Never played'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-idle')));
    await _settle(tester);
    expect(find.text('Never played'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Observer implements MotorInspectionObserver {
  final registered = <TrackController>[];

  TrackController byLabel(String label) =>
      registered.lastWhere((c) => c.debugLabel == label);

  @override
  void didRegisterController(TrackController controller) =>
      registered.add(controller);

  @override
  void didUnregisterController(TrackController controller) =>
      registered.remove(controller);
}
