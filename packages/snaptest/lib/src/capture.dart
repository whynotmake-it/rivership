/// Low-level capture and composition primitives shared by [snap] and
/// [SnapRecording].
///
/// Everything in this file is package-internal: these functions rasterize
/// already-painted layer trees and never pump frames, load fonts, or change
/// the test environment. The higher-level `snap()` API adds that environment
/// setup on top.
/// @docImport 'package:snaptest/src/snap.dart';
/// @docImport 'package:snaptest/src/video/snap_recording.dart';
library;

import 'dart:ui' as ui;

import 'package:device_frame/device_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/src/blocked_text_painting_context.dart';
import 'package:snaptest/src/video/video_settings.dart';

/// The result of capturing an element's closest [RepaintBoundary].
@internal
class CapturedImage {
  /// Creates a captured image result.
  const CapturedImage({
    required this.image,
    required this.logicalBounds,
    required this.imageContentBounds,
  });

  /// The rasterized image.
  final ui.Image image;

  /// The captured region in logical coordinates.
  final Rect logicalBounds;

  /// The bounds inside [image] that contain the actual content.
  ///
  /// This differs from the full image bounds when a device frame was
  /// composited around the content: the image then includes the bezel, and
  /// this rect marks the screen area.
  final Rect imageContentBounds;
}

/// The result of compositing an image inside a device frame.
@internal
class FramedImage {
  /// Creates a framed image result.
  const FramedImage({
    required this.image,
    required this.screenBounds,
  });

  /// The composited image including the device frame.
  final ui.Image image;

  /// The screen area inside the frame, in image coordinates.
  final Rect screenBounds;
}

/// The logical bounds of the implicit test view.
@internal
Rect viewLogicalBounds() {
  final implicitView =
      TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
  final logicalSize = implicitView.physicalSize / implicitView.devicePixelRatio;
  return Offset.zero & logicalSize;
}

/// The bounds of the given [image] in image coordinates.
@internal
Rect imageBounds(ui.Image image) =>
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble());

/// Runs a given function [fn] in a runAsync block.
///
/// If the function is already in a runAsync block, it will be run immediately.
/// Otherwise, it will be run in a runAsync block.
@internal
Future<T?> maybeRunAsync<T>(Future<T> Function() fn) async {
  final binding = TestWidgetsFlutterBinding.instance;

  late final bool isInRunAsync;

  try {
    await binding.runAsync(() async {});
    isInRunAsync = false;
  } catch (e) {
    isInRunAsync = true;
  }

  if (isInRunAsync) {
    return fn();
  }

  return binding.runAsync(fn);
}

/// Renders the closest [RepaintBoundary] of the [element] into an image.
///
/// Set [blockText] to `true` to replace text with colored rectangles for
/// cross-platform consistency in golden tests.
///
/// If [includeDeviceFrame] is `true` and a [device] is provided, the image
/// will be wrapped with the device's frame.
///
/// See also:
///
///  * [OffsetLayer.toImage] which is the actual method being called.
@internal
Future<CapturedImage> captureElementImage(
  Element element, {
  bool blockText = false,
  DeviceInfo? device,
  Orientation orientation = Orientation.portrait,
  bool includeDeviceFrame = false,
}) async {
  final isViewCapture = element.widget is View;
  assert(
    element.renderObject != null,
    'The given element $element does not have a RenderObject',
  );
  var renderObject = element.renderObject!;
  while (!renderObject.isRepaintBoundary) {
    // ignore: unnecessary_cast
    renderObject = renderObject.parent! as RenderObject;
  }
  assert(!renderObject.debugNeedsPaint, 'The RenderObject needs painting');

  // RepaintBoundary is guaranteed to have an OffsetLayer
  // ignore: invalid_use_of_protected_member
  final layer = renderObject.layer! as OffsetLayer;

  if (blockText) {
    BlockedTextPaintingContext(
      containerLayer: layer,
      estimatedBounds: renderObject.paintBounds,
    ).paintSingleChild(renderObject);
  }

  final image = await layer.toImage(renderObject.paintBounds);
  final bounds = isViewCapture
      ? viewLogicalBounds()
      : MatrixUtils.transformRect(
          renderObject.getTransformTo(null),
          renderObject.paintBounds,
        );

  if (element.renderObject is RenderBox) {
    final expectedSize = (element.renderObject as RenderBox?)!.size;
    if (expectedSize.width.ceil() != image.width ||
        expectedSize.height.ceil() != image.height) {
      // ignore: avoid_print
      print(
        'Warning: The screenshot captured of ${element.toStringShort()} is '
        'larger (${image.width}, ${image.height}) than '
        '${element.toStringShort()} (${expectedSize.width}, '
        '${expectedSize.height}) itself.\n'
        'Wrap the ${element.toStringShort()} in a RepaintBoundary to be able '
        'to capture only that layer. ',
      );
    }
  }

  if (includeDeviceFrame && device != null) {
    final framedImage = await wrapImageWithDeviceFrame(
      image,
      device,
      orientation,
    );
    return CapturedImage(
      image: framedImage.image,
      logicalBounds: bounds,
      imageContentBounds: framedImage.screenBounds,
    );
  }

  return CapturedImage(
    image: image,
    logicalBounds: bounds,
    imageContentBounds: imageBounds(image),
  );
}

/// Crops [image] to the [crop] rect given in logical coordinates.
///
/// [captured] carries the coordinate mapping produced by
/// [captureElementImage] so the logical crop is correctly mapped into the
/// image, including when a device frame shifted the content area.
///
/// Disposes [image]. Returns a new image that the caller must dispose.
@internal
Future<ui.Image> cropCapturedImage(
  ui.Image image,
  Rect crop,
  CapturedImage captured,
) async {
  final croppedBounds = crop.intersect(captured.logicalBounds);
  if (croppedBounds.isEmpty) {
    image.dispose();
    throw ArgumentError.value(
      crop,
      'crop',
      'Crop rect must intersect the snapped bounds.',
    );
  }

  final cropRectInBounds = croppedBounds.translate(
    -captured.logicalBounds.left,
    -captured.logicalBounds.top,
  );
  final scaleX =
      captured.imageContentBounds.width / captured.logicalBounds.width;
  final scaleY =
      captured.imageContentBounds.height / captured.logicalBounds.height;
  final sourceRect = Rect.fromLTWH(
    captured.imageContentBounds.left + cropRectInBounds.left * scaleX,
    captured.imageContentBounds.top + cropRectInBounds.top * scaleY,
    cropRectInBounds.width * scaleX,
    cropRectInBounds.height * scaleY,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final outputWidth = croppedBounds.width.ceil();
  final outputHeight = croppedBounds.height.ceil();
  final outputSize = Size(
    outputWidth.toDouble(),
    outputHeight.toDouble(),
  );

  canvas.drawImageRect(
    image,
    sourceRect,
    Offset.zero & outputSize,
    Paint(),
  );

  final picture = recorder.endRecording();
  final croppedImage = await picture.toImage(outputWidth, outputHeight);

  picture.dispose();
  image.dispose();
  return croppedImage;
}

/// Paints a touch indicator over every [logicalPositions] entry.
///
/// Positions are in logical view coordinates (e.g. `PointerEvent.position`)
/// and are mapped into image coordinates the same way [cropCapturedImage]
/// maps crops, so indicators land correctly inside composited device frames
/// and subtree captures. Positions outside [CapturedImage.logicalBounds]
/// are skipped.
///
/// Disposes [image]. Returns a new image that the caller must dispose.
@internal
Future<ui.Image> drawPointerIndicators(
  ui.Image image,
  CapturedImage captured,
  Iterable<Offset> logicalPositions, {
  PointerIndicatorPainter? painter,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawImage(image, Offset.zero, Paint());
  _paintPointerIndicators(canvas, captured, logicalPositions, painter: painter);
  final picture = recorder.endRecording();
  final output = await picture.toImage(image.width, image.height);
  picture.dispose();
  image.dispose();
  return output;
}

void _paintPointerIndicators(
  Canvas canvas,
  CapturedImage captured,
  Iterable<Offset> logicalPositions, {
  PointerIndicatorPainter? painter,
}) {
  final scaleX =
      captured.imageContentBounds.width / captured.logicalBounds.width;
  final scaleY =
      captured.imageContentBounds.height / captured.logicalBounds.height;

  const logicalRadius = 14.0;
  final ringPaint = Paint()
    ..color = const Color(0xB3000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5 * scaleX;
  final fillPaint = Paint()..color = const Color(0xB3FFFFFF);

  for (final position in logicalPositions) {
    if (!captured.logicalBounds.contains(position)) {
      continue;
    }
    final center = Offset(
      captured.imageContentBounds.left +
          (position.dx - captured.logicalBounds.left) * scaleX,
      captured.imageContentBounds.top +
          (position.dy - captured.logicalBounds.top) * scaleY,
    );
    if (painter != null) {
      painter(canvas, center, scaleX);
    } else {
      final radius = logicalRadius * scaleX;
      _drawTouchIndicator(canvas, center, radius, fillPaint, ringPaint);
    }
  }
}

void _drawTouchIndicator(
  Canvas canvas,
  Offset center,
  double radius,
  Paint fill,
  Paint ring,
) {
  canvas
    ..drawCircle(center, radius, fill)
    ..drawCircle(center, radius, ring);
}

/// Wraps the given [image] with a device frame for the specified [device].
///
/// This creates a new image that includes the device frame around the content
/// without modifying the original widget tree.
///
/// Disposes [image]. Returns a new image that the caller must dispose.
@internal
Future<FramedImage> wrapImageWithDeviceFrame(
  ui.Image image,
  DeviceInfo device,
  Orientation orientation,
) async {
  // Create a picture recorder to draw the device frame
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final (deviceFrameSize, screenPath) = _paintDeviceFrame(
    canvas,
    device,
    orientation,
  );
  final screenRect = screenPath.getBounds();
  canvas
    ..clipPath(screenPath)
    ..drawImageRect(image, imageBounds(image), screenRect, Paint());
  final picture = recorder.endRecording();
  final framedImage = await picture.toImage(
    deviceFrameSize.width.round(),
    deviceFrameSize.height.round(),
  );
  picture.dispose();
  image.dispose();
  return FramedImage(image: framedImage, screenBounds: screenRect);
}

(Size, Path) _paintDeviceFrame(
  Canvas canvas,
  DeviceInfo device,
  Orientation orientation,
) {
  // Get frame size and screen path based on orientation
  Size deviceFrameSize;
  Path screenPath;

  if (orientation == Orientation.landscape) {
    // For landscape, we need to rotate the device frame
    deviceFrameSize = Size(device.frameSize.height, device.frameSize.width);

    // Transform the screen path for landscape orientation
    final transform = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(
        deviceFrameSize.width / 2,
        deviceFrameSize.height / 2,
      )
      ..rotateZ(1.5708) // 90 degrees in radians
      // ignore: deprecated_member_use
      ..translate(
        -device.frameSize.width / 2,
        -device.frameSize.height / 2,
      );

    screenPath = device.screenPath.transform(transform.storage);
  } else {
    deviceFrameSize = device.frameSize;
    screenPath = device.screenPath;
  }

  // Save canvas state before transformation
  canvas.save();

  if (orientation == Orientation.landscape) {
    // Rotate the canvas for landscape device frame painting
    canvas
      ..translate(deviceFrameSize.width / 2, deviceFrameSize.height / 2)
      ..rotate(1.5708) // 90 degrees
      ..translate(-device.frameSize.width / 2, -device.frameSize.height / 2);
  }

  device.framePainter.paint(canvas, device.frameSize);

  // Restore canvas state
  canvas.restore();

  return (deviceFrameSize, screenPath);
}

/// A recording-scoped compositor and conservative retained-scene cache.
@internal
class VideoFrameCapture {
  /// Creates a compositor with fixed output settings.
  VideoFrameCapture(this.settings, this.crop);

  /// Fixed composition settings for the recording.
  final SnapVideoSettings settings;

  /// The optional logical capture rectangle.
  final Rect? crop;
  OffsetLayer? _lastLayer;
  ui.EngineLayer? _lastEngineLayer;
  Rect? _lastBounds;
  Rect? _lastPaintBounds;
  DeviceInfo? _device;
  Orientation? _orientation;
  late bool _deviceFrameDirty = true;
  late List<Offset> _pointers = [];
  ui.Picture? _devicePicture;
  CapturedImage? _scene;
  late Path _screenPath;
  late Size _deviceSize;

  /// Returns null only when the complete captured scene is unchanged.
  Future<ui.Image?> capture(
    Element element, {
    required DeviceInfo? device,
    required Orientation orientation,
    required Iterable<Offset> pointers,
  }) async {
    var renderObject = element.renderObject!;
    while (!renderObject.isRepaintBoundary) {
      renderObject = renderObject.parent!;
    }
    // ignore: invalid_use_of_protected_member
    final layer = renderObject.layer! as OffsetLayer;
    final bounds = element.widget is View
        ? viewLogicalBounds()
        : MatrixUtils.transformRect(
            renderObject.getTransformTo(null),
            renderObject.paintBounds,
          );
    final positions = pointers.toList();
    final framedDevice = settings.includeDeviceFrame ? device : null;
    layer.updateSubtreeNeedsAddToScene();
    if (identical(layer, _lastLayer) &&
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        identical(layer.engineLayer, _lastEngineLayer) &&
        // ignore: invalid_use_of_visible_for_testing_member
        layer.debugSubtreeNeedsAddToScene == false &&
        bounds == _lastBounds &&
        renderObject.paintBounds == _lastPaintBounds &&
        framedDevice == _device &&
        orientation == _orientation &&
        !_deviceFrameDirty &&
        listEquals(positions, _pointers) &&
        settings.pointerIndicator == null &&
        !_hasExternalContent(layer)) {
      return null;
    }
    if (_deviceFrameDirty ||
        framedDevice != _device ||
        orientation != _orientation) {
      _device?.framePainter.removeListener(_markDeviceFrameDirty);
      _devicePicture?.dispose();
      _devicePicture = null;
      _device = framedDevice;
      _orientation = orientation;
      _deviceFrameDirty = false;
      if (framedDevice != null) {
        framedDevice.framePainter.addListener(_markDeviceFrameDirty);
        final recorder = ui.PictureRecorder();
        final (Size, Path) geometry;
        try {
          geometry = _paintDeviceFrame(
            Canvas(recorder),
            framedDevice,
            orientation,
          );
        } catch (_) {
          recorder.endRecording().dispose();
          rethrow;
        }
        _devicePicture = recorder.endRecording();
        _deviceSize = geometry.$1;
        _screenPath = geometry.$2;
      }
    }
    final captured = await captureElementImage(element);
    if (settings.showPointers || settings.pointerIndicator != null) {
      _scene?.image.dispose();
      _scene = CapturedImage(
        image: captured.image.clone(),
        logicalBounds: captured.logicalBounds,
        imageContentBounds: captured.imageContentBounds,
      );
    }
    _lastLayer = layer;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    _lastEngineLayer = layer.engineLayer;
    _lastBounds = bounds;
    _lastPaintBounds = renderObject.paintBounds;
    _pointers = positions;
    return _compose(captured, positions);
  }

  /// Repaints only overlays on the previous painted scene, not a future scene.
  Future<ui.Image> captureOverlay(List<Offset> pointers) => _compose(
    CapturedImage(
      image: _scene!.image.clone(),
      logicalBounds: _scene!.logicalBounds,
      imageContentBounds: _scene!.imageContentBounds,
    ),
    pointers,
  );

  void _markDeviceFrameDirty() => _deviceFrameDirty = true;

  bool _hasExternalContent(Layer layer) {
    if (layer is TextureLayer ||
        layer is PerformanceOverlayLayer ||
        layer is PlatformViewLayer) {
      return true;
    }
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        if (_hasExternalContent(child)) return true;
        child = child.nextSibling;
      }
    }
    return false;
  }

  Future<ui.Image> _compose(
    CapturedImage captured,
    List<Offset> positions,
  ) async {
    final image = captured.image;
    final framed = _devicePicture != null;
    final content = framed ? _screenPath.getBounds() : imageBounds(image);
    final size = framed ? _deviceSize : imageBounds(image).size;
    final mapping = CapturedImage(
      image: image,
      logicalBounds: captured.logicalBounds,
      imageContentBounds: content,
    );
    final background =
        settings.backgroundColor ??
        (settings.encoding.supportsAlpha
            ? const Color(0x00000000)
            : const Color(0xFFFFFFFF));
    if (!framed &&
        positions.isEmpty &&
        crop == null &&
        background.a == 0 &&
        image.width.isEven &&
        image.height.isEven) {
      return image;
    }
    var width = size.width.round();
    var height = size.height.round();
    final recorder = ui.PictureRecorder();
    ui.Picture? picture;
    final ui.Image output;
    try {
      final canvas = Canvas(recorder)
        ..save()
        ..clipRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()))
        ..save();
      if (framed) {
        canvas
          ..drawPicture(_devicePicture!)
          ..clipPath(_screenPath);
      }
      canvas
        ..drawImageRect(image, imageBounds(image), content, Paint())
        ..restore();
      _paintPointerIndicators(
        canvas,
        mapping,
        positions,
        painter: settings.pointerIndicator,
      );
      canvas.restore();
      if (crop == null) {
        width += width & 1;
        height += height & 1;
      }
      if (crop == null && background.a > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()
            ..color = background
            ..blendMode = BlendMode.dstOver,
        );
      }
      picture = recorder.endRecording();
      output = await picture.toImage(width, height);
    } finally {
      (picture ?? recorder.endRecording()).dispose();
      image.dispose();
    }
    // Crop the rasterized overlays, not their vector commands: scaling
    // vectors first would change antialiasing and pointer edge pixels.
    if (crop != null) {
      final cropped = await cropCapturedImage(output, crop!, mapping);
      final paddedWidth = cropped.width + (cropped.width & 1);
      final paddedHeight = cropped.height + (cropped.height & 1);
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawImage(cropped, Offset.zero, Paint())
        ..drawRect(
          Rect.fromLTWH(0, 0, paddedWidth.toDouble(), paddedHeight.toDouble()),
          Paint()
            ..color = background
            ..blendMode = BlendMode.dstOver,
        );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(paddedWidth, paddedHeight);
      } finally {
        picture.dispose();
        cropped.dispose();
      }
    }
    return output;
  }

  /// Releases cached engine resources when recording ends.
  void dispose() {
    _scene?.image.dispose();
    _scene = null;
    _device?.framePainter.removeListener(_markDeviceFrameDirty);
    _devicePicture?.dispose();
    _devicePicture = null;
    _lastLayer = null;
    _lastEngineLayer = null;
  }
}
