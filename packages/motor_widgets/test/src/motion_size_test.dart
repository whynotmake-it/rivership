import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

import '../util.dart';

const _spring = CupertinoMotion.smooth();

double _width(WidgetTester tester) =>
    tester.getSize(find.byType(MotionSize)).width;

Widget _topLeft(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  testWidgets(
    'MotionSize springs when its content changes, but follows its room',
    (tester) async {
      // A content change springs.
      Widget content(double width) => _topLeft(
        MotionSize(
          motion: _spring,
          child: SizedBox(width: width, height: 20),
        ),
      );
      await tester.pumpWidget(content(100));
      await tester.pumpWidget(content(200));
      await tester.pump(frame);
      await tester.pump(frame);
      expect(_width(tester), inExclusiveRange(100, 200));
      await tester.pumpAndSettle();
      expect(_width(tester), 200);

      // A parent resize that changes the child's size lands at once.
      Widget resized(double room) => _topLeft(
        SizedBox(
          width: room,
          child: Align(
            alignment: Alignment.topLeft,
            child: MotionSize(
              motion: _spring,
              // A child that fills half the room it is given.
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    SizedBox(width: constraints.maxWidth / 2, height: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(resized(400));
      await tester.pumpWidget(resized(200));
      expect(_width(tester), 100);
      await tester.pump(frame);
      expect(_width(tester), 100);

      // A sibling taking room, which leaves the child's size alone, doesn't
      // cut a spring in flight short.
      Widget row({required double content, required double sibling}) =>
          _topLeft(
            SizedBox(
              width: 400,
              child: Row(
                children: [
                  Flexible(
                    child: MotionSize(
                      motion: _spring,
                      child: SizedBox(width: content, height: 20),
                    ),
                  ),
                  SizedBox(width: sibling, height: 20),
                ],
              ),
            ),
          );
      await tester.pumpWidget(row(content: 100, sibling: 0));
      await tester.pumpWidget(row(content: 300, sibling: 0));
      await tester.pump(frame);
      await tester.pump(frame);
      final midway = _width(tester);
      expect(midway, inExclusiveRange(100, 300));
      await tester.pumpWidget(row(content: 300, sibling: 50));
      expect(_width(tester), lessThan(300));
      await tester.pump(frame);
      expect(_width(tester), greaterThan(midway));
      expect(_width(tester), lessThan(300));
      await tester.pumpAndSettle();
      expect(_width(tester), 300);
    },
  );
}
