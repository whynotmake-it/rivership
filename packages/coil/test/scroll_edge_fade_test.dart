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
    testWidgets("a covered end fades up to the cover's edge, and follows it "
        '(${solid ? 'solid' : 'mask'})', (tester) async {
      // 200 tall; something 40 tall floats over the end, and the list pads
      // its end by as much, as a chat does under its composer.
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Future<void> pump(double cover) => tester.pumpWidget(
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
                    child: () {
                      final list = ListView(
                        controller: controller,
                        padding: EdgeInsets.only(bottom: cover),
                        children: const [
                          SizedBox(
                            height: 1000,
                            child: ColoredBox(color: _red),
                          ),
                        ],
                      );
                      return solid
                          ? CoilScrollEdgeFade.solid(
                              color: _white,
                              startExtent: 0,
                              endExtent: 40,
                              endCover: cover,
                              child: list,
                            )
                          : CoilScrollEdgeFade(
                              startExtent: 0,
                              endExtent: 40,
                              endCover: cover,
                              child: list,
                            );
                    }(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<bool> fadedAt(double fromBottom) async {
        final rect = tester.getRect(find.byKey(_probe));
        return _faded(
          await colorAt(
            tester,
            find.byKey(_probe),
            Offset(rect.center.dx, rect.bottom - fromBottom),
          ),
        );
      }

      await pump(40);
      await tester.pumpAndSettle();
      // More content below: it fades out just above the cover, is hidden
      // under it, and is untouched well above.
      expect(await fadedAt(50), isTrue, reason: 'just above the cover');
      expect(await fadedAt(20), isTrue, reason: 'under the cover');
      expect(await fadedAt(100), isFalse, reason: 'well above the fade');

      // The cover grows (a keyboard slides up): the fade moves with it.
      await pump(120);
      await tester.pumpAndSettle();
      expect(await fadedAt(130), isTrue, reason: 'just above the new cover');
      expect(await fadedAt(180), isFalse);

      // Scrolled to the end, the content rests above the cover: no fade.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(await fadedAt(130), isFalse, reason: 'the end is in view');
    });
  }
}
