import 'package:coil/coil.dart';
import 'package:coil/src/primitives/motion_layer.dart'
    show CoilPainterLayer, RenderCoilMotionLayer;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The blocks a [RenderCoilMotionLayer] paints now, as superellipses.
List<RSuperellipse> _blocks(WidgetTester tester) {
  final layer = tester.renderObject<RenderCoilMotionLayer>(
    find.byType(CoilPainterLayer),
  );
  final canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawRSuperellipse)
        call.invocation.positionalArguments.first as RSuperellipse,
  ];
}

Widget _row(TextDirection direction, Set<int> selected) => Directionality(
  textDirection: direction,
  child: CoilTheme(
    data: CoilThemeData.light,
    child: Center(
      child: CoilMotionLayer(
        background: [
          CoilSelectionBlocks(
            selected: selected,
            color: const Color(0xFF000000),
            radius: 8,
            motion: const CoilMotion(),
            axis: Axis.horizontal,
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              CoilMotionTarget(
                index: i,
                child: const SizedBox(width: 40, height: 30),
              ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('${direction.name}: a split row glides apart, never across', (
      tester,
    ) async {
      await tester.pumpWidget(_row(direction, {0, 1, 2}));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_row(direction, {0, 2}));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final blocks = _blocks(tester);
        if (blocks.length < 2) continue;
        final [a, b] = blocks..sort((x, y) => x.left.compareTo(y.left));
        expect(
          a.right,
          lessThanOrEqualTo(b.left + 0.5),
          reason: 'frame $frame: the halves overlap',
        );
        // The seam corners are the square ones: the left block's right
        // side and the right block's left side.
        expect(a.tlRadius.x, greaterThanOrEqualTo(a.trRadius.x));
        expect(b.trRadius.x, greaterThanOrEqualTo(b.tlRadius.x));
      }
    });

    testWidgets('${direction.name}: a merge squares the seam', (tester) async {
      await tester.pumpWidget(_row(direction, {0, 2}));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_row(direction, {0, 1, 2}));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final blocks = _blocks(tester);
        if (blocks.length < 2) continue;
        final [a, b] = blocks..sort((x, y) => x.left.compareTo(y.left));
        expect(
          a.right,
          lessThanOrEqualTo(b.left + 0.5),
          reason: 'frame $frame: the halves cross',
        );
        expect(a.tlRadius.x, greaterThanOrEqualTo(a.trRadius.x));
        expect(b.trRadius.x, greaterThanOrEqualTo(b.tlRadius.x));
      }
      await tester.pumpAndSettle();
      expect(_blocks(tester), hasLength(1));
    });
  }

  testWidgets('rtl: a focus ring takes directional radii', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: CoilTheme(
          data: CoilThemeData.light,
          child: Center(
            child: CoilFocusRing(
              visible: true,
              borderRadius: BorderRadiusDirectional.only(
                topStart: Radius.circular(12),
              ),
              child: SizedBox(width: 40, height: 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paint = tester.renderObject<RenderCustomPaint>(
      find.descendant(
        of: find.byType(CoilFocusRing),
        matching: find.byType(CustomPaint),
      ),
    );
    final canvas = TestRecordingCanvas();
    paint.foregroundPainter!.paint(canvas, paint.size);
    final ring =
        canvas.invocations
                .firstWhere(
                  (c) => c.invocation.memberName == #drawRSuperellipse,
                )
                .invocation
                .positionalArguments
                .first
            as RSuperellipse;
    // The start is on the right.
    expect(ring.trRadius.x, greaterThan(ring.tlRadius.x));
  });
}
