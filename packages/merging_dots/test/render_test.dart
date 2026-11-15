import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots/src/rendering/data_texture.dart';

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

  testWidgets('data textures keep their bytes on either upload path', (
    tester,
  ) async {
    final rgba = Uint8List.fromList([
      for (var i = 0; i < 6; i++) ...[i * 40, 255 - i * 40, i * 7, 255],
    ]);
    final texture = DotDataTexture()..upload(rgba, 3, 2);
    addTearDown(texture.dispose);
    final data = (await tester.runAsync(
      () => texture.image!.toByteData(),
    ))!;
    expect(data.buffer.asUint8List(), rgba);
  });

  testWidgets('clouds render many dots', (tester) async {
    // A 30 x 30 lattice of 900 small dots, far more than one tile holds.
    final image = await capture(
      tester,
      SizedBox(
        width: 300,
        height: 300,
        child: DotCloudView(
          cloud: DotCloud(
            [
              for (var y = 0; y < 30; y++)
                for (var x = 0; x < 30; x++) Dot(x * 10 + 5, y * 10 + 5, 2),
            ],
            size: const Size.square(300),
          ),
          style: const DotCloudStyle(color: Color(0xFF00FF00), blend: 1),
        ),
      ),
    );
    final alpha = await alphaReader(tester, image);
    for (final (x, y) in [(0, 0), (29, 0), (13, 17), (29, 29)]) {
      // Dot centers, plus the 10 pixel padding.
      expect(alpha(x * 10 + 15, y * 10 + 15), 255, reason: '($x, $y)');
      // Between dots.
      expect(alpha(x * 10 + 20, y * 10 + 20), 0, reason: '($x, $y) gap');
    }
  });

  testWidgets('the order of dots does not change the shape', (tester) async {
    const dots = [
      Dot(30, 50, 12),
      Dot(52, 44, 9),
      Dot(70, 58, 14),
      Dot(48, 66, 6),
    ];
    Future<List<int>> render(List<Dot> dots) async {
      final image = await capture(
        tester,
        SizedBox.square(
          dimension: 100,
          child: DotCloudView(
            cloud: DotCloud(dots),
            style: const DotCloudStyle(color: Color(0xFFFFFFFF), blend: 16),
          ),
        ),
      );
      final data = (await tester.runAsync(
        image.toByteData,
      ))!;
      return data.buffer.asUint8List();
    }

    final forwards = await render(dots);
    final backwards = await render(dots.reversed.toList());
    var different = 0;
    for (var i = 0; i < forwards.length; i++) {
      if ((forwards[i] - backwards[i]).abs() > 1) different++;
    }
    expect(different, 0);
    // And they did merge.
    expect(forwards.where((v) => v == 255).length, greaterThan(1000));
  });

  testWidgets('tiles fuse full cells and carve round holes', (tester) async {
    final image = await capture(
      tester,
      DotGridView(
        grid: DotGrid.parse('''
          ###
          #.#
          ###
          #..
        '''),
        style: const DotGridStyle.tiles(
          color: Color(0xFFFF0000),
          cellSize: 20,
        ),
      ),
    );
    final alpha = await alphaReader(tester, image);
    // Cells are 20 pixels, plus 10 pixels of padding.
    // The join between two filled cells is solid.
    expect(alpha(30, 20), 255);
    // The empty middle cell is a round hole: empty at its center, ink in
    // its corners.
    expect(alpha(40, 40), 0);
    expect(alpha(31, 31), 255);
    // A free corner is rounded: its very tip is paper.
    expect(alpha(11, 11), 0);
    expect(alpha(20, 20), 255);
    // The empty bottom right cells stay empty next to the filled edge.
    expect(alpha(50, 80), 0);
    // An edge between a filled and an empty cell is straight.
    expect(alpha(49, 62), 255);
    expect(alpha(49, 71), 0);
  });
}
