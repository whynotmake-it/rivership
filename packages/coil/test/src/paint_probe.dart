import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The color painted at [globalPoint] inside the `RepaintBoundary` found by
/// [boundary], at 1x. For checking what users see (a highlight on a row)
/// without reading a painter's internals.
Future<Color> colorAt(
  WidgetTester tester,
  Finder boundary,
  Offset globalPoint,
) async {
  final box = tester.renderObject<RenderRepaintBoundary>(boundary);
  final local = box.globalToLocal(globalPoint);
  final bytes = await tester.runAsync(() async {
    final image = await box.toImage();
    final data = await image.toByteData();
    final width = image.width;
    image.dispose();
    final i = (local.dy.floor() * width + local.dx.floor()) * 4;
    return data!.buffer.asUint8List().sublist(i, i + 4);
  });
  return Color.fromARGB(bytes![3], bytes[0], bytes[1], bytes[2]);
}

/// Whether [color] is close to [expected] (antialiasing aside).
bool isNear(Color color, Color expected, {int tolerance = 8}) {
  int c(double v) => (v * 255).round();
  return (c(color.r) - c(expected.r)).abs() <= tolerance &&
      (c(color.g) - c(expected.g)).abs() <= tolerance &&
      (c(color.b) - c(expected.b)).abs() <= tolerance;
}
