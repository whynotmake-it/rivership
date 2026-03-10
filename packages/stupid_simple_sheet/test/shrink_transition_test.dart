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

        final rect = tester.getRect(find.byKey(childKey));

        expect(rect.height, equals(headerHeight + footerHeight));

        // Child is pushing out now, so the bottom should be beyond the screen
        expect(rect.bottom, greaterThan(600));
      },
    );

    testWidgets('aligns to bottom', (tester) async {
      const child = SizedBox.expand(
        child: Placeholder(
          key: childKey,
        ),
      );

      await tester.pumpWidget(build(child: child));

      final rect1 = tester.getRect(find.byKey(childKey));
      expect(rect1.top, equals(0));
      expect(rect1.bottom, equals(600));

      await tester.pumpWidget(build(child: child, sizeFactor: .5));
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
  });
}
