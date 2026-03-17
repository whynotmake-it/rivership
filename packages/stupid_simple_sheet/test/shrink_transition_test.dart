import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
  group('$ShrinkTransition', () {
    const childKey = Key('child');

    Widget build({
      required Widget child,
      double sizeFactor = 1.0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ShrinkTransition(
            sizeFactor: sizeFactor,
            child: child,
          ),
        ),
      );
    }

    testWidgets(
      'supports scroll view with header and footer',
      (tester) async {
        const headerHeight = 100.0;
        const footerHeight = 50.0;
        const headerKey = Key('header');
        const footerKey = Key('footer');
        final child = Column(
          key: childKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              key: headerKey,
              height: headerHeight,
              child: Placeholder(),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemBuilder: (context, index) =>
                    ListTile(title: Text('Item $index')),
              ),
            ),
            const SizedBox(
              key: footerKey,
              height: footerHeight,
              child: Placeholder(),
            ), // footer
          ],
        );

        await tester.pumpWidget(build(child: child));

        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byKey(headerKey)).height,
          equals(headerHeight),
        );
        expect(
          tester.getSize(find.byKey(footerKey)).height,
          equals(footerHeight),
        );
        expect(
          tester.getSize(find.byKey(childKey)).height,
          equals(600),
        );

        await tester.pumpWidget(build(child: child, sizeFactor: 0.1));
        await tester.pumpAndSettle();

        // Header and footer will not shrink
        expect(
          tester.getSize(find.byKey(headerKey)).height,
          equals(headerHeight),
        );
        expect(
          tester.getSize(find.byKey(footerKey)).height,
          equals(footerHeight),
        );

        // The child column collapses to header + footer height (the
        // Expanded scrollable gets 0 height) because targetHeight
        // (0.1 × 600 = 60) is below that minimum.
        final childRect = tester.getRect(find.byKey(childKey));
        expect(
          childRect.height,
          equals(headerHeight + footerHeight),
        );

        // The ShrinkTransition clips the top — only the bottom
        // 60 px (10 % of 600) of the child are visible.
        final shrinkSize = tester.getSize(find.byType(ShrinkTransition));
        expect(shrinkSize.height, equals(600 * 0.1));
      },
    );

    testWidgets('aligns to bottom', (tester) async {
      // When nested inside a Column(mainAxisAlignment: end) — which
      // is how the sheet route uses it — the child's bottom stays
      // pinned to the screen edge.
      const child = SizedBox.expand(
        child: Placeholder(
          key: childKey,
        ),
      );

      Widget buildBottomAligned({double sizeFactor = 1.0}) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: ShrinkTransition(
                    sizeFactor: sizeFactor,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildBottomAligned());

      final rect1 = tester.getRect(find.byKey(childKey));
      expect(rect1.top, equals(0));
      expect(rect1.bottom, equals(600));

      await tester.pumpWidget(buildBottomAligned(sizeFactor: .5));
      await tester.pumpAndSettle();
      await snap();
      final rect2 = tester.getRect(find.byKey(childKey));
      expect(rect2.top, equals(300));
      expect(rect2.bottom, equals(600));
    });

    testWidgets('does not force child to fill height', (tester) async {
      const childHeight = 200.0;
      const child = SizedBox(
        height: childHeight,
        child: Placeholder(
          key: childKey,
        ),
      );

      await tester.pumpWidget(build(child: child));

      final rect1 = tester.getRect(find.byKey(childKey));
      expect(rect1.height, equals(childHeight));
    });

    testWidgets('renders without error when there is no child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShrinkTransition(
              key: Key('shrink'),
              sizeFactor: 1,
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const Key('shrink')));
      expect(size.height, equals(0));
      expect(size.width, equals(0));
    });

    testWidgets('sizeFactor 0 collapses child with no min intrinsic height',
        (tester) async {
      const child = SizedBox.expand(
        child: Placeholder(key: childKey),
      );

      await tester.pumpWidget(build(child: child, sizeFactor: 0));
      await tester.pumpAndSettle();

      final shrinkSize = tester.getSize(find.byType(ShrinkTransition));
      expect(shrinkSize.height, equals(0));
    });

    testWidgets('sizeFactor > 1.0 does not overflow or error', (tester) async {
      const child = SizedBox.expand(
        child: Placeholder(key: childKey),
      );

      await tester.pumpWidget(build(child: child, sizeFactor: 1.2));
      await tester.pumpAndSettle();

      // Clamped to the parent constraints — no visual overflow
      final shrinkSize = tester.getSize(find.byType(ShrinkTransition));
      expect(shrinkSize.height, equals(600));
    });

    testWidgets('smoothly transitions between multiple sizeFactor values',
        (tester) async {
      const child = SizedBox.expand(
        child: Placeholder(key: childKey),
      );

      Widget buildBottomAligned({double sizeFactor = 1.0}) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: ShrinkTransition(
                    sizeFactor: sizeFactor,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildBottomAligned());
      final fullRect = tester.getRect(find.byKey(childKey));
      expect(fullRect.top, equals(0));
      expect(fullRect.bottom, equals(600));

      await tester.pumpWidget(buildBottomAligned(sizeFactor: 0.25));
      await tester.pumpAndSettle();
      final quarterRect = tester.getRect(find.byKey(childKey));
      expect(quarterRect.top, equals(450));
      expect(quarterRect.bottom, equals(600));
    });

    testWidgets('shrinks a child that is shorter than the available space',
        (tester) async {
      const childHeight = 200.0;
      const child = SizedBox(
        height: childHeight,
        child: Placeholder(key: childKey),
      );

      // At sizeFactor 1.0, the visible area is the child's natural height
      await tester.pumpWidget(build(child: child));
      final fullSize = tester.getSize(find.byType(ShrinkTransition));
      expect(fullSize.height, equals(childHeight));

      // sizeFactor scales from the child's natural height, not from
      // the full constraint. 0.5 × 200 = 100.
      await tester.pumpWidget(build(child: child, sizeFactor: 0.5));
      await tester.pumpAndSettle();
      final halfSize = tester.getSize(find.byType(ShrinkTransition));
      expect(halfSize.height, equals(childHeight * 0.5));

      // 0.1 × 200 = 20
      await tester.pumpWidget(build(child: child, sizeFactor: 0.1));
      await tester.pumpAndSettle();
      final smallSize = tester.getSize(find.byType(ShrinkTransition));
      expect(smallSize.height, equals(childHeight * 0.1));
    });

    testWidgets(
      'referenceHeight is the child natural height, not the constraint',
      (tester) async {
        // A 200 px child inside a 600 px Scaffold body. The reference
        // height must be 200 (the child) so that drag normalisation
        // maps a 200 px drag to the full 0→1 range.
        double? capturedHeight;
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShrinkTransition(
                sizeFactor: 1,
                child: SizedBox(
                  height: 200,
                  child: Builder(
                    builder: (context) {
                      capturedContext = context;
                      return const Placeholder();
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        // Read after layout has set _referenceHeight.
        capturedHeight = ShrinkTransition.referenceHeightOf(capturedContext);
        expect(capturedHeight, equals(200));
      },
    );

    testWidgets(
      'child is pushed out the bottom once it hits its '
      'min intrinsic height',
      (tester) async {
        // Column with 100 px header + 50 px footer = 150 px min.
        // At sizeFactor 0.05 the target is 30 px (below min).
        // The child can't shrink below 150, so the ShrinkTransition
        // clips from the bottom: the header stays visible, the
        // footer is pushed off-screen.
        const headerKey = Key('header');
        const footerKey = Key('footer');

        Widget buildBottomAligned({double sizeFactor = 1.0}) {
          return MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: ShrinkTransition(
                      sizeFactor: sizeFactor,
                      child: Column(
                        key: childKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            key: headerKey,
                            height: 100,
                            child: Placeholder(),
                          ),
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemBuilder: (context, index) => ListTile(
                                title: Text('Item $index'),
                              ),
                            ),
                          ),
                          const SizedBox(
                            key: footerKey,
                            height: 50,
                            child: Placeholder(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(buildBottomAligned(sizeFactor: 0.05));
        await tester.pumpAndSettle();

        // The ShrinkTransition visible window is 5% of 600 = 30 px.
        final shrinkSize = tester.getSize(find.byType(ShrinkTransition));
        expect(shrinkSize.height, equals(600 * 0.05));

        // The header (100 px) is taller than the 30 px window, so
        // only its top portion is visible. The footer is below the
        // visible window — pushed out.
        final footerRect = tester.getRect(find.byKey(footerKey));
        final shrinkRect = tester.getRect(find.byType(ShrinkTransition));
        expect(
          footerRect.top,
          greaterThan(shrinkRect.bottom),
          reason: 'Footer should be pushed below the visible area',
        );
      },
    );

    testWidgets(
      'sizeFactor > 1.0 grows the transition past the '
      "child's natural height",
      (tester) async {
        const childHeight = 200.0;
        const child = SizedBox(
          height: childHeight,
          child: Placeholder(key: childKey),
        );

        // At sizeFactor 1.0 the transition matches the child.
        await tester.pumpWidget(build(child: child));
        final normalSize = tester.getSize(find.byType(ShrinkTransition));
        expect(normalSize.height, equals(childHeight));

        // At sizeFactor 1.5 the transition should be 300 px — larger
        // than the child's 200 px. This is how spring overshoot
        // works: the parent sees a bigger widget and can position
        // it further down, creating the visual bounce.
        await tester.pumpWidget(
          build(child: child, sizeFactor: 1.5),
        );
        await tester.pumpAndSettle();
        final overshootSize = tester.getSize(find.byType(ShrinkTransition));
        expect(
          overshootSize.height,
          equals(childHeight * 1.5),
        );
      },
    );

    testWidgets(
      'sizeFactor > 1.0 translates the child upward when '
      'constrained to natural height',
      (tester) async {
        const child = SizedBox.expand(
          child: Placeholder(key: childKey),
        );

        // Bottom-aligned layout mirrors how the sheet route works.
        Widget buildBottomAligned({double sizeFactor = 1.0}) {
          return MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: ShrinkTransition(
                      sizeFactor: sizeFactor,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // At sizeFactor 1.0 the child fills the available space (600 px)
        // and its top sits at 0.
        await tester.pumpWidget(buildBottomAligned());
        final normalRect = tester.getRect(find.byKey(childKey));
        expect(normalRect.top, equals(0));
        expect(normalRect.bottom, equals(600));

        // At sizeFactor 1.2, targetHeight = 720 but the constraint
        // clamps the ShrinkTransition to 600 px.  The child (600 px)
        // must be translated up by 120 px so it appears to push
        // above the top of the screen.
        await tester.pumpWidget(buildBottomAligned(sizeFactor: 1.2));
        await tester.pumpAndSettle();

        final overshootRect = tester.getRect(find.byKey(childKey));
        expect(
          overshootRect.top,
          equals(-120),
          reason: 'Child should be translated upward by the overshoot amount',
        );
        expect(
          overshootRect.bottom,
          equals(480),
          reason: 'Bottom should shift up by the same overshoot amount',
        );

        // The ShrinkTransition itself is still clamped to 600 px.
        final shrinkSize = tester.getSize(find.byType(ShrinkTransition));
        expect(shrinkSize.height, equals(600));
      },
    );

    testWidgets('referenceHeightOf returns null outside a ShrinkTransition',
        (tester) async {
      double? capturedHeight;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedHeight = ShrinkTransition.referenceHeightOf(context);
                return const Placeholder();
              },
            ),
          ),
        ),
      );

      expect(capturedHeight, isNull);
    });
  });
}
