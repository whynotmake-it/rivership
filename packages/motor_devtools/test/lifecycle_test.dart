import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_devtools/motor_devtools.dart';

var _mounts = 0;

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    _mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> _pump(WidgetTester tester, Widget child, {bool enabled = true}) =>
    tester.pumpWidget(
      MotorDevTools(
        enabled: enabled,
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      ),
    );

void main() {
  testWidgets('toggling enabled keeps the app subtree', (tester) async {
    _mounts = 0;
    await _pump(tester, const _Counter());
    await _pump(tester, const _Counter(), enabled: false);
    await _pump(tester, const _Counter());
    expect(_mounts, 1);
  });
}
