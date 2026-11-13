import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

class _Host extends StatefulWidget {
  const _Host({required this.controller, this.presentation});

  final CoilPopupController controller;
  final CoilPresentation? presentation;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? value = 'banana';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 220,
        child: CoilSelect<String>(
          key: const ValueKey('select'),
          options: fruits,
          value: value,
          presentation: widget.presentation,
          controller: widget.controller,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    ),
  );
}

Future<CoilPopupController> _pump(
  WidgetTester tester, {
  CoilPresentation? presentation,
  CoilTier tier = CoilTier.pointer,
}) async {
  useScreen(
    tester,
    tier == CoilTier.pointer ? TestScreen.desktop : TestScreen.phone,
  );
  final controller = CoilPopupController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    testApp(
      home: _Host(controller: controller, presentation: presentation),
      tier: tier,
    ),
  );
  return controller;
}

void main() {
  testWidgets('open() resolves once with selected; isOpen follows', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final opens = <bool>[];
    controller.addListener(() => opens.add(controller.isOpen));
    final first = controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    // While open, open() hands back the same future.
    expect(identical(controller.open(), first), isTrue);

    await tester.tap(find.text('Cherry'), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(await first, CoilPopupCloseReason.selected);
    expect(controller.isOpen, isFalse);
    expect(opens, [true, false]);
    expect(find.text('Cherry'), findsOneWidget, reason: 'trigger shows it');
  });

  testWidgets('Escape resolves with escape', (tester) async {
    final controller = await _pump(tester);
    final closed = controller.open();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await closed, CoilPopupCloseReason.escape);
  });

  testWidgets('Tab resolves with dismissed', (tester) async {
    final controller = await _pump(tester);
    final closed = controller.open();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(await closed, CoilPopupCloseReason.dismissed);
  });

  testWidgets('an outside tap closes on tap-up with outsideTap', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final closed = controller.open();
    await tester.pumpAndSettle();
    final finger = await tester.startGesture(const Offset(400, 420));
    await tester.pump();
    expect(controller.isOpen, isTrue, reason: 'still open on tap-down');
    await finger.up();
    await tester.pumpAndSettle();
    expect(await closed, CoilPopupCloseReason.outsideTap);
  });

  testWidgets('close() resolves with programmatic', (tester) async {
    final controller = await _pump(tester);
    final closed = controller.open();
    await tester.pumpAndSettle();
    controller.close();
    await tester.pumpAndSettle();
    expect(await closed, CoilPopupCloseReason.programmatic);
    expect(find.byType(CoilSheetPanel), findsNothing);
  });

  testWidgets('a sheet scrim tap is outsideTap; a user open reports too', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      presentation: CoilPresentation.sheet,
      tier: CoilTier.touch,
    );
    // Opened by the user, not the controller: the controller still sees it.
    await tester.tap(find.byKey(const ValueKey('select')));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    final closed = controller.open();
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(await closed, CoilPopupCloseReason.outsideTap);
    expect(find.byType(CoilSheetPanel), findsNothing);
  });
}
