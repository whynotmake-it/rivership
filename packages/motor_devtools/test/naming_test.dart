import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

void main() {
  testWidgets('names unlabeled controllers after the code that made them', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MotorDevTools(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [_Harness(), _Card()]),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('motor-devtools-launcher')));
    await _settle(tester);

    expect(find.text('Harness · controller'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-idle')));
    await _settle(tester);
    expect(find.text('Card · SingleMotionBuilder'), findsOneWidget);

    await tester.tap(find.text('Harness · controller'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('motor-devtools-tracks')));
    await _settle(tester);
    expect(find.text('double: to 1.00 → hold 100 ms'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _track = Track<double>(MotionConverter.single, initial: 0);

  @override
  void initState() {
    super.initState();
    _controller.play(
      TrackTimeline([
        _track(const [
          TrackStep.to(1, motion: Motion.linear(Duration(seconds: 1))),
          TrackStep.hold(Duration(milliseconds: 100)),
        ]),
      ]),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: 1,
    motion: const Motion.smoothSpring(),
    builder: (context, value, child) => SizedBox(height: value),
  );
}
