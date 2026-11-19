import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));
final _panel = find.byKey(const ValueKey('motor-devtools-panel'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
  });

  testWidgets('opens, closes and toggles the panel from code', (tester) async {
    final devTools = MotorDevToolsController();
    addTearDown(devTools.dispose);
    await tester.pumpWidget(
      MotorDevTools(
        controller: devTools,
        child: const _Harness(),
      ),
    );
    await _settle(tester);
    expect(_panel, findsNothing);

    devTools.open();
    await _settle(tester);
    expect(devTools.isOpen, isTrue);
    expect(_panel, findsOneWidget);
    expect(find.text('1 controller'), findsOneWidget);

    devTools.close();
    await _settle(tester);
    expect(devTools.isOpen, isFalse);
    expect(_panel, findsNothing);
    expect(_launcher, findsOneWidget);

    devTools.toggle();
    await _settle(tester);
    expect(devTools.isOpen, isTrue);
    expect(_panel, findsOneWidget);

    devTools.toggle();
    await _settle(tester);
    expect(devTools.isOpen, isFalse);
    expect(_panel, findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a listener above the tools survives enabled changing', (
    tester,
  ) async {
    final devTools = MotorDevToolsController();
    addTearDown(devTools.dispose);
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    var builds = 0;
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: Listenable.merge([devTools, enabled]),
        builder: (context, _) {
          builds++;
          return MotorDevTools(
            controller: devTools,
            enabled: enabled.value,
            child: const _Harness(),
          );
        },
      ),
    );
    devTools.open();
    await _settle(tester);
    expect(_panel, findsOneWidget);

    enabled.value = false;
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_panel, findsNothing);
    expect(_launcher, findsNothing);

    expect(devTools.isOpen, isFalse);

    enabled.value = true;
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_launcher, findsOneWidget);

    devTools.open();
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_panel, findsOneWidget);
    expect(builds, greaterThan(3));

    await tester.pumpWidget(const SizedBox());
  });
}

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  late final TrackController controller;

  @override
  void initState() {
    super.initState();
    controller = TrackController(vsync: this, debugLabel: 'Harness');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
