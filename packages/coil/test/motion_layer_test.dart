import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_sheet.dart';
import 'src/paint_probe.dart';

const _red = Color(0xFFFF0000);
const _white = Color(0xFFFFFFFF);
final _boundary = find.byKey(const ValueKey('boundary'));

/// Ten rows in a region with a red highlight. [scroll] puts them in a
/// short scroll view.
Widget _list({
  double width = 200,
  double firstRowHeight = 36,
  ScrollController? scroll,
}) {
  Widget rows = CoilHoverHighlight(
    color: _red,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 10; i++)
          CoilHoverItem(
            index: i,
            child: SizedBox(
              height: i == 0 ? firstRowHeight : 36,
              child: Text('Row $i'),
            ),
          ),
      ],
    ),
  );
  if (scroll != null) {
    rows = SizedBox(
      height: 120,
      child: SingleChildScrollView(controller: scroll, child: rows),
    );
  }
  return WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => CoilTheme(
      data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
      child: RepaintBoundary(
        key: const ValueKey('boundary'),
        child: ColoredBox(
          color: _white,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: CoilHoverRegion(child: rows),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A point near row [i]'s right end, clear of its text.
Offset _rowPoint(WidgetTester tester, int i) =>
    tester
        .getRect(
          find
              .ancestor(
                of: find.text('Row $i'),
                matching: find.byType(SizedBox),
              )
              .first,
        )
        .centerRight -
    const Offset(4, 0);

void main() {
  testWidgets('the highlight follows its row when the list resizes', (
    tester,
  ) async {
    await tester.pumpWidget(_list());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(_rowPoint(tester, 1));
    await settle(tester);
    expect(
      isNear(await colorAt(tester, _boundary, _rowPoint(tester, 1)), _red),
      isTrue,
    );
    expect(
      isNear(await colorAt(tester, _boundary, _rowPoint(tester, 0)), _white),
      isTrue,
    );

    // Wider and with a taller first row: one frame later the highlight
    // already sits on row 1's new place.
    await tester.pumpWidget(_list(width: 320, firstRowHeight: 60));
    expect(
      isNear(await colorAt(tester, _boundary, _rowPoint(tester, 1)), _red),
      isTrue,
    );
    expect(
      isNear(await colorAt(tester, _boundary, const Offset(316, 40)), _white),
      isTrue,
    );
  });

  testWidgets('the highlight stays on its row while the list scrolls under '
      'a resting pointer', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_list(scroll: scroll));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(_rowPoint(tester, 1));
    await settle(tester);

    scroll.jumpTo(10);
    await tester.pump();
    final row = _rowPoint(tester, 1);
    expect(isNear(await colorAt(tester, _boundary, row), _red), isTrue);
    // Just below the row's new bottom edge, where it used to be: no fill.
    expect(
      isNear(await colorAt(tester, _boundary, row + const Offset(0, 22)), _red),
      isFalse,
    );
  });

  testWidgets('a rebuild with an equal item keeps a glide going', (
    tester,
  ) async {
    const linear = Motion.linear(Duration(milliseconds: 200));
    Widget strip(int target) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: const ValueKey('boundary'),
          child: CoilMotionLayer(
            background: [
              CoilHighlight(
                target: target,
                decoration: const BoxDecoration(color: _red),
                motion: linear,
                exitMotion: linear,
                exitTravelMotion: linear,
                fade: linear,
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  CoilMotionTarget(
                    index: i,
                    child: const SizedBox(width: 100, height: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    Future<bool> redAt(double x) async =>
        isNear(await colorAt(tester, _boundary, Offset(x, 10)), _red);

    await tester.pumpWidget(strip(0));
    await tester.pumpWidget(strip(2));
    await tester.pump(const Duration(milliseconds: 100));
    // Halfway: the box covers the middle target.
    expect(await redAt(150), isTrue);

    // An equal rebuild mid-glide doesn't restart or jump it.
    await tester.pumpWidget(strip(2));
    await tester.pump();
    expect(await redAt(150), isTrue);
    expect(await redAt(50), isFalse);
    expect(await redAt(250), isFalse);

    await tester.pumpAndSettle();
    expect(await redAt(250), isTrue);
  });
}
