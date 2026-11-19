import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('MotionPadding', () {
    const motion = Motion.linear(Duration(milliseconds: 100));
    const child = SizedBox(key: Key('child'), width: 10, height: 10);

    Widget build(EdgeInsetsGeometry padding, {TextDirection? direction}) =>
        Directionality(
          textDirection: direction ?? TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: MotionPadding(
              motion: motion,
              padding: padding,
              child: child,
            ),
          ),
        );

    Offset childOffset(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('child')));

    testWidgets('animates to a new padding', (tester) async {
      await tester.pumpWidget(build(EdgeInsets.zero));
      expect(childOffset(tester), Offset.zero);

      await tester.pumpWidget(build(const EdgeInsets.only(left: 20, top: 40)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final halfway = childOffset(tester);
      expect(halfway.dx, closeTo(10, error));
      expect(halfway.dy, closeTo(20, error));

      await tester.pumpAndSettle();
      expect(childOffset(tester), const Offset(20, 40));
    });

    testWidgets('applies directional padding on the start side',
        (tester) async {
      const padding = EdgeInsetsDirectional.only(start: 20);

      await tester.pumpWidget(build(padding));
      expect(childOffset(tester), const Offset(20, 0));

      await tester.pumpWidget(build(padding, direction: TextDirection.rtl));
      expect(childOffset(tester), Offset.zero);
      expect(tester.getSize(find.byType(MotionPadding)).width, 30);
    });

    testWidgets('allows negative padding', (tester) async {
      await tester.pumpWidget(build(const EdgeInsets.only(left: 30)));
      await tester.pumpWidget(build(const EdgeInsets.only(left: -5)));
      await tester.pumpAndSettle();
      expect(childOffset(tester), const Offset(-5, 0));
    });
  });
}
