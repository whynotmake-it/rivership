import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

/// A list whose width and first-row height the test changes.
class _List extends StatelessWidget {
  const _List({required this.width, required this.firstRowHeight});

  final double width;
  final double firstRowHeight;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => FluidTheme(
      data: FluidThemeData.light.copyWith(tier: FluidTier.desktop),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: FluidHoverRegion(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++)
                  FluidHoverItem(
                    index: i,
                    child: SizedBox(
                      height: i == 0 ? firstRowHeight : 36,
                      child: Text('Row $i'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the highlight tracks a resized container in the same frame', (
    tester,
  ) async {
    await tester.pumpWidget(const _List(width: 200, firstRowHeight: 36));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(tester.getCenter(find.text('Row 1')));
    await settle(tester);

    RenderFluidMotionLayer layer() =>
        tester.renderObject(find.byType(FluidMotionLayer));
    FluidHighlightPainter highlight() =>
        layer().background.whereType<FluidHighlightPainter>().single;

    expect(highlight().debugLastPaintedRect, layer().rectOf(1));
    expect(layer().rectOf(1), const Rect.fromLTWH(0, 36, 200, 36));

    // Resize: wider container, taller first row (pushes row 1 down). One
    // frame later the highlight already sits on row 1's new rect: no
    // measuring pass, no extra frame.
    await tester.pumpWidget(const _List(width: 320, firstRowHeight: 60));
    final row1 = layer().rectOf(1);
    expect(row1, const Rect.fromLTWH(0, 60, 320, 36));
    expect(highlight().debugLastPaintedRect, row1);
  });
}
