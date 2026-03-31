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
import 'package:snaptest/src/font_loading.dart';
import 'package:snaptest/src/snaptest_settings.dart';
import 'package:snaptest/src/test_devices_variant.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

/// Tracks the number of times snap has been called per test name.
/// Maps test name to call count.
final Map<String, int> _snapCallCounts = {};

/// The global [Snap] instance.
///
/// Use `snap()` for visual debugging screenshots, `snap.golden()` for golden
/// file comparison only, and `snap.andGolden()` for both.
///
/// ```dart
/// // Visual debugging screenshot
/// await snap();
///
/// // Golden comparison only (no .snaptest/ file)
/// await snap.golden();
///
/// // Both visual debugging + golden comparison
/// await snap.andGolden();
///
/// // Get a ui.Image without saving to disk
/// final image = await snap.image();
/// ```
const Snap snap = Snap._();

/// A callable class that provides methods for taking screenshots in widget
/// tests.
///
/// The primary instance is the top-level [snap] constant. Use it as a function
/// for visual debugging screenshots, or call its methods for golden file
/// comparison and image capture.
///
/// ## Usage
///
/// ```dart
/// // Visual debugging screenshot (saves to .snaptest/)
/// await snap();
///
/// // Golden file comparison only (no .snaptest/ file)
/// await snap.golden();
///
/// // Both visual debugging + golden comparison
/// await snap.andGolden();
///
/// // Get a ui.Image without saving to disk
/// final image = await snap.image();
/// ```
///
/// ## Device Simulation
///
/// All methods accept `device` and `orientation` parameters:
/// ```dart
/// await snap(device: Devices.ios.iPhone16Pro);
/// await snap.golden(device: Devices.ios.iPhone16Pro);
/// ```
///
/// Or use [TestDevicesVariant] to test multiple devices:
/// ```dart
/// testWidgets(
///   'my test',
///   variant: TestDevicesVariant({Devices.ios.iPhone16Pro}),
///   (tester) async {
///     await snap(); // device resolved from variant
///   },
/// );
/// ```
class Snap {
  const Snap._();

  /// Takes a visual debugging screenshot and saves it to the file system.
  ///
  /// If [settings] is not provided, the global default settings are used,
  /// which you can also set globally via [SnaptestSettings.global].
  ///
  /// The screenshot is saved as a PNG file with the given [name] in the
  /// directory specified by [SnaptestSettings.pathPrefix] (`.snaptest/` by
  /// default). If no [name] is provided, the name of the current test is used.
  ///
  /// ## Multiple Calls Per Test
  ///
  /// When called multiple times in the same test without providing a [name],
  /// a counter suffix is automatically added to prevent overwriting:
  /// ```dart
  /// testWidgets('my test', (tester) async {
  ///   await snap(); // Creates: my_test.png
  ///   await snap(); // Creates: my_test_2.png
  ///   await snap(); // Creates: my_test_3.png
  /// });
  /// ```
  ///
  /// The screenshot will be taken from the [from] [Finder] and if none is
  /// provided, the screenshot will be taken from the whole screen.
  Future<List<File>> call({
    String? name,
    Finder? from,
    SnaptestSettings? settings,
    DeviceInfo? device,
    Orientation? orientation,
  }) async {
    final s = settings ?? SnaptestSettings.global;
    final resolved = _resolve(
      name: name,
      device: device,
      orientation: orientation,
    );

    final restore = await _setUpForSettings(s);

    final image = await _takeDeviceScreenshot(
      device: resolved.device,
      orientation: resolved.orientation,
      from: from,
      settings: s,
    );

    final file = await _saveScreenshot(
      image: image,
      fileName: resolved.fileName,
      pathPrefix: s.pathPrefix,
    );

    restore();
    return [file];
  }

  /// Takes a golden comparison screenshot and runs [matchesGoldenFile].
  ///
  /// Does **not** save a visual debugging screenshot. Use [andGolden] if you
  /// want both.
  ///
  /// By default the golden is rendered with [SnaptestSettings.goldens]
  /// (blocked text, no shadows, no images, no device frame) for cross-platform
  /// consistency. Pass [settings] to override.
  Future<List<File>> golden({
    String? name,
    Finder? from,
    SnaptestSettings? settings,
    DeviceInfo? device,
    Orientation? orientation,
    String prefix = 'goldens/',
  }) async {
    final goldenSettings = settings ?? SnaptestSettings.goldens;
    final resolved = _resolve(
      name: name,
      device: device,
      orientation: orientation,
    );

    final restore = await _setUpForSettings(goldenSettings);

    final goldenImage = await _takeDeviceScreenshot(
      device: resolved.device,
      orientation: resolved.orientation,
      from: from,
      settings: goldenSettings,
    );

    restore();

    if (goldenImage == null) {
      throw Exception('Could not take golden screenshot.');
    }

    final goldenFile = await _saveScreenshot(
      image: goldenImage,
      fileName: resolved.fileName,
      pathPrefix: goldenSettings.pathPrefix,
    );

    await expectLater(
      goldenImage,
      matchesGoldenFile(join(prefix, resolved.fileName)),
    );

    return [goldenFile];
  }

  /// Takes a visual debugging screenshot **and** a golden comparison
  /// screenshot.
  ///
  /// The visual snap uses [settings] (or [SnaptestSettings.global]), and the
  /// golden uses [goldenSettings] (or [SnaptestSettings.goldens]).
  ///
  /// Returns a record of (snapshots, goldens) file lists.
  Future<(List<File> snapshots, List<File> goldens)> andGolden({
    String? name,
    Finder? from,
    SnaptestSettings? settings,
    SnaptestSettings? goldenSettings,
    DeviceInfo? device,
    Orientation? orientation,
    String prefix = 'goldens/',
  }) async {
    final s = settings ?? SnaptestSettings.global;
    final gs = goldenSettings ?? SnaptestSettings.goldens;
    final resolved = _resolve(
      name: name,
      device: device,
      orientation: orientation,
    );

    final restore = await _setUpForSettings(s);

    final image = await _takeDeviceScreenshot(
      device: resolved.device,
      orientation: resolved.orientation,
      from: from,
      settings: s,
    );

    final file = await _saveScreenshot(
      image: image,
      fileName: resolved.fileName,
      pathPrefix: s.pathPrefix,
    );

    restore();

    // Take golden screenshot (potentially with different settings)
    final goldenRestore = await _setUpForSettings(gs);

    final goldenImage = await _takeDeviceScreenshot(
      device: resolved.device,
      orientation: resolved.orientation,
      settings: gs,
      from: from,
    );

    goldenRestore();

    final File? goldenFile;
    if (goldenImage != null) {
      goldenFile = await _saveScreenshot(
        image: goldenImage,
        fileName: resolved.fileName,
        pathPrefix: gs.pathPrefix,
      );

      await expectLater(
        goldenImage,
        matchesGoldenFile(join(prefix, resolved.fileName)),
      );
    } else {
      throw Exception('Could not take golden screenshot.');
    }

    return ([file], [goldenFile]);
  }

  /// Same as [call] but returns a [ui.Image] instead of saving to disk.
  ///
  /// Useful for custom image processing workflows, generating assets, or
  /// compositing screenshots programmatically.
  Future<ui.Image?> image({
    String? name,
    Finder? from,
    SnaptestSettings? settings,
    DeviceInfo? device,
    Orientation? orientation,
  }) async {
    final s = settings ?? SnaptestSettings.global;
    final resolved = _resolve(
      name: name,
      device: device,
      orientation: orientation,
    );

    final restore = await _setUpForSettings(s);

    final result = await _takeDeviceScreenshot(
      device: resolved.device,
      orientation: resolved.orientation,
      from: from,
      settings: s,
    );

    restore();
    return result;
  }
}

/// Resolves name, device, orientation, and builds the filename.
_Resolved _resolve({
  String? name,
  DeviceInfo? device,
  Orientation? orientation,
}) {
  final testName = name ?? Invoker.current?.liveTest.test.name;

  if (testName == null) {
    throw Exception('Could not determine a name for the screenshot.');
  }

  // Track the number of times snap has been called for this test
  final callCount = _snapCallCounts[testName] =
      (_snapCallCounts[testName] ?? 0) + 1;
  final counterSuffix = callCount > 1 ? '_$callCount' : '';

  // Resolve device and orientation: explicit param > variant > defaults
  final resolvedDevice = device ?? activeDeviceVariant?.$1;
  final resolvedOrientation =
      orientation ?? activeDeviceVariant?.$2 ?? Orientation.portrait;
  final deviceFromExplicitParam = device != null;

  // Only append device/orientation to filename when explicitly passed,
  // since the variant framework already includes the variant description
  // in the test name.
  final deviceAppendix =
      deviceFromExplicitParam &&
          resolvedDevice != null &&
          resolvedDevice.name.isNotEmpty
      ? '_${resolvedDevice.name.toValidFilename()}'
      : '';

  final orientationAppendix =
      deviceFromExplicitParam && resolvedOrientation == Orientation.landscape
      ? '_landscape'
      : '';

  final fileName =
      '${testName.toValidFilename()}'
      '$counterSuffix$deviceAppendix$orientationAppendix.png';

  return _Resolved(
    device: resolvedDevice,
    orientation: resolvedOrientation,
    fileName: fileName,
  );
}

class _Resolved {
  const _Resolved({
    required this.device,
    required this.orientation,
    required this.fileName,
  });

  final DeviceInfo? device;
  final Orientation orientation;
  final String fileName;
}

/// Saves a screenshot image to disk.
Future<File> _saveScreenshot({
  required ui.Image? image,
  required String fileName,
  required String pathPrefix,
}) async {
  late final File file;

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
            basedir.resolve(join(pathPrefix, fileName)),
            null,
          )
          .toFilePath();
    } else {
      throw Exception('Could not determine a path for the screenshot.');
    }

    file = File(path);

    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    await file.writeAsBytes(bytes);
  });

  return file;
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
/// final restore = setTestViewForDevice(Devices.ios.iPhone16Pro);
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
VoidCallback setTestViewForDevice(
  DeviceInfo? device,
  Orientation orientation,
) {
  final implicitView =
      TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
  final previousTargetPlatform = debugDefaultTargetPlatformOverride;

  void restore() {
    debugDefaultTargetPlatformOverride = previousTargetPlatform;
    implicitView
      ..resetPhysicalSize()
      ..resetPadding()
      ..resetDevicePixelRatio();
  }

  if (device == null) {
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
Future<ui.Image?> _takeDeviceScreenshot({
  required DeviceInfo? device,
  required SnaptestSettings settings,
  required Orientation orientation,
  Finder? from,
}) async {
  final finder = from ?? find.byType(View);

  final image = await _runInFakeDevice(
    device,
    orientation,
    () async {
      await TestWidgetsFlutterBinding.instance.pump(Duration.zero);

      return finder.captureImage(
        blockText: settings.blockText,
        device: device,
        orientation: orientation,
        includeDeviceFrame: settings.includeDeviceFrame,
      );
    },
  );

  return image;
}

Future<VoidCallback> _setUpForSettings(SnaptestSettings settings) async {
  // final restoreImages = TestWidgetsFlutterBinding.instance.imageCache.clear;
  await loadFonts();

  final previousShadows = debugDisableShadows;

  debugDisableShadows = !settings.renderShadows;

  return () {
    debugDisableShadows = previousShadows;
  };
}

/// Pre-caches all images so that they will be rendered correctly when taking
/// screenshots.
///
/// An optional [Finder] can be provided to limit the scope of the precaching to
/// matching descendants of that [Finder].
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
  DeviceInfo? device,
  Orientation orientation,
  Future<T> Function() fn,
) async {
  final binding = TestWidgetsFlutterBinding.instance;
  await binding.pump(Duration.zero);

  final restoreView = setTestViewForDevice(device, orientation);

  final result = await maybeRunAsync(fn);

  restoreView();

  await binding.pump(Duration.zero);

  return result;
}

/// Allows capturing the closest [RepaintBoundary] of a [Finder] into an image.
extension CaptureFinder on Finder {
  /// Captures this finder's closest [RepaintBoundary] into an image.
  ///
  /// Will throw if this finder doesn't evaluate to exactly one element.
  ///
  /// See also:
  /// - [CaptureImage] to capture an element that contains a
  /// [RepaintBoundary].
  Future<ui.Image> captureImage({
    bool blockText = false,
    DeviceInfo? device,
    Orientation orientation = Orientation.portrait,
    bool includeDeviceFrame = false,
  }) {
    return evaluate().single.captureImage(
      blockText: blockText,
      device: device,
      orientation: orientation,
      includeDeviceFrame: includeDeviceFrame,
    );
  }
}

/// Allows capturing the closest [RepaintBoundary] of an element into an image.
extension CaptureImage on Element {
  /// Renders the closest [RepaintBoundary] of this element into an image.
  ///
  /// Set [blockText] to `true` to replace text with colored rectangles for
  /// cross-platform consistency in golden tests.
  ///
  /// If [includeDeviceFrame] is `true` and a [device] is provided, the image
  /// will be wrapped with the device's frame.
  ///
  /// See also:
  /// - [CaptureFinder] to capture a finder that contains a [RepaintBoundary].
  Future<ui.Image> captureImage({
    bool blockText = false,
    DeviceInfo? device,
    Orientation orientation = Orientation.portrait,
    bool includeDeviceFrame = false,
  }) async {
    return _captureImage(
      this,
      blockText: blockText,
      device: device,
      orientation: orientation,
      includeDeviceFrame: includeDeviceFrame,
    );
  }
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
Future<ui.Image> _captureImage(
  Element element, {
  bool blockText = false,
  DeviceInfo? device,
  Orientation orientation = Orientation.portrait,
  bool includeDeviceFrame = false,
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
