import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_frame/device_frame.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapper/src/fake_device.dart';
import 'package:snapper/src/snap_settings.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

/// Saves a screenshot of the current state of the widget test as if it was
/// rendered on each device in [devices] to the file system.
///
/// If [devices] is not provided, the global default list of devices is used,
/// which you can also set globally via [SnapSettings.devices].
///
/// The screenshot is saved as a PNG file with the given [name] in the given
/// [pathPrefix] (`.snapper/` by default), optionally appending the device name to
/// the file name. If no [name] is provided, the name of the current test is
/// used.
///
/// The Screenshot will be taken from the [from] [Finder] and if none is
/// provided, the screenshot will be taken from the whole screen.
///
/// You can decide whether shadows should be rendered or not by setting
/// [renderShadows] to `true` or `false`. If not provided, the global default
/// is used, which you can also set globally via [SnapSettings.renderShadows].
Future<List<File>> snap({
  List<DeviceInfo>? devices,
  String? name,
  Finder? from,
  bool appendDeviceName = true,
  bool? renderShadows,
  String pathPrefix = '.snapper/',
}) async {
  final testName = name ?? Invoker.current?.liveTest.test.name;

  if (testName == null) {
    throw Exception('Could not determine a name for the screenshot.');
  }

  final files = <File>[];

  for (final device in devices ?? SnapSettings.devices) {
    final image = await takeDeviceScreenshot(
      device: device,
      from: from,
      renderShadows: renderShadows,
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
/// Example usage:
///
/// ```dart
/// final restore = setTestViewToFakeDevice(FakeDevice.reweMde);
///
/// // ...
///
/// restore();
VoidCallback setTestViewToFakeDevice(DeviceInfo device) {
  final implicitView =
      TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;

  if (device is WidgetTesterDevice) {
    return () {};
  }

  final prevResolution = implicitView.physicalSize;
  final prevPadding = implicitView.padding;
  final prevPixelRatio = implicitView.devicePixelRatio;

  implicitView
    ..physicalSize = device.screenSize * device.pixelRatio
    ..padding = device.safeAreas.toFakeViewPadding()
    ..devicePixelRatio = device.pixelRatio;

  return () {
    implicitView
      ..physicalSize = prevResolution
      ..padding = prevPadding
      ..devicePixelRatio = prevPixelRatio;
  };
}

/// Takes a screenshot of the current state of the widget test as if it was
/// rendered on the given [device].
///
/// If [from] is provided, the screenshot will be taken from the given [Finder].
/// Otherwise, the screenshot will be taken from the whole screen.
///
/// You can decide whether shadows should be rendered or not by setting
/// [renderShadows] to `true` or `false`. If not provided, the global default
/// is used, which you can also set globally via [SnapSettings.renderShadows].
Future<ui.Image?> takeDeviceScreenshot({
  required DeviceInfo device,
  Finder? from,
  bool? renderShadows,
}) async {
  final finder = from ?? find.byType(View);

  final element = finder.evaluate().single;

  final image = await _runInFakeDevice(
    device,
    () => _captureImage(element),
    disableShadows: !(renderShadows ?? SnapSettings.renderShadows),
  );

  return image;
}

/// Runs a given function [fn] in a [FakeDevice] [device].
///
/// Resets the testers view to the previous state after the function has
/// finished.
Future<T?> _runInFakeDevice<T>(
  DeviceInfo device,
  Future<T> Function() fn, {
  bool disableShadows = true,
}) async {
  final binding = TestWidgetsFlutterBinding.instance;

  final restoreView = setTestViewToFakeDevice(device);

  final prevDisableShadows = debugDisableShadows;
  debugDisableShadows = disableShadows;

  await TestAsyncUtils.guard<void>(binding.pump);

  final result = await maybeRunAsync(fn);

  restoreView();

  debugDisableShadows = prevDisableShadows;

  await TestAsyncUtils.guard<void>(binding.pump);

  return result;
}

/// Render the closest [RepaintBoundary] of the [element] into an image.
///
/// See also:
///
///  * [OffsetLayer.toImage] which is the actual method being called.
Future<ui.Image> _captureImage(Element element) async {
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

  return image;
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
