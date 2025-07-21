import 'package:snapper/snapper.dart';

/// Global defaults for the snapper package.
///
/// You can set them anywhere in your tests. Beware of side effects 🤷
abstract class SnapSettings {
  const SnapSettings._();

  /// Whether to render shadows.
  static bool renderShadows = true;

  /// The devices to use for the screenshot.
  static List<FakeDevice> devices = [FakeDevice.none];

  /// Resets the global settings to their default values.
  static void reset() {
    renderShadows = true;
    devices = [FakeDevice.none];
  }
}
