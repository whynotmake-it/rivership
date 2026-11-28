import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

/// Far jumps must lay out only what lands in the viewport, however much
/// history the user has scrolled through first.
void main() {
  const viewport = Size(400, 800);
  const count = 3000;

  Future<({TurnScrollController controller, Set<int> built})> pump(
    WidgetTester tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = viewport;
    addTearDown(tester.view.reset);
    final controller = TurnScrollController();
    addTearDown(controller.dispose);
    final built = <int>{};
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: TurnScrollView<int>.sectioned(
            controller: controller,
            itemCount: count,
            itemId: (i) => 'm$i',
            sectionId: (i) => i ~/ 40,
            autoScrollMotion: const CupertinoMotion.smooth(),
            sectionHeaderBuilder: (context, details) =>
                SizedBox(height: 28, child: Text('Day ${details.section}')),
            itemBuilder: (context, i) {
              built.add(i);
              return SizedBox(
                key: ValueKey('box:m$i'),
                height: 40.0 + (i % 5) * 12,
                child: Text('m$i'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (controller: controller, built: built);
  }

  /// Wheels to the very top so every item is laid out (and measured) once.
  Future<void> scrollToTop(
    WidgetTester tester,
    TurnScrollController controller,
  ) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse)
      ..hover(const Offset(200, 400));
    for (var i = 0; i < 400; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -4000)));
      await tester.pump(const Duration(milliseconds: 16));
      final pos = controller.position;
      if (pos.pixels <= pos.minScrollExtent + 0.5) break;
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('box:m0')), findsOneWidget);
  }

  double topOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey('box:$id'))).dy;

  testWidgets('scrollToBottom(animate: false) from the top builds only the '
      'tail', (tester) async {
    final (:controller, :built) = await pump(tester);
    await scrollToTop(tester, controller);

    built.clear();
    final arrived = controller.scrollToBottom(animate: false);
    await tester.pumpAndSettle();
    expect(await arrived, isTrue);

    expect(find.byKey(const ValueKey('box:m${count - 1}')), findsOneWidget);
    expect(controller.distanceFromBottom.value, lessThan(1));
    expect(built.length, lessThan(80));
  });

  testWidgets('long animated scrollToBottom teleports, then glides one '
      'viewport', (tester) async {
    final (:controller, :built) = await pump(tester);
    await scrollToTop(tester, controller);

    built.clear();
    final arrived = controller.scrollToBottom();
    await tester.pump();
    expect(controller.isAutoScrolling.value, isTrue);
    await tester.pumpAndSettle();
    expect(await arrived, isTrue);

    expect(controller.distanceFromBottom.value, lessThan(1));
    expect(built.length, lessThan(120));
  });

  testWidgets('scrollTo a far item, animated or not, builds only around the '
      'target', (tester) async {
    final (:controller, :built) = await pump(tester);

    built.clear();
    final toTop = controller.scrollTo('m5', animate: false);
    await tester.pumpAndSettle();
    expect(await toTop, isTrue);
    expect(topOf(tester, 'm5'), closeTo(28, 1)); // below the sticky header
    expect(built.length, lessThan(80));

    built.clear();
    final toMiddle = controller.scrollTo('m1500');
    await tester.pumpAndSettle();
    expect(await toMiddle, isTrue);
    expect(topOf(tester, 'm1500'), closeTo(28, 1));
    expect(built.length, lessThan(120));
  });
}
