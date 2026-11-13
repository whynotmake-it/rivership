import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  bool expanded, {
  bool reduce = false,
  double childHeight = 80,
  bool appear = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduce),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CoilTheme(
      data: CoilThemeData.light,
      child: Align(
        alignment: Alignment.topLeft,
        child: CoilCollapsible(
          expanded: expanded,
          appear: appear,
          child: SizedBox(width: 100, height: childHeight),
        ),
      ),
    ),
  ),
);

double _height(WidgetTester tester) =>
    tester.getSize(find.byType(CoilCollapsible)).height;

void main() {
  // The first argument reads as "expanded" at every call site.
  // ignore_for_file: avoid_positional_boolean_parameters
  testWidgets('springs its height open and closed', (tester) async {
    await tester.pumpWidget(_app(false));
    expect(_height(tester), 0);
    await tester.pumpWidget(_app(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_height(tester), inExclusiveRange(0, 80));
    await tester.pumpAndSettle();
    expect(_height(tester), 80);
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();
    expect(_height(tester), 0);
  });

  testWidgets('a closed region is out of focus and semantics', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CoilCollapsible(
          expanded: false,
          child: Focus(focusNode: node, child: const Text('Hidden')),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isFalse);
    expect(find.bySemanticsLabel('Hidden'), findsNothing);
  });

  testWidgets('reduced motion snaps the height', (tester) async {
    await tester.pumpWidget(_app(false, reduce: true));
    await tester.pumpWidget(_app(true, reduce: true));
    await tester.pump();
    await tester.pump();
    expect(_height(tester), 80);
  });

  testWidgets('a child resizing inside an open region resizes at once', (
    tester,
  ) async {
    await tester.pumpWidget(_app(true));
    expect(_height(tester), 80);
    await tester.pumpWidget(_app(true, childHeight: 120));
    expect(_height(tester), 120);
  });

  testWidgets('appear opens a region that starts open', (tester) async {
    await tester.pumpWidget(_app(true, appear: true));
    expect(_height(tester), 0);
    await tester.pumpAndSettle();
    expect(_height(tester), 80);
  });
}
