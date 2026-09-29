import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/widgets/layout/padding_extended.dart';

void main() {
  group('PaddingExtended', () {
    const childKey = Key('child');
    const childSize = Size(100, 100);

    Widget build(
      EdgeInsetsGeometry padding, {
      TextDirection direction = TextDirection.ltr,
      Widget? child = const SizedBox(
        key: childKey,
        width: 100,
        height: 100,
      ),
    }) =>
        Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topLeft,
            child: PaddingExtended(padding: padding, child: child),
          ),
        );

    Size ownSize(WidgetTester tester) =>
        tester.getSize(find.byType(PaddingExtended));

    Offset childOffset(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(childKey)) -
        tester.getTopLeft(find.byType(PaddingExtended));

    testWidgets('sizes itself to child plus padding and offsets the child',
        (tester) async {
      const ltr = TextDirection.ltr;
      const rtl = TextDirection.rtl;
      for (final (name, padding, direction, size, offset)
          in const <(String, EdgeInsetsGeometry, TextDirection, Size, Offset)>[
        (
          'uniform positive',
          EdgeInsets.all(20),
          ltr,
          Size(140, 140),
          Offset(20, 20)
        ),
        (
          'uniform negative',
          EdgeInsets.all(-20),
          ltr,
          Size(60, 60),
          Offset(-20, -20)
        ),
        ('zero', EdgeInsets.zero, ltr, Size(100, 100), Offset.zero),
        (
          'asymmetric positive',
          EdgeInsets.fromLTRB(10, 20, 30, 40),
          ltr,
          Size(140, 160),
          Offset(10, 20)
        ),
        (
          'asymmetric negative',
          EdgeInsets.fromLTRB(-10, -20, -30, -40),
          ltr,
          Size(60, 40),
          Offset(-10, -20)
        ),
        (
          'negative leading edges',
          EdgeInsets.only(left: -20, top: -30),
          ltr,
          Size(80, 70),
          Offset(-20, -30)
        ),
        (
          'mixed signs',
          EdgeInsets.fromLTRB(20, -10, -15, 30),
          ltr,
          Size(105, 120),
          Offset(20, -10)
        ),
        (
          'negative beyond the child clamps to zero',
          EdgeInsets.all(-200),
          ltr,
          Size.zero,
          Offset(-200, -200)
        ),
        (
          'directional in ltr',
          EdgeInsetsDirectional.only(start: 20, end: 40),
          ltr,
          Size(160, 100),
          Offset(20, 0)
        ),
        (
          'directional in rtl',
          EdgeInsetsDirectional.only(start: 20, end: 40),
          rtl,
          Size(160, 100),
          Offset(40, 0)
        ),
        (
          'negative directional in ltr',
          EdgeInsetsDirectional.only(start: -30),
          ltr,
          Size(70, 100),
          Offset(-30, 0)
        ),
        (
          'negative directional in rtl',
          EdgeInsetsDirectional.only(start: -30),
          rtl,
          Size(70, 100),
          Offset.zero
        ),
      ]) {
        await tester.pumpWidget(build(padding, direction: direction));
        expect(ownSize(tester), size, reason: name);
        expect(childOffset(tester), offset, reason: name);
      }
    });

    testWidgets('sizes itself to the clamped padding without a child',
        (tester) async {
      for (final (padding, size) in [
        (const EdgeInsets.all(20), const Size(40, 40)),
        (const EdgeInsets.all(-20), Size.zero),
      ]) {
        await tester.pumpWidget(build(padding, child: null));
        expect(ownSize(tester), size, reason: '$padding');
      }
    });

    testWidgets('computes min intrinsics including negative padding',
        (tester) async {
      for (final (padding, dimension, expected) in [
        (const EdgeInsets.symmetric(horizontal: 20), Axis.horizontal, 140.0),
        (const EdgeInsets.symmetric(horizontal: -20), Axis.horizontal, 60.0),
        (const EdgeInsets.symmetric(horizontal: -100), Axis.horizontal, 0.0),
        (const EdgeInsets.symmetric(vertical: 30), Axis.vertical, 110.0),
        (const EdgeInsets.symmetric(vertical: -10), Axis.vertical, 30.0),
      ]) {
        await tester.pumpWidget(
          build(padding, child: const SizedBox(width: 100, height: 50)),
        );
        final renderObject = tester.renderObject<RenderPaddingExtended>(
          find.byType(PaddingExtended),
        );
        final actual = switch (dimension) {
          Axis.horizontal => renderObject.computeMinIntrinsicWidth(50),
          Axis.vertical => renderObject.computeMinIntrinsicHeight(100),
        };
        expect(actual, expected, reason: '$padding');
      }
    });

    testWidgets('hit tests only within its own bounds, not the overflow',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        build(
          const EdgeInsets.all(-30),
          child: GestureDetector(
            onTap: () => taps++,
            child: Container(
              key: childKey,
              width: 100,
              height: 100,
              color: const Color(0xFF2196F3),
            ),
          ),
        ),
      );

      final bounds = tester.getRect(find.byType(PaddingExtended));
      final childRect = tester.getRect(find.byKey(childKey));
      expect(bounds.size, const Size(40, 40));
      expect(childRect.size, childSize);

      final result = HitTestResult();
      tester.binding.hitTestInView(result, bounds.center, tester.view.viewId);
      expect(
        result.path.map((entry) => entry.target),
        contains(isA<RenderPaddingExtended>()),
      );

      await tester.tapAt(bounds.center);
      expect(taps, 1);

      await tester.tapAt(childRect.bottomRight - const Offset(5, 5));
      expect(taps, 1, reason: 'The overflowing part of the child is not hit.');
    });

    testWidgets('relayouts when padding or text direction changes',
        (tester) async {
      for (final (padding, direction, size, offset) in [
        (const EdgeInsets.all(20), TextDirection.ltr, 140.0, 20.0),
        (const EdgeInsets.all(40), TextDirection.ltr, 180.0, 40.0),
        (const EdgeInsets.all(-20), TextDirection.ltr, 60.0, -20.0),
      ]) {
        await tester.pumpWidget(build(padding, direction: direction));
        expect(ownSize(tester), Size(size, size), reason: '$padding');
        expect(childOffset(tester), Offset(offset, offset), reason: '$padding');
      }

      const directional = EdgeInsetsDirectional.only(start: 50);
      await tester.pumpWidget(build(directional));
      expect(childOffset(tester), const Offset(50, 0));
      await tester.pumpWidget(build(directional, direction: TextDirection.rtl));
      expect(childOffset(tester), Offset.zero);
      expect(ownSize(tester), const Size(150, 100));
    });
  });
}
