import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart';
import 'package:device_frame/device_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/src/fake_device.dart';
import 'package:snaptest/src/snaptest_settings.dart';
import 'package:spot/spot.dart' as spot;

// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

/// Saves a screenshot of the current state of the widget test as if it was
/// rendered on each device in [settings].devices to the file system.
///
/// If [settings] is not provided, the global default settings are used,
/// which you can also set globally via [SnaptestSettings.global].
///
/// The screenshot is saved as a PNG file with the given [name] in the given
/// [pathPrefix] (`.snaptest/` by default), optionally appending the device name to
/// the file name. If no [name] is provided, the name of the current test is
/// used.
///
/// The Screenshot will be taken from the [from] [Finder] and if none is
/// provided, the screenshot will be taken from the whole screen.
///
/// You can decide whether shadows should be rendered or not by setting
/// [SnaptestSettings.renderShadows] to `true` or `false`. If not provided, the
/// global default is used, which you can also set globally via
/// [SnaptestSettings.global].
Future<List<File>> snap({
  String? name,
  Finder? from,
  bool appendDeviceName = true,
  SnaptestSettings? settings,
  String pathPrefix = '.snaptest/',
}) async {
  final s = settings ?? SnaptestSettings.global;
  final testName = name ?? Invoker.current?.liveTest.test.name;

  final restore = await _setUpForSettings(s);

  if (testName == null) {
    throw Exception('Could not determine a name for the screenshot.');
  }

  final files = <File>[];

  for (final device in s.devices) {
    final image = await takeDeviceScreenshot(
      device: device,
      from: from,
      settings: s,
    );

    await maybeRunAsync(() async {
      final byteData = await image?.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null) {
        throw Exception('Could not encode screenshot.');
      }

      final appendix = appendDeviceName && device.name.isNotEmpty
          ? '_${device.name.toValidFilename()}'
          : '';

      final fileName = '$pathPrefix${testName.toValidFilename()}$appendix.png';

      final String? path;

      if (goldenFileComparator case LocalFileComparator(:final basedir)) {
        path = goldenFileComparator
            .getTestUri(basedir.resolve(fileName), null)
            .toFilePath();
      } else {
        throw Exception('Could not determine a path for the screenshot.');
      }

      final file = File(path);

      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }

      await file.writeAsBytes(bytes);

      files.add(file);
    });
  }

  restore();

  return files;
}

/// Runs a given function [fn] in a runAsync block.
///
/// If the function is already in a runAsync block, it will be run immediately.
/// Otherwise, it will be run in a runAsync block.
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

/// Sets the test view to the given [device] and returns a callback that
/// restores the previous state.
///
/// If [device] is `null`, the test view will be reset to the previous state.
///
/// Example usage:
///
/// ```dart
/// final restore = setTestViewToFakeDevice(Devices.ios.iPhone16Pro);
///
/// // ...
///
/// restore();
VoidCallback setTestViewToFakeDevice(DeviceInfo device) {
  final implicitView =
      TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;

  void restore() {
    debugDefaultTargetPlatformOverride = null;
    implicitView
      ..resetPhysicalSize()
      ..resetPadding()
      ..resetDevicePixelRatio();
  }

  if (device is WidgetTesterDevice) {
    restore();
    return () {};
  }

  implicitView
    ..physicalSize = device.screenSize * device.pixelRatio
    ..padding = device.safeAreas.toFakeViewPadding()
    ..devicePixelRatio = device.pixelRatio;

  debugDefaultTargetPlatformOverride = device.identifier.platform;

  return restore;
}

/// Takes a screenshot of the current state of the widget test as if it was
/// rendered on the given [device].
///
/// If [from] is provided, the screenshot will be taken from the given [Finder].
/// Otherwise, the screenshot will be taken from the whole screen.
///

Future<ui.Image?> takeDeviceScreenshot({
  required DeviceInfo device,
  required SnaptestSettings settings,
  Finder? from,
}) async {
  final finder = from ?? find.byType(View);

  final element = finder.evaluate().single;

  final image = await _runInFakeDevice(
    device,
    () async {
      await TestWidgetsFlutterBinding.instance.pump(Duration.zero);

      return _captureImage(
        element,
        blockText: settings.blockText,
        device: device,
        includeDeviceFrame: settings.includeDeviceFrame,
      );
    },
  );

  return image;
}

bool _fontsLoaded = false;

Future<VoidCallback> _setUpForSettings(SnaptestSettings settings) async {
  final restoreImages = TestWidgetsFlutterBinding.instance.imageCache.clear;

  if (settings.renderImages) {
    await precacheImages();
  } else {
    restoreImages();
  }

  if (!settings.blockText) {
    await loadAppFonts();
  }

  final previousShadows = debugDisableShadows;

  debugDisableShadows = !settings.renderShadows;

  return () {
    debugDisableShadows = previousShadows;
    restoreImages();
  };
}

/// Loads all fonts that the app uses so that they will be rendered correctly
/// when taking screenshots.
///
/// {@macro snaptest.fake_device.renderingUndoDisclaimer}
Future<void> loadAppFonts() async {
  if (_fontsLoaded) {
    return;
  }

  await spot.loadAppFonts();
  _fontsLoaded = true;
}

/// Pre-caches all images so that they will be rendered correctly when taking
/// screenshots.
///
/// An optional [Finder] can be provided to limit the scope of the precaching to
/// matching descendants of that [Finder].
///
/// {@macro snaptest.fake_device.renderingUndoDisclaimer}
Future<void> precacheImages([Finder? from]) async {
  final finder = from ?? find.byType(View);
  await TestWidgetsFlutterBinding.instance.runAsync(() async {
    final children = find.descendant(
      of: finder,
      matching: find.bySubtype<Image>(),
    );

    final operations = children.evaluate().map((e) {
      final image = e.widget as Image;

      return precacheImage(image.image, e);
    });

    return Future.wait(operations);
  });
}

/// Runs a given function [fn] in a [DeviceInfo] [device].
///
/// Resets the testers view to the previous state after the function has
/// finished.
Future<T?> _runInFakeDevice<T>(
  DeviceInfo device,
  Future<T> Function() fn,
) async {
  final binding = TestWidgetsFlutterBinding.instance;
  await binding.pump(Duration.zero);

  final restoreView = setTestViewToFakeDevice(device);

  final result = await maybeRunAsync(fn);

  restoreView();

  await binding.pump(Duration.zero);

  return result;
}

/// Render the closest [RepaintBoundary] of the [element] into an image.
///
/// See also:
///
///  * [OffsetLayer.toImage] which is the actual method being called.
Future<ui.Image> _captureImage(
  Element element, {
  required bool blockText,
  required DeviceInfo device,
  required bool includeDeviceFrame,
}) async {
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

  final layer = renderObject.debugLayer! as OffsetLayer;

  if (blockText) {
    BlockedTextPaintingContext(
      containerLayer: layer,
      estimatedBounds: renderObject.paintBounds,
    ).paintSingleChild(renderObject);
  }

  final image = await layer.toImage(renderObject.paintBounds);

  if (element.renderObject is RenderBox) {
    final expectedSize = (element.renderObject as RenderBox?)!.size;
    if (expectedSize.width != image.width ||
        expectedSize.height != image.height) {
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

  if (includeDeviceFrame && device is! WidgetTesterDevice) {
    return _wrapImageWithDeviceFrame(image, device);
  }

  return image;
}

/// Wraps the given [image] with a device frame for the specified [device].
///
/// This creates a new image that includes the device frame around the content
/// without modifying the original widget tree.
Future<ui.Image> _wrapImageWithDeviceFrame(
  ui.Image image,
  DeviceInfo device,
) async {
  // Create a picture recorder to draw the device frame
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final deviceFrameSize = device.frameSize;

  device.framePainter.paint(canvas, deviceFrameSize);

  // Calculate the screen area within the device frame
  final screenRect = Rect.fromCenter(
    center: Offset(deviceFrameSize.width / 2, deviceFrameSize.height / 2),
    width: device.screenSize.width / device.pixelRatio,
    height: device.screenSize.height / device.pixelRatio,
  );

  // Draw the captured image in the screen area
  canvas.drawImageRect(
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
  return framedImage;
}

extension on String {
  String toValidFilename() => replaceAll(RegExp(r'[^\w\s]'), '');
}

extension on EdgeInsets {
  FakeViewPadding toFakeViewPadding() => FakeViewPadding(
    bottom: bottom,
    left: left,
    right: right,
    top: top,
  );
}
