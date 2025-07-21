import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart' as spot;

/// Represents a fake device for testing purposes.
///
/// Properties that are `null` will not be overridden for the screenshot.
class FakeDevice with EquatableMixin {
  /// Creates a fake device.
  ///
  /// [name] is the name of the device.
  /// [resolution] is the resolution of the device.
  /// [devicePixelRatio] is the device pixel ratio of the device.
  /// [viewPadding] is the view padding of the device.
  const FakeDevice({
    required this.name,
    this.resolution,
    this.devicePixelRatio,
    this.viewPadding,
  });

  /// The default fake device, which will not override any properties.
  static const FakeDevice none = FakeDevice(name: '');

  /// Properties of an iPhone 16 Pro.
  static const FakeDevice iPhone16Pro = FakeDevice(
    name: 'iPhone 16 Pro',
    resolution: Size(1290, 2796),
    viewPadding: EdgeInsets.only(bottom: 34, top: 62),
    devicePixelRatio: 3,
  );

  /// Properties of an iPhone SE (2020).
  static const FakeDevice iPhoneSE2020 = FakeDevice(
    name: 'iPhone SE (2020)',
    resolution: Size(750, 1334),
    viewPadding: EdgeInsets.only(top: 20),
    devicePixelRatio: 2,
  );

  /// The name of the device.
  final String name;

  /// The resolution of the device in physical pixels.
  final Size? resolution;

  /// The view padding of the device in logical pixels.
  final EdgeInsets? viewPadding;

  /// The device pixel ratio of the device.
  final double? devicePixelRatio;

  @override
  List<Object?> get props => [name, resolution, viewPadding, devicePixelRatio];

  /// Creates a copy of this fake device with the given properties overridden.
  FakeDevice copyWith({
    Size? resolution,
    EdgeInsets? viewPadding,
    double? devicePixelRatio,
  }) => FakeDevice(
    name: name,
    resolution: resolution ?? this.resolution,
    viewPadding: viewPadding ?? this.viewPadding,
    devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
  );

  /// Whether the device is in landscape mode.
  bool get isLandscape => switch (resolution) {
    null => false,
    Size(aspectRatio: >= 1) => true,
    Size() => false,
  };

  /// Creates a copy of this fake device in portrait mode.
  FakeDevice portrait() => copyWith(
    resolution: switch (resolution) {
      // Flip width and height if aspect ratio is greater than 1
      Size(:final width, :final height, aspectRatio: >= 1) => Size(
        height,
        width,
      ),
      Size(:final width, :final height) => Size(width, height),
      null => null,
    },
  );

  /// Creates a copy of this fake device in landscape mode.
  FakeDevice landscape() => copyWith(
    resolution: switch (resolution) {
      // Flip width and height if aspect ratio is smaller than 1
      Size(:final width, :final height, aspectRatio: <= 1) => Size(
        height,
        width,
      ),
      Size(:final width, :final height) => Size(width, height),
      null => null,
    },
  );
}

/// Enables rendering fonts and images correctly for this test.
///
/// Make sure to call `.pump()` after calling this function to ensure that it
/// takes effect.
///
/// {@template snap.fake_device.renderingUndoDisclaimer}
/// **Beware:** Once this has been called in a widget test, it can't be undone
/// for this test and will influence all subsequent rendering, including golden
/// tests.
/// {@endtemplate}
Future<void> enableRealRenderingForTest() async {
  await loadAppFonts();
  await precacheImages();
}

/// Loads all fonts that the app uses so that they will be rendered correctly
/// when taking screenshots.
///
/// {@macro snap.fake_device.renderingUndoDisclaimer}
Future<void> loadAppFonts() async {
  await spot.loadAppFonts();
}

/// Pre-caches all images so that they will be rendered correctly when taking
/// screenshots.
///
/// An optional [Finder] can be provided to limit the scope of the precaching to
/// matching descendants of that [Finder].
///
/// {@macro snap.fake_device.renderingUndoDisclaimer}
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
