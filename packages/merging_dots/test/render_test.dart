import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

Future<ui.Image> capture(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: Padding(padding: const EdgeInsets.all(10), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(boundary.toImage))!;
}

Future<int Function(int x, int y)> alphaReader(
  WidgetTester tester,
  ui.Image image,
) async {
  final data = (await tester.runAsync(
    () => image.toByteData(),
  ))!;
  return (int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await DotShaders.precache();
  });

  testWidgets('shaders load', (tester) async {
    expect(DotShaders.isLoaded, isTrue);
  });

  testWidgets('grid dots render where their cells are', (tester) async {
    final image = await capture(
      tester,
      DotGridView(
        grid: DotGrid.parse('#.#'),
        style: const DotGridStyle(
          color: Color(0xFFFF0000),
          blend: 0,
          cellSize: 20,
        ),
      ),
    );
    expect(image.width, 80);
    expect(image.height, 40);
    final alpha = await alphaReader(tester, image);
    // Cell centers at x = 10 + 10, 30, 50; y = 20.
    expect(alpha(20, 20), 255);
    expect(alpha(30, 20), 0);
    expect(alpha(60, 20), 255);
    // Radius is 8: just inside and outside.
    expect(alpha(27, 20), 255);
    expect(alpha(29, 20), 0);
    expect(alpha(5, 5), 0);
  });

  testWidgets('blend bridges neighbors', (tester) async {
    Future<int> middle(double blend) async {
      final image = await capture(
        tester,
        DotGridView(
          grid: DotGrid.parse('##'),
          style: DotGridStyle(
            color: const Color(0xFFFF0000),
            blend: blend,
            cellSize: 20,
            dotSize: 0.7,
          ),
        ),
      );
      final alpha = await alphaReader(tester, image);
      return alpha(30, 20);
    }

    expect(await middle(0), 0);
    expect(await middle(1), 255);
  });

  testWidgets('cloud dots render at their canvas position', (tester) async {
    final image = await capture(
      tester,
      const SizedBox(
        width: 200,
        height: 100,
        child: DotCloudView(
          cloud: DotCloud(
            [Dot(10, 10, 5), Dot(90, 90, 5)],
          ),
          style: DotCloudStyle(color: Color(0xFF00FF00), blend: 0),
        ),
      ),
    );
    final alpha = await alphaReader(tester, image);
    // The canvas is 100 x 100, centered in 200 x 100 at x = 50, plus 10.
    expect(alpha(70, 20), 255);
    expect(alpha(150, 100), 255);
    expect(alpha(110, 60), 0);
  });
}
