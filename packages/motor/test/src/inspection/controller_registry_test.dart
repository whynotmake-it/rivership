import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets('reports named controller creation and disposal', (tester) async {
    final observer = _RecordingObserver();
    final subscription = MotorInspectionRegistry.attach(observer);
    final controller = TrackController(
      vsync: tester,
      debugLabel: 'Checkout confirmation',
    );

    expect(observer.registered, [controller]);
    expect(controller.debugLabel, 'Checkout confirmation');

    controller.dispose();
    expect(observer.unregistered, [controller]);
    subscription.dispose();
    expect(MotorInspectionRegistry.hasObservers, isFalse);
  });

  testWidgets('a later observer receives controllers held by active tooling', (
    tester,
  ) async {
    final first = _RecordingObserver();
    final firstSubscription = MotorInspectionRegistry.attach(first);
    final controller = TrackController(vsync: tester);
    final second = _RecordingObserver();
    final secondSubscription = MotorInspectionRegistry.attach(second);

    expect(second.registered, [controller]);

    secondSubscription.dispose();
    controller.dispose();
    firstSubscription.dispose();
  });

  testWidgets('motion controllers forward their debug label', (tester) async {
    final observer = _RecordingObserver();
    final subscription = MotorInspectionRegistry.attach(observer);
    final controller = SingleMotionController(
      motion: const Motion.linear(Duration(milliseconds: 100)),
      vsync: tester,
      debugLabel: 'Primary CTA',
    );

    expect(observer.registered.single.debugLabel, 'Primary CTA');
    expect(
      observer.registered.single.inspectPlayback().tracks,
      isEmpty,
    );

    controller.dispose();
    subscription.dispose();
  });
}

class _RecordingObserver implements MotorInspectionObserver {
  final registered = <TrackController>[];
  final unregistered = <TrackController>[];

  @override
  void didRegisterController(TrackController controller) {
    registered.add(controller);
  }

  @override
  void didUnregisterController(TrackController controller) {
    unregistered.add(controller);
  }
}
