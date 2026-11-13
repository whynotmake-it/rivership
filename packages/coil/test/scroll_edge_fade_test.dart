import 'package:coil/coil.dart';
// The eased ramp is internal; the golden compares it with a linear one.
// ignore: implementation_imports
import 'package:coil/src/primitives/eased_gradient.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';
import 'src/paint_probe.dart';

const _red = Color(0xFFFF0000);
const _white = Color(0xFFFFFFFF);
const _probe = ValueKey('probe');

/// Pumps a 200 x 100 fade over [length] px of red on white and returns the
/// color at its start and end edges, once settled after [scrollTo].
Future<({Color start, Color end})> _edges(
  WidgetTester tester, {
  Axis axis = Axis.horizontal,
  TextDirection direction = TextDirection.ltr,
  bool reverse = false,
  double length = 1000,
  double? scrollTo,
  bool solid = false,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  final list = ListView(
    controller: controller,
    scrollDirection: axis,
    reverse: reverse,
    children: [
      SizedBox.square(
        dimension: length,
        child: const ColoredBox(color: _red),
      ),
    ],
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: CoilTheme(
        data: CoilThemeData.light,
        child: Center(
          child: RepaintBoundary(
            key: _probe,
            child: ColoredBox(
              color: _white,
              child: SizedBox(
                width: 200,
                height: 100,
                child: solid
                    ? CoilScrollEdgeFade.solid(
                        axis: axis,
                        color: _white,
                        child: list,
                      )
                    : CoilScrollEdgeFade(axis: axis, child: list),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (scrollTo != null) {
    controller.jumpTo(scrollTo);
    await tester.pumpAndSettle();
  }
  final rect = tester.getRect(find.byKey(_probe));
  Offset at(double t) => axis == Axis.vertical
      ? Offset(rect.center.dx, rect.top + 1 + (rect.height - 2) * t)
      : Offset(rect.left + 1 + (rect.width - 2) * t, rect.center.dy);
  return (
    start: await colorAt(tester, find.byKey(_probe), at(0)),
    end: await colorAt(tester, find.byKey(_probe), at(1)),
  );
}

bool _faded(Color color) => !isNear(color, _red);

void main() {
  testWidgets('at rest only the end with more content fades', (tester) async {
    final edges = await _edges(tester);
    expect(_faded(edges.start), isFalse);
    expect(_faded(edges.end), isTrue);
  });

  testWidgets('content that fits fades nowhere', (tester) async {
    final edges = await _edges(tester, length: 200);
    expect(_faded(edges.start), isFalse);
    expect(_faded(edges.end), isFalse);
  });

  testWidgets('scrolled to the middle, both edges fade', (tester) async {
    final edges = await _edges(tester, scrollTo: 400);
    expect(_faded(edges.start), isTrue);
    expect(_faded(edges.end), isTrue);
  });

  testWidgets('scrolled to the end, only the start fades', (tester) async {
    final edges = await _edges(tester, scrollTo: 800);
    expect(_faded(edges.start), isTrue);
    expect(_faded(edges.end), isFalse);
  });

  testWidgets('right to left: the hidden content is on the left', (
    tester,
  ) async {
    final edges = await _edges(tester, direction: TextDirection.rtl);
    expect(_faded(edges.start), isTrue, reason: 'the left edge');
    expect(_faded(edges.end), isFalse, reason: 'the right edge');
  });

  testWidgets('a reversed list: the hidden content is at the top', (
    tester,
  ) async {
    final edges = await _edges(tester, axis: Axis.vertical, reverse: true);
    expect(_faded(edges.start), isTrue, reason: 'the top edge');
    expect(_faded(edges.end), isFalse, reason: 'the bottom edge');
  });

  testWidgets('solid mode fades into its color without a ShaderMask', (
    tester,
  ) async {
    final edges = await _edges(tester, solid: true);
    expect(find.byType(ShaderMask), findsNothing);
    expect(_faded(edges.start), isFalse);
    expect(isNear(edges.end, _white), isTrue);
  });

  testWidgets('eased ramp against a linear one', (tester) async {
    Widget bar(Gradient gradient) => Container(
      width: 320,
      height: 48,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(gradient: gradient),
    );
    const black = Color(0xFF000000);
    final sheet = await pumpSheet(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: _white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bar(
                easedGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  from: black,
                  to: black.withValues(alpha: 0),
                ),
              ),
              bar(
                LinearGradient(
                  colors: [black, black.withValues(alpha: 0)],
                ),
              ),
            ],
          ),
        ),
      ),
      surface: const Size(400, 160),
    );
    await expectSheetGolden(tester, sheet, 'goldens/eased_gradient.png');
  });
}
