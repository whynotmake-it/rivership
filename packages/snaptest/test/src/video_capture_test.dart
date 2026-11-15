import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:snaptest/src/capture.dart';

void main() {
  for (final background in [
    Colors.white,
    Colors.transparent,
    const Color(0x804080C0),
  ]) {
    for (final framed in [false, true]) {
      for (final crop in [
        null,
        const Rect.fromLTWH(12, 8, 41, 27),
        const Rect.fromLTWH(12.25, 8.5, 41.5, 27.25),
      ]) {
        for (final orientation in Orientation.values) {
          testWidgets(
            'matches legacy pixels: $background $framed $crop $orientation',
            (
              tester,
            ) async {
              tester.view
                ..physicalSize = const Size(81, 61)
                ..devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              await tester.pumpWidget(const _Scene());
              final device = framed ? Devices.ios.iPhone16Pro : null;
              final capture = VideoFrameCapture(
                SnapVideoSettings(
                  includeDeviceFrame: framed,
                  showPointers: true,
                  backgroundColor: background,
                ),
                crop,
              );
              addTearDown(capture.dispose);
              final element = tester.element(find.byType(View));
              const pointers = [Offset(30, 20), Offset(80, 60)];
              final result = await tester.runAsync(() async {
                final captured = await captureElementImage(
                  element,
                  device: device,
                  orientation: orientation,
                  includeDeviceFrame: framed,
                );
                var legacy = await drawPointerIndicators(
                  captured.image,
                  captured,
                  pointers,
                );
                if (crop != null) {
                  legacy = await cropCapturedImage(legacy, crop, captured);
                }
                legacy = await _background(legacy, background);
                final image = (await capture.capture(
                  element,
                  device: device,
                  orientation: orientation,
                  pointers: pointers,
                ))!;
                final oldPixels = await _pixels(legacy);
                final newPixels = await _pixels(image);
                return (oldPixels, newPixels);
              });
              expect(result!.$2, orderedEquals(result.$1));
            },
          );
        }
      }
    }
  }

  testWidgets('straight RGBA preserves the PNG path including alpha edges', (
    tester,
  ) async {
    await tester.pumpWidget(const _Scene());
    final result = await tester.runAsync(() async {
      final captured = await captureElementImage(
        tester.element(find.byType(View)),
      );
      final png = (await captured.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      final codec = await ui.instantiateImageCodec(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
      try {
        return (
          await _pixels(captured.image),
          await _pixels((await codec.getNextFrame()).image),
        );
      } finally {
        codec.dispose();
      }
    });
    expect(result!.$1, orderedEquals(result.$2));
  });

  testWidgets('retains static pixels, but invalidates on paint and pointers', (
    tester,
  ) async {
    await tester.pumpWidget(const _Scene());
    final capture = VideoFrameCapture(const SnapVideoSettings(), null);
    addTearDown(capture.dispose);
    Future<bool?> take([List<Offset> pointers = const []]) =>
        tester.runAsync(() async {
          final image = await capture.capture(
            tester.element(find.byType(View)),
            device: null,
            orientation: Orientation.portrait,
            pointers: pointers,
          );
          final changed = image != null;
          image?.dispose();
          return changed;
        });
    expect(await take(), isTrue);
    expect(await take(), isFalse);
    expect(await take(const [Offset(30, 20)]), isTrue);
    expect(await take(), isTrue);
    await tester.pumpWidget(const _Scene(color: Colors.blue));
    expect(await take(), isTrue);
  });

  testWidgets('invalidates cached artwork when a device painter notifies', (
    tester,
  ) async {
    await tester.pumpWidget(const _Scene());
    final color = ValueNotifier<Color>(Colors.red);
    addTearDown(color.dispose);
    final device = Devices.ios.iPhone16Pro.copyWith(
      framePainter: _FramePainter(color),
    );
    final capture = VideoFrameCapture(
      const SnapVideoSettings(includeDeviceFrame: true),
      null,
    );
    addTearDown(capture.dispose);
    Future<Uint8List?> take() => tester.runAsync<Uint8List?>(() async {
      final image = await capture.capture(
        tester.element(find.byType(View)),
        device: device,
        orientation: Orientation.portrait,
        pointers: [],
      );
      return image == null ? null : _pixels(image);
    });
    final before = await take();
    expect(await take(), isNull);
    color.value = Colors.blue;
    expect(await take(), isNot(orderedEquals(before!)));
  });

  testWidgets('does not reuse texture pixels or custom pointer painting', (
    tester,
  ) async {
    await tester.pumpWidget(const Texture(textureId: 123));
    final capture = VideoFrameCapture(const SnapVideoSettings(), null);
    addTearDown(capture.dispose);
    final textures = await tester.runAsync(() async {
      final element = tester.element(find.byType(View));
      final first = await capture.capture(
        element,
        device: null,
        orientation: Orientation.portrait,
        pointers: [],
      );
      first?.dispose();
      final second = await capture.capture(
        element,
        device: null,
        orientation: Orientation.portrait,
        pointers: [],
      );
      second?.dispose();
      return second != null;
    });
    expect(textures, isTrue);
    await tester.pumpWidget(const _Scene());
    var paints = 0;
    final custom = VideoFrameCapture(
      SnapVideoSettings(
        pointerIndicator: (canvas, center, scale) {
          paints++;
        },
      ),
      null,
    );
    addTearDown(custom.dispose);
    await tester.runAsync(() async {
      for (var i = 0; i < 2; i++) {
        final image = await custom.capture(
          tester.element(find.byType(View)),
          device: null,
          orientation: Orientation.portrait,
          pointers: [const Offset(30, 20)],
        );
        image?.dispose();
      }
    });
    expect(paints, 2);
  });

  testWidgets('detects composited transforms without repainting the child', (
    tester,
  ) async {
    final offset = ValueNotifier<double>(0);
    addTearDown(offset.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: offset,
        builder: (context, value, child) =>
            Transform.translate(offset: Offset(value, 0), child: child),
        child: const RepaintBoundary(child: _Scene()),
      ),
    );
    final capture = VideoFrameCapture(const SnapVideoSettings(), null);
    addTearDown(capture.dispose);
    Future<Uint8List?> take() => tester.runAsync<Uint8List?>(() async {
      final image = await capture.capture(
        tester.element(find.byType(View)),
        device: null,
        orientation: Orientation.portrait,
        pointers: [],
      );
      return image == null ? null : _pixels(image);
    });
    final before = await take();
    offset.value = 30;
    await tester.pump();
    final after = await take();
    expect(after, isNotNull);
    expect(after, isNot(orderedEquals(before!)));
  });
}

Future<Uint8List> _pixels(ui.Image image) async {
  try {
    final data = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _background(ui.Image image, Color background) async {
  final width = image.width + (image.width & 1);
  final height = image.height + (image.height & 1);
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawImage(image, Offset.zero, Paint())
    ..drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()
        ..color = background
        ..blendMode = BlendMode.dstOver,
    );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
    image.dispose();
  }
}

class _Scene extends StatelessWidget {
  const _Scene({this.color = Colors.red});
  final Color color;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 51,
        height: 33,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    ),
  );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color) : super(repaint: color);
  final ValueNotifier<Color> color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawRect(Offset.zero & size, Paint()..color = color.value);

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}
