import 'package:device_frame/device_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapper/snapper.dart';
import 'package:spot/spot.dart' as spot;

/// A device that represents the widget tester, will get special treatment in
/// [setTestViewToFakeDevice] and [snap].
///
/// Don't access its properties.
class WidgetTesterDevice implements DeviceInfo {
  /// Creates a new [WidgetTesterDevice].
  const WidgetTesterDevice();

  @override
  DeviceIdentifier get identifier => DeviceIdentifier(
    defaultTargetPlatform,
    DeviceType.unknown,
    'WidgetTester',
  );

  @override
  String get name => 'WidgetTester';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

/// Enables rendering fonts and images correctly for this test.
///
/// Make sure to call `.pump()` after calling this function to ensure that it
/// takes effect.
///
/// {@template snapper.fake_device.renderingUndoDisclaimer}
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
/// {@macro snapper.fake_device.renderingUndoDisclaimer}
Future<void> loadAppFonts() async {
  await spot.loadAppFonts();
}

/// Pre-caches all images so that they will be rendered correctly when taking
/// screenshots.
///
/// An optional [Finder] can be provided to limit the scope of the precaching to
/// matching descendants of that [Finder].
///
/// {@macro snapper.fake_device.renderingUndoDisclaimer}
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
