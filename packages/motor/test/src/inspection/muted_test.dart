import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets('isMuted follows the TickerMode above the vsync', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    Widget build({required bool enabled}) => TickerMode(
          enabled: enabled,
          child: _Host(key: key),
        );

    await tester.pumpWidget(build(enabled: true));
    final controller = key.currentState!.controller;
    expect(controller.isMuted, isFalse);

    await tester.pumpWidget(build(enabled: false));
    expect(controller.isMuted, isTrue);

    await tester.pumpWidget(build(enabled: true));
    expect(controller.isMuted, isFalse);
  });

  test('isMuted is false once disposed', () {
    final controller = TrackController(vsync: const TestVSync())..dispose();
    expect(controller.isMuted, isFalse);
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final controller = TrackController(vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
