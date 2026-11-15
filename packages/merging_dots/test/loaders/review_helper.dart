import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

/// Renders [loader] as a film strip PNG at [path], for reviewing motion.
///
/// An endless loader is filmed over [duration], a determinate one while its
/// progress steps through [steps], filming the motion between steps. Each
/// frame is [size] logical pixels on paper.
Future<void> reviewLoader(
  WidgetTester tester,
  DotLoader loader,
  String path, {
  Duration duration = const Duration(milliseconds: 2400),
  int frames = 16,
  List<double> steps = const [0, 0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1],
  double size = 96,
}) async {
  await DotShaders.precache();
  tester.view
    ..physicalSize = Size(size, size)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  Widget stage(double progress) => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: const Color(0xFFF3F1EC),
        child: IconTheme(
          data: const IconThemeData(color: Color(0xFF1D1C1A)),
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: DotLoaderView(loader: loader, progress: progress),
          ),
        ),
      ),
    ),
  );

  final images = <ui.Image>[];
  Future<void> capture() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    images.add((await tester.runAsync(boundary.toImage))!);
  }

  if (loader.isDeterminate) {
    await tester.pumpWidget(stage(steps.first));
    await tester.pump(const Duration(seconds: 1));
    await capture();
    for (final step in steps.skip(1)) {
      await tester.pumpWidget(stage(step));
      // Two frames mid-motion, then the settled pose.
      await tester.pump(const Duration(milliseconds: 80));
      await capture();
      await tester.pump(const Duration(milliseconds: 120));
      await capture();
      await tester.pump(const Duration(seconds: 1));
      await capture();
    }
  } else {
    await tester.pumpWidget(stage(0));
    final frameTime = duration ~/ frames;
    for (var i = 0; i < frames; i++) {
      await tester.pump(frameTime);
      await capture();
    }
  }

  // Lay the frames out in rows of 8.
  const perRow = 8;
  final rows = (images.length / perRow).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var i = 0; i < images.length; i++) {
    canvas.drawImage(
      images[i],
      Offset((i % perRow) * size, (i ~/ perRow) * size),
      Paint(),
    );
  }
  final picture = recorder.endRecording();
  final bytes = await tester.runAsync(() async {
    final image = await picture.toImage(
      (perRow * size).round(),
      (rows * size).round(),
    );
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  // Let animations end so the test can finish.
  await tester.pumpWidget(const SizedBox());
}
