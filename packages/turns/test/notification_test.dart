import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

Future<List<TurnScrollNotification>> _pump(
  WidgetTester tester, {
  required int itemCount,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _viewport;
  addTearDown(tester.view.reset);
  final received = <TurnScrollNotification>[];
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: _viewport),
        child: NotificationListener<TurnScrollNotification>(
          onNotification: (notification) {
            received.add(notification);
            return false;
          },
          child: TurnScrollView(
            itemCount: itemCount,
            itemId: (i) => 'm$i',
            itemBuilder: (context, i) => const SizedBox(height: 100),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return received;
}

void main() {
  testWidgets(
    'a first page shorter than the viewport still reports that both edges '
    'are in view, so edge pagination can start',
    (tester) async {
      final received = await _pump(tester, itemCount: 3);
      expect(received, isNotEmpty);
      expect(received.last.leadingExtent, 0);
      expect(received.last.trailingExtent, 0);
    },
  );

  testWidgets('dragging against a clamped edge is reported', (tester) async {
    final received = await _pump(tester, itemCount: 30);
    final before = received.length;
    // The list opens at the bottom: dragging further up against that edge
    // moves nothing, but the drag still has to be seen.
    await tester.drag(find.byType(TurnScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(received.length, greaterThan(before));
    expect(received.last.trailingExtent, 0);
  });
}
