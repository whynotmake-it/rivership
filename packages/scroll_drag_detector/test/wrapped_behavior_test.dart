import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

class _Plain extends ScrollBehavior {
  const _Plain();
}

void main() {
  const modes = ScrollDragMode.values;
  for (final wrapped in [true, false]) {
    for (final vMode in modes) {
      for (final hMode in modes) {
        for (final scrollAxis in Axis.values) {
          testWidgets(
            '${wrapped ? 'copyWith' : 'plain subclass'} parent, '
            'vertical $vMode, horizontal $hMode, $scrollAxis list: '
            'drags in every direction end cleanly',
            (tester) async {
              await tester.pumpWidget(
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Builder(
                    builder: (context) => ScrollConfiguration(
                      behavior: wrapped
                          ? ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false)
                          : const _Plain(),
                      child: ScrollDragDetector(
                        up: vMode,
                        down: vMode,
                        left: hMode,
                        right: hMode,
                        onVerticalDragUpdate: (_, __) {},
                        onHorizontalDragUpdate: (_, __) {},
                        child: ListView.builder(
                          scrollDirection: scrollAxis,
                          itemCount: 50,
                          itemBuilder: (_, i) =>
                              SizedBox.square(dimension: 60, child: Text('$i')),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              for (final delta in const [
                Offset(0, -200),
                Offset(0, 200),
                Offset(-200, 0),
                Offset(200, 0),
                Offset(150, -150),
              ]) {
                final g = await tester.startGesture(const Offset(400, 300));
                for (var i = 0; i < 10; i++) {
                  await g.moveBy(delta / 10);
                  await tester.pump(const Duration(milliseconds: 16));
                }
                await g.up();
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
