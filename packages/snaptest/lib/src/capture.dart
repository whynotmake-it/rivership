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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:snaptest/src/blocked_text_painting_context.dart';

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
  return croppedImage;
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

  // Calculate the screen area within the device frame
  final screenRect = screenPath.getBounds();

  canvas
    ..clipPath(screenPath)
    // Draw the captured image in the screen area
    ..drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      screenRect,
      Paint(),
    );

  // Convert to image
  final picture = recorder.endRecording();
  final framedImage = await picture.toImage(
    deviceFrameSize.width.round(),
    deviceFrameSize.height.round(),
  );

  picture.dispose();
  image.dispose();
  return FramedImage(image: framedImage, screenBounds: screenRect);
}
