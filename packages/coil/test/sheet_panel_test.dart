import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

double _hairlineAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(CoilSheetPanel),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border is Border,
          ),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).border! as Border).top.color.a;
}

void main() {
  testWidgets('the header hairline shows only while content is under it', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => CoilTheme(
          data: CoilThemeData.light,
          child: SizedBox(
            height: 400,
            child: CoilSheetPanel(
              title: const Text('Fruit'),
              child: ListView(
                controller: scroll,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 44, child: Text('Row $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_hairlineAlpha(tester), 0, reason: 'at the top: no line');

    scroll.jumpTo(100);
    await tester.pumpAndSettle();
    expect(_hairlineAlpha(tester), greaterThan(0), reason: 'scrolled under');

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_hairlineAlpha(tester), 0, reason: 'back at the top');
  });
}
