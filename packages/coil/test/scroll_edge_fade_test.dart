import 'package:coil/coil.dart';
// The eased ramp is internal.
// ignore: implementation_imports
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
  double? startExtent,
  double? endExtent,
  double inset = 1,
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
                        startExtent: startExtent,
                        endExtent: endExtent,
                        child: list,
                      )
                    : CoilScrollEdgeFade(
                        axis: axis,
                        startExtent: startExtent,
                        endExtent: endExtent,
                        child: list,
                      ),
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
      ? Offset(rect.center.dx, rect.top + inset + (rect.height - 2 * inset) * t)
      : Offset(
          rect.left + inset + (rect.width - 2 * inset) * t,
          rect.center.dy,
        );
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

  for (final solid in [false, true]) {
    testWidgets('each end can fade over its own extent '
        '(${solid ? 'solid' : 'mask'})', (tester) async {
      // 12 px in from each edge: inside a 40 px fade, past an 8 px one.
      final edges = await _edges(
        tester,
        scrollTo: 400,
        solid: solid,
        startExtent: 8,
        endExtent: 40,
        inset: 12,
      );
      expect(_faded(edges.start), isFalse);
      expect(_faded(edges.end), isTrue);
    });
  }

  for (final solid in [false, true]) {
    testWidgets('stops shape a fade: faint at the edge, hidden, then clear '
        '(${solid ? 'solid' : 'mask'})', (tester) async {
      // 200 tall, the end fading over 100: content stays 30 % visible
      // along the first 40 (under something translucent), is hidden from
      // 40 to 60, then eases back in by 100.
      const stops = [
        CoilFadeStop(0, 0.3),
        CoilFadeStop(0.4, 0.3),
        CoilFadeStop(0.4, 0),
        CoilFadeStop(0.6, 0),
        CoilFadeStop(1, 1),
      ];
      final list = ListView(
        children: const [
          SizedBox(height: 1000, child: ColoredBox(color: _red)),
        ],
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CoilTheme(
            data: CoilThemeData.light,
            child: Center(
              child: RepaintBoundary(
                key: _probe,
                child: ColoredBox(
                  color: _white,
                  child: SizedBox(
                    width: 100,
                    height: 200,
                    child: solid
                        ? CoilScrollEdgeFade.solid(
                            color: _white,
                            startExtent: 0,
                            endExtent: 100,
                            endStops: stops,
                            child: list,
                          )
                        : CoilScrollEdgeFade(
                            startExtent: 0,
                            endExtent: 100,
                            endStops: stops,
                            child: list,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<Color> at(double fromBottom) {
        final rect = tester.getRect(find.byKey(_probe));
        return colorAt(
          tester,
          find.byKey(_probe),
          Offset(rect.center.dx, rect.bottom - fromBottom),
        );
      }

      final faint = await at(20);
      expect(
        isNear(faint, _red) || isNear(faint, _white),
        isFalse,
        reason: 'faintly visible at the edge',
      );
      expect(isNear(await at(50), _white), isTrue, reason: 'hidden');
      expect(isNear(await at(150), _red), isTrue, reason: 'past the fade');
    });
  }
}
