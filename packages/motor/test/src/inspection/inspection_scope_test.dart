import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

void main() {
  late _Observer observer;
  late MotorInspectionSubscription subscription;
  setUp(() {
    observer = _Observer();
    subscription = MotorInspectionRegistry.attach(observer);
  });
  tearDown(() => subscription.dispose());

  TrackController byLabel(String label) =>
      observer.registered.firstWhere((c) => c.debugLabel == label);

  Widget builder(String label) => SingleMotionBuilder(
        debugLabel: label,
        value: 1,
        motion: const Motion.smoothSpring(),
        builder: (context, value, child) => const SizedBox(),
      );

  testWidgets('scopes apply to builders below, the nearest value wins', (
    tester,
  ) async {
    await tester.pumpWidget(
      Column(
        children: [
          builder('outside'),
          MotorInspectionScope(
            group: 'Buttons',
            inspectable: false,
            child: Column(
              children: [
                builder('hidden'),
                MotorInspectionScope(
                  inspectable: true,
                  child: builder('shown'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    expect(byLabel('outside').inspectable, isTrue);
    expect(byLabel('outside').inspectionGroup, isNull);
    expect(byLabel('hidden').inspectable, isFalse);
    expect(byLabel('hidden').inspectionGroup, 'Buttons');
    expect(byLabel('shown').inspectable, isTrue);
    expect(byLabel('shown').inspectionGroup, 'Buttons');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("a controller's own setting beats its scope", (tester) async {
    await tester.pumpWidget(
      MotorInspectionScope(
        group: 'Buttons',
        inspectable: false,
        child: builder('button'),
      ),
    );
    final controller = byLabel('button')
      ..inspectable = true
      ..inspectionGroup = 'Primary';
    expect(controller.inspectable, isTrue);
    expect(controller.inspectionGroup, 'Primary');

    controller
      ..inspectable = null
      ..inspectionGroup = null;
    expect(controller.inspectable, isFalse);
    expect(controller.inspectionGroup, 'Buttons');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('motion controllers forward their settings', (tester) async {
    final controller = SingleMotionController(
      motion: const Motion.smoothSpring(),
      vsync: tester,
    )
      ..inspectable = false
      ..inspectionGroup = 'Press';

    final inner = observer.registered.single;
    expect(inner.inspectable, isFalse);
    expect(inner.inspectionGroup, 'Press');
    expect(controller.inspectable, isFalse);
    controller.dispose();
  });

  testWidgets('settings are ignored while no tool is attached', (
    tester,
  ) async {
    subscription.dispose();
    final controller = TrackController(vsync: tester)
      ..inspectable = false
      ..inspectionGroup = 'Press';

    expect(controller.inspectable, isTrue);
    expect(controller.inspectionGroup, isNull);
    controller.dispose();
    subscription = MotorInspectionRegistry.attach(observer);
  });
}

class _Observer implements MotorInspectionObserver {
  final registered = <TrackController>[];

  @override
  void didRegisterController(TrackController controller) =>
      registered.add(controller);

  @override
  void didUnregisterController(TrackController controller) {}
}
