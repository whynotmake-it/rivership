import 'package:device_frame/device_frame.dart';
import 'package:snapper/src/fake_device.dart';

/// Global defaults for the snapper package.
///
/// You can set them anywhere in your tests. Beware of side effects 🤷
abstract class SnapSettings {
  const SnapSettings._();

  /// Whether to render shadows.
  static bool renderShadows = true;

  /// The devices to use for the screenshot.
  static List<DeviceInfo> devices = [
    const WidgetTesterDevice(),
  ];

  /// Resets the global settings to their default values.
  static void reset() {
    renderShadows = true;
    devices = [
      const WidgetTesterDevice(),
    ];
  }
}
