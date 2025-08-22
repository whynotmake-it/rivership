import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_frame/device_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:snaptest/src/blocked_text_painting_context.dart';
import 'package:snaptest/src/fake_device.dart';
import 'package:snaptest/src/flutter_sdk_root.dart';
import 'package:snaptest/src/snaptest_settings.dart';
import 'package:spot/spot.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

/// Saves a screenshot of the current state of the widget test as if it was
/// rendered on each device in [settings].devices and each orientation in
/// [settings].orientations to the file system.
///
/// If [settings] is not provided, the global default settings are used,
/// which you can also set globally via [SnaptestSettings.global].
///
/// The screenshot is saved as a PNG file with the given [name] in the directory
/// specified by [SnaptestSettings.pathPrefix] (`.snaptest/` by default),
/// optionally appending the device name and orientation to the file name.
/// If no [name] is provided, the name of the current test is used.
///
/// ## Multiple Devices and Orientations
///
/// When multiple devices and orientations are specified, separate screenshots
/// are created for each device and orientation with suffixes like
/// `_iPhone16Pro_portrait` and `_samsungGalaxyS20_landscape`:
/// ```dart
/// await snap(
///   settings: SnaptestSettings.rendered(
///     devices: [
///       Devices.ios.iPhone16Pro,
///       Devices.android.samsungGalaxyS20,
///     ],
///     orientations: {Orientation.portrait, Orientation.landscape},
///   ),
/// );
/// // Creates: my_test_iPhone16Pro_portrait.png, my_test_iPhone16Pro_landscape.png
/// ```
///
/// Note: Device names and orientations are only appended if there are multiple
/// devices or orientations.
/// If you want to always append the device name or orientation, set
/// [alwaysAppendDeviceName] or [alwaysAppendOrientation] to `true`.
///
/// The Screenshot will be taken from the [from] [Finder] and if none is
/// provided, the screenshot will be taken from the whole screen.
///
/// You can decide whether shadows should be rendered or not by setting
/// [SnaptestSettings.renderShadows] to `true` or `false`. If not provided, the
/// global default is used, which you can also set globally via
/// [SnaptestSettings.global].
///
/// The directory where screenshots are saved can be customized by setting
/// [SnaptestSettings.pathPrefix]. By default, screenshots are saved to
/// `.snaptest/`.
///
/// ## Golden File Comparison
///
/// When [matchToGolden] is set to `true`, the function performs golden file
/// comparison testing in addition to saving screenshots. This creates a
/// reference image for each device in [settings] with golden-friendly settings.
///
/// It will then invoke the [matchesGoldenFile] matcher.
///
/// See the documentation for this matcher to learn more about golden testing.
Future<List<File>> snap({
  String? name,
  Finder? from,
  SnaptestSettings? settings,
  bool matchToGolden = false,
  String goldenPrefix = 'goldens/',
  bool alwaysAppendDeviceName = false,
  bool alwaysAppendOrientation = false,
}) async {
  final s = settings ?? SnaptestSettings.global;
  final testName = name ?? Invoker.current?.liveTest.test.name;

  final restore = await _setUpForSettings(s);

  if (testName == null) {
    throw Exception('Could not determine a name for the screenshot.');
  }

  if (s.devices.isEmpty) {
    throw ArgumentError.value(
      s.devices,
      'devices',
      'No devices to screenshot.',
    );
  }

  if (s.orientations.isEmpty) {
    throw ArgumentError.value(
      s.orientations,
      'orientations',
      'No orientations to screenshot.',
    );
  }

  final files = <File>[];

  final goldens = <(String, ui.Image)>[];

  final rotatedDevices = s.devices.where((device) => device.canRotate);

  final appendDeviceName = alwaysAppendDeviceName || s.devices.length > 1;
  final appendOrientation =
      alwaysAppendOrientation ||
      (s.orientations.length > 1 && rotatedDevices.isNotEmpty);

  for (final device in s.devices) {
    for (final orientation in s.orientations) {
      if (!device.canRotate && orientation == Orientation.landscape) {
        continue;
      }

      final image = await takeDeviceScreenshot(
        device: device,
        orientation: orientation,
        from: from,
        settings: s,
      );

      final goldenImage = switch (matchToGolden) {
        true => await takeDeviceScreenshot(
          device: device,
          orientation: orientation,
          settings: const SnaptestSettings(),
        ),
        false => null,
      };

      final deviceAppendix = appendDeviceName && device.name.isNotEmpty
          ? '_${device.name.toValidFilename()}'
          : '';

      final orientationAppendix = appendOrientation
          ? '_${orientation.name}'
          : '';

      final fileName =
          '${testName.toValidFilename()}'
          '$deviceAppendix$orientationAppendix.png';

      await maybeRunAsync(() async {
        final byteData = await image?.toByteData(
          format: ui.ImageByteFormat.png,
        );
        final bytes = byteData?.buffer.asUint8List();

        if (bytes == null) {
          throw Exception('Could not encode screenshot.');
        }

        final String? path;

        if (goldenFileComparator case LocalFileComparator(:final basedir)) {
          path = goldenFileComparator
              .getTestUri(
                basedir.resolve(join(s.pathPrefix, fileName)),
                null,
              )
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

      if (goldenImage != null) {
        goldens.add((join(goldenPrefix, fileName), goldenImage));
      }
    }
  }

  restore();

  for (final (key, image) in goldens) {
    await expectLater(image, matchesGoldenFile(key));
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

/// Temporarily changes the test environment to simulate a specific device.
///
/// This is a lower-level function that [snap] uses internally. You typically
/// don't need to call this directly - just use [snap] with device settings
/// instead.
///
/// Returns a callback to restore the original test environment:
/// ```dart
/// final restore = setTestViewToFakeDevice(Devices.ios.iPhone16Pro);
///
/// // Test environment now simulates iPhone 16 Pro
/// await tester.pumpWidget(MyApp());
///
/// // Restore original test environment
/// restore();
/// ```
///
/// The [snap] function handles this automatically, so prefer using [snap] with
/// [SnaptestSettings] instead of calling this directly.
VoidCallback setTestViewToFakeDevice(
  DeviceInfo device,
  Orientation orientation,
) {
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

  // Get screen size based on orientation
  var screenSize = device.screenSize;
  var safeAreas = device.safeAreas;

  if (device.isLandscape(orientation)) {
    // Swap width and height for landscape
    screenSize = screenSize.flipped;
    // Rotate safe areas for landscape (90 degrees clockwise)
    // Portrait: top=notch, right=0, bottom=home, left=0
    // Landscape: left=notch, top=0, right=home, bottom=0
    safeAreas = device.rotatedSafeAreas!;
  }

  implicitView
    ..physicalSize = screenSize * device.pixelRatio
    ..padding = safeAreas.toFakeViewPadding(
      devicePixelRatio: device.pixelRatio,
    )
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
  required Orientation orientation,
  Finder? from,
}) async {
  final finder = from ?? find.byType(View);

  final element = finder.evaluate().single;

  final image = await _runInFakeDevice(
    device,
    orientation,
    () async {
      await TestWidgetsFlutterBinding.instance.pump(Duration.zero);

      return _captureImage(
        element,
        blockText: settings.blockText,
        device: device,
        orientation: orientation,
        includeDeviceFrame: settings.includeDeviceFrame,
      );
    },
  );

  return image;
}

bool _fontsLoaded = false;

/// Loads fonts and icons required for consistent screenshot rendering.
///
/// This function ensures that all fonts (including system fonts) and icons
/// are properly loaded before taking screenshots. It should be called once
/// before running any tests that use [snap] to ensure consistent text
/// rendering across all screenshots.
///
/// **Important**: Once fonts are loaded, they cannot be unloaded due to
/// Flutter's limitations. This means that if [loadFontsAndIcons] is called
/// during one test, all subsequent tests in the same test run will use the
/// loaded fonts, which may cause text to render differently than in a fresh
/// test environment.
///
/// ## Recommended Usage
///
/// Add this to your `flutter_test_config.dart` file to ensure fonts are
/// loaded before all tests:
///
/// ```dart
/// import 'dart:async';
/// import 'package:snaptest/snaptest.dart';
///
/// Future<void> testExecutable(FutureOr<void> Function() testMain) async {
///   await loadFontsAndIcons();
///   await testMain();
/// }
/// ```
///
/// This prevents side effects where [snap] calls might produce different
/// results depending on whether fonts were loaded in previous tests.
///
/// ## What it does
///
/// - Loads all application fonts defined in `pubspec.yaml`
/// - Overrides Cupertino system fonts with Roboto for consistency, since
/// Cupertino fonts can't be loaded on all platforms
/// - Ensures icons are properly loaded for rendering
/// - Sets a flag to prevent duplicate loading in the same test session
///
/// The function is idempotent - calling it multiple times has no additional
/// effect after the first call.
Future<void> loadFontsAndIcons() async {
  if (_fontsLoaded) return;

  await loadAppFonts();
  await _overrideCupertinoFonts();

  _fontsLoaded = true;
}

Future<VoidCallback> _setUpForSettings(SnaptestSettings settings) async {
  final restoreImages = TestWidgetsFlutterBinding.instance.imageCache.clear;

  if (settings.renderImages) {
    await precacheImages();
  } else {
    restoreImages();
  }

  await loadFontsAndIcons();

  final previousShadows = debugDisableShadows;

  debugDisableShadows = !settings.renderShadows;

  return () {
    debugDisableShadows = previousShadows;
    restoreImages();
  };
}

Future<void> _overrideCupertinoFonts() async {
  final root = flutterSdkRoot().absolute.path;

  final materialFontsDir = Directory(
    '$root/bin/cache/artifacts/material_fonts/',
  );

  final fontFormats = ['.ttf', '.otf', '.ttc'];
  final existingFonts = materialFontsDir
      .listSync()
      // dartfmt come on,...
      .whereType<File>()
      .where(
        (font) => fontFormats.any((element) => font.path.endsWith(element)),
      )
      .toList();

  final robotoFonts = existingFonts
      .where((font) {
        final name = basename(font.path).toLowerCase();
        return name.startsWith('Roboto-'.toLowerCase());
      })
      .map((file) => file.path)
      .toList();
  if (robotoFonts.isEmpty) {
    debugPrint("Warning: No Roboto font found in SDK");
  }
  await loadFont('CupertinoSystemText', robotoFonts);
  await loadFont('CupertinoSystemDisplay', robotoFonts);
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
  Orientation orientation,
  Future<T> Function() fn,
) async {
  final binding = TestWidgetsFlutterBinding.instance;
  await binding.pump(Duration.zero);

  final restoreView = setTestViewToFakeDevice(device, orientation);

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
  required Orientation orientation,
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

  if (includeDeviceFrame && device is! WidgetTesterDevice) {
    return _wrapImageWithDeviceFrame(image, device, orientation);
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
      ..translateByDouble(
        deviceFrameSize.width / 2,
        deviceFrameSize.height / 2,
        0,
        0,
      )
      ..rotateZ(1.5708) // 90 degrees in radians
      ..translateByDouble(
        -device.frameSize.width / 2,
        -device.frameSize.height / 2,
        0,
        0,
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
  return framedImage;
}

extension on String {
  String toValidFilename() => replaceAll(RegExp(r'[^\w\s]'), '');
}

extension on EdgeInsets {
  FakeViewPadding toFakeViewPadding({double devicePixelRatio = 1}) =>
      FakeViewPadding(
        bottom: bottom * devicePixelRatio,
        left: left * devicePixelRatio,
        right: right * devicePixelRatio,
        top: top * devicePixelRatio,
      );
}
