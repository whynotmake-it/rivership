// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/overflow_padding.dart';

void main() {
  group('$OverflowPadding', () {
    group('positive padding (behaves like Padding)', () {
      testWidgets('renders with uniform positive padding', (tester) async {
        const padding = EdgeInsets.all(20);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingSize = tester.getSize(overflowPaddingFinder);

        // OverflowPadding size should equal child size plus padding
        expect(
          overflowPaddingSize,
          equals(
            Size(
              childSize.width + padding.horizontal,
              childSize.height + padding.vertical,
            ),
          ),
        );
      });

      testWidgets('renders with asymmetric positive padding', (tester) async {
        const padding = EdgeInsets.only(
          left: 10,
          top: 20,
          right: 30,
          bottom: 40,
        );
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingSize = tester.getSize(overflowPaddingFinder);

        expect(
          overflowPaddingSize,
          equals(
            Size(
              childSize.width + padding.horizontal,
              childSize.height + padding.vertical,
            ),
          ),
        );
      });

      testWidgets('compares to standard Padding widget', (tester) async {
        const padding = EdgeInsets.all(30);
        const childSize = Size(80, 120);

        // Test with standard Padding
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Padding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final standardSize = tester.getSize(find.byType(Padding));

        // Test with OverflowPadding
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final extendedSize = tester.getSize(find.byType(OverflowPadding));

        // Should be identical
        expect(extendedSize, equals(standardSize));
      });

      testWidgets('child is positioned correctly with positive padding', (
        tester,
      ) async {
        const padding = EdgeInsets.only(left: 20, top: 30);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: OverflowPadding(
                padding: padding,
                child: Container(width: 50, height: 50, color: Colors.red),
              ),
            ),
          ),
        );

        final containerFinder = find.byType(Container);
        final containerOffset = tester.getTopLeft(containerFinder);

        // Child should be offset by the padding amount
        expect(containerOffset.dx, equals(padding.left));
        expect(containerOffset.dy, equals(padding.top));
      });
    });

    group('negative padding (expands beyond bounds)', () {
      testWidgets('renders with uniform negative padding', (tester) async {
        const padding = EdgeInsets.all(-20);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingSize = tester.getSize(overflowPaddingFinder);

        // OverflowPadding size should be child size minus absolute padding
        // Since padding is -40 total in each direction, child expands beyond
        // bounds
        expect(
          overflowPaddingSize,
          equals(
            Size(
              childSize.width + padding.horizontal,
              childSize.height + padding.vertical,
            ),
          ),
        );

        // Verify the size is smaller than child size
        expect(overflowPaddingSize.width, lessThan(childSize.width));
        expect(overflowPaddingSize.height, lessThan(childSize.height));
      });

      testWidgets('child expands beyond widget bounds with negative padding', (
        tester,
      ) async {
        const padding = EdgeInsets.all(-30);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: OverflowPadding(
                padding: padding,
                child: Container(
                  width: childSize.width,
                  height: childSize.height,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final containerFinder = find.byType(Container);

        final overflowPaddingSize = tester.getSize(overflowPaddingFinder);
        final containerSize = tester.getSize(containerFinder);

        // Container should maintain its full size
        expect(containerSize, equals(childSize));

        // OverflowPadding should be smaller
        expect(overflowPaddingSize.width, equals(childSize.width - 60));
        expect(overflowPaddingSize.height, equals(childSize.height - 60));

        // Container should be larger than OverflowPadding
        expect(containerSize.width, greaterThan(overflowPaddingSize.width));
        expect(containerSize.height, greaterThan(overflowPaddingSize.height));
      });

      testWidgets('child is positioned correctly with negative padding', (
        tester,
      ) async {
        const padding = EdgeInsets.only(left: -20, top: -30);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: OverflowPadding(
                padding: padding,
                child: Container(width: 50, height: 50, color: Colors.red),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final containerFinder = find.byType(Container);

        final overflowPaddingOffset = tester.getTopLeft(overflowPaddingFinder);
        final containerOffset = tester.getTopLeft(containerFinder);

        // Child should be offset by the negative padding (shifted left and up)
        expect(
          containerOffset.dx,
          equals(overflowPaddingOffset.dx + padding.left),
        );
        expect(
          containerOffset.dy,
          equals(overflowPaddingOffset.dy + padding.top),
        );

        // Verify child is actually positioned before the parent's top-left
        expect(containerOffset.dx, lessThan(overflowPaddingOffset.dx));
        expect(containerOffset.dy, lessThan(overflowPaddingOffset.dy));
      });

      testWidgets('renders with asymmetric negative padding', (tester) async {
        const padding = EdgeInsets.only(
          left: -10,
          top: -20,
          right: -30,
          bottom: -40,
        );
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingSize = tester.getSize(overflowPaddingFinder);

        expect(
          overflowPaddingSize,
          equals(
            Size(
              childSize.width + padding.horizontal,
              childSize.height + padding.vertical,
            ),
          ),
        );
      });
    });

    group('mixed positive and negative padding', () {
      testWidgets('handles mixed padding values', (tester) async {
        const padding = EdgeInsets.only(
          left: 20,
          top: -10,
          right: -15,
          bottom: 30,
        );
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingSize = tester.getSize(overflowPaddingFinder);

        expect(
          overflowPaddingSize,
          equals(
            Size(
              childSize.width + padding.horizontal,
              childSize.height + padding.vertical,
            ),
          ),
        );
      });
    });

    group('hit testing', () {
      testWidgets('hit test succeeds within bounds', (tester) async {
        const padding = EdgeInsets.all(-30);
        var tapped = false;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: GestureDetector(
                  onTap: () => tapped = true,
                  child: Container(width: 100, height: 100, color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingCenter = tester.getCenter(overflowPaddingFinder);

        // Tap at the center of OverflowPadding (within its bounds)
        await tester.tapAt(overflowPaddingCenter);
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('OverflowPadding bounds do not include child overflow', (
        tester,
      ) async {
        const padding = EdgeInsets.all(-30);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                child: OverflowPadding(
                  padding: padding,
                  child: Container(
                    width: childSize.width,
                    height: childSize.height,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final containerFinder = find.byType(Container).last;

        final overflowPaddingRect = tester.getRect(overflowPaddingFinder);
        final containerRect = tester.getRect(containerFinder);

        // Verify that the child extends beyond OverflowPadding's bounds
        expect(containerRect.left, lessThan(overflowPaddingRect.left));
        expect(containerRect.top, lessThan(overflowPaddingRect.top));
        expect(containerRect.right, greaterThan(overflowPaddingRect.right));
        expect(containerRect.bottom, greaterThan(overflowPaddingRect.bottom));

        // OverflowPadding's size should be smaller than child
        expect(overflowPaddingRect.width, equals(40)); // 100 - 60
        expect(overflowPaddingRect.height, equals(40)); // 100 - 60
      });

      testWidgets('hit test correctly identifies OverflowPadding bounds', (
        tester,
      ) async {
        const padding = EdgeInsets.only(left: -50);
        final hitResults = <HitTestResult>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                child: OverflowPadding(
                  padding: padding,
                  child: Container(width: 100, height: 100, color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        final overflowPaddingFinder = find.byType(OverflowPadding);
        final overflowPaddingRect = tester.getRect(overflowPaddingFinder);

        // Perform hit test at the center of OverflowPadding (within bounds)
        final centerResult = HitTestResult();
        tester.binding.hitTestInView(
          centerResult,
          overflowPaddingRect.center,
          tester.view.viewId,
        );
        hitResults.add(centerResult);

        // Verify the hit test result includes OverflowPadding
        final hasExtendedPadding = centerResult.path.any(
          (entry) => entry.target.toString().contains('RenderOverflowPadding'),
        );
        expect(hasExtendedPadding, isTrue);

        // Verify OverflowPadding size accounts for negative padding
        expect(overflowPaddingRect.width, equals(50)); // 100 - 50
      });
    });

    group('intrinsic dimensions', () {
      testWidgets(
        'computes min intrinsic width correctly with positive padding',
        (tester) async {
          const padding = EdgeInsets.symmetric(horizontal: 20);
          const childWidth = 100.0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: OverflowPadding(
                  padding: padding,
                  child: SizedBox(width: childWidth, height: 50),
                ),
              ),
            ),
          );

          final renderObject = tester.renderObject<RenderOverflowPadding>(
            find.byType(OverflowPadding),
          );

          // Test intrinsic width method directly
          final minIntrinsicWidth = renderObject.computeMinIntrinsicWidth(50);

          // Width should be child width + horizontal padding
          expect(minIntrinsicWidth, equals(childWidth + padding.horizontal));
        },
      );

      testWidgets(
        'computes min intrinsic width correctly with negative padding',
        (tester) async {
          const padding = EdgeInsets.symmetric(horizontal: -20);
          const childWidth = 100.0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: OverflowPadding(
                  padding: padding,
                  child: SizedBox(width: childWidth, height: 50),
                ),
              ),
            ),
          );

          final renderObject = tester.renderObject<RenderOverflowPadding>(
            find.byType(OverflowPadding),
          );

          // Test intrinsic width method directly
          final minIntrinsicWidth = renderObject.computeMinIntrinsicWidth(50);

          // Width should be child width + horizontal padding (negative),
          // clamped to 0 minimum
          // 100 + (-40) = 60
          expect(minIntrinsicWidth, equals(60));
        },
      );

      testWidgets(
        'computes min intrinsic height correctly with positive padding',
        (tester) async {
          const padding = EdgeInsets.symmetric(vertical: 30);
          const childHeight = 50.0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: OverflowPadding(
                  padding: padding,
                  child: SizedBox(width: 100, height: childHeight),
                ),
              ),
            ),
          );

          final renderObject = tester.renderObject<RenderOverflowPadding>(
            find.byType(OverflowPadding),
          );

          // Test intrinsic height method directly
          final minIntrinsicHeight = renderObject.computeMinIntrinsicHeight(
            100,
          );

          // Height should be child height + vertical padding
          expect(minIntrinsicHeight, equals(childHeight + padding.vertical));
        },
      );

      testWidgets(
        'computes min intrinsic height correctly with negative padding',
        (tester) async {
          const padding = EdgeInsets.symmetric(vertical: -10);
          const childHeight = 50.0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: OverflowPadding(
                  padding: padding,
                  child: SizedBox(width: 100, height: childHeight),
                ),
              ),
            ),
          );

          final renderObject = tester.renderObject<RenderOverflowPadding>(
            find.byType(OverflowPadding),
          );

          // Test intrinsic height method directly
          final minIntrinsicHeight = renderObject.computeMinIntrinsicHeight(
            100,
          );

          // Height should be child height + vertical padding (negative),
          //clamped to 0 minimum
          // 50 + (-20) = 30
          expect(minIntrinsicHeight, equals(30));
        },
      );
    });

    group('edge cases', () {
      testWidgets('handles null child', (tester) async {
        const padding = EdgeInsets.all(20);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: OverflowPadding(padding: padding)),
          ),
        );

        final overflowPaddingSize = tester.getSize(
          find.byType(OverflowPadding),
        );

        // With no child, size should be just the padding
        expect(overflowPaddingSize.width, equals(40));
        expect(overflowPaddingSize.height, equals(40));
      });

      testWidgets('handles null child with negative padding', (tester) async {
        const padding = EdgeInsets.all(-20);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: OverflowPadding(padding: padding)),
          ),
        );

        final overflowPaddingSize = tester.getSize(
          find.byType(OverflowPadding),
        );

        // With no child and negative padding, size should be zero (clamped)
        expect(overflowPaddingSize.width, equals(0));
        expect(overflowPaddingSize.height, equals(0));
      });

      testWidgets('handles zero padding', (tester) async {
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: EdgeInsets.zero,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingSize = tester.getSize(
          find.byType(OverflowPadding),
        );

        // Size should equal child size
        expect(overflowPaddingSize, equals(childSize));
      });

      testWidgets('extreme negative padding results in zero size', (
        tester,
      ) async {
        const padding = EdgeInsets.all(-200);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: padding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        final overflowPaddingSize = tester.getSize(
          find.byType(OverflowPadding),
        );

        // Size should be clamped to zero (not negative)
        expect(overflowPaddingSize.width, equals(0));
        expect(overflowPaddingSize.height, equals(0));
      });
    });

    group('directionality', () {
      testWidgets('respects text direction for EdgeInsetsDirectional', (
        tester,
      ) async {
        const padding = EdgeInsetsDirectional.only(start: 20, end: 40);
        const childSize = Size(100, 100);

        // Test LTR
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: OverflowPadding(
                padding: padding,
                child: Container(
                  width: childSize.width,
                  height: childSize.height,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        final ltrContainerOffset = tester.getTopLeft(find.byType(Container));
        expect(ltrContainerOffset.dx, equals(20)); // start = left in LTR

        // Test RTL
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.topRight,
              child: OverflowPadding(
                padding: padding,
                child: Container(
                  width: childSize.width,
                  height: childSize.height,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        final screenWidth =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final rtlContainerOffset = tester.getTopLeft(find.byType(Container));

        // In RTL, start = right, so container should be offset from right edge
        expect(
          rtlContainerOffset.dx,
          equals(screenWidth - childSize.width - 20),
        );
      });

      testWidgets(
        'respects text direction for negative EdgeInsetsDirectional',
        (tester) async {
          const padding = EdgeInsetsDirectional.only(start: -30);
          const childSize = Size(100, 100);

          // Test LTR
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: OverflowPadding(
                  padding: padding,
                  child: Container(
                    width: childSize.width,
                    height: childSize.height,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          );

          final ltrOverflowPaddingOffset = tester.getTopLeft(
            find.byType(OverflowPadding),
          );
          final ltrContainerOffset = tester.getTopLeft(find.byType(Container));

          // In LTR, negative start padding shifts child left (negative offset)
          expect(
            ltrContainerOffset.dx,
            equals(ltrOverflowPaddingOffset.dx - 30),
          );
        },
      );
    });

    group('updates', () {
      testWidgets('updates when padding changes', (tester) async {
        const initialPadding = EdgeInsets.all(20);
        const updatedPadding = EdgeInsets.all(40);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: initialPadding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        var overflowPaddingSize = tester.getSize(find.byType(OverflowPadding));
        expect(overflowPaddingSize.width, equals(140));

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: updatedPadding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        overflowPaddingSize = tester.getSize(find.byType(OverflowPadding));
        expect(overflowPaddingSize.width, equals(180));
      });

      testWidgets('updates when switching from positive to negative padding', (
        tester,
      ) async {
        const positivePadding = EdgeInsets.all(20);
        const negativePadding = EdgeInsets.all(-20);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: positivePadding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        var overflowPaddingSize = tester.getSize(find.byType(OverflowPadding));
        expect(overflowPaddingSize.width, equals(140));
        expect(overflowPaddingSize.height, equals(140));

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: OverflowPadding(
                padding: negativePadding,
                child: SizedBox.fromSize(size: childSize),
              ),
            ),
          ),
        );

        overflowPaddingSize = tester.getSize(find.byType(OverflowPadding));
        expect(overflowPaddingSize.width, equals(60));
        expect(overflowPaddingSize.height, equals(60));
      });

      testWidgets('updates when text direction changes', (tester) async {
        const padding = EdgeInsetsDirectional.only(start: 50);
        const childSize = Size(100, 100);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: OverflowPadding(
                padding: padding,
                child: Container(
                  width: childSize.width,
                  height: childSize.height,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        final ltrContainerOffset = tester.getTopLeft(find.byType(Container));

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.topLeft,
              child: OverflowPadding(
                padding: padding,
                child: Container(
                  width: childSize.width,
                  height: childSize.height,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        final rtlContainerOffset = tester.getTopLeft(find.byType(Container));

        // Offsets should be different in RTL vs LTR
        expect(ltrContainerOffset.dx, isNot(equals(rtlContainerOffset.dx)));
      });
    });
  });
}
