import 'package:device_frame/device_frame.dart';
import 'package:equatable/equatable.dart';
import 'package:snaptest/src/fake_device.dart';

/// Global defaults for the snaptest package.
///
/// You can set them anywhere in your tests. Beware of side effects 🤷
class SnaptestSettings with EquatableMixin {
  /// Creates a new [SnaptestSettings] instance.
  const SnaptestSettings({
    this.blockText = true,
    this.renderShadows = false,
    this.renderImages = false,
    this.includeDeviceFrame = false,
    this.devices = const [
      WidgetTesterDevice(),
    ],
  });

  /// Creates a new [SnaptestSettings] instance with full rendering.
  const SnaptestSettings.full(
    this.devices,
  ) : blockText = false,
      renderImages = true,
      renderShadows = true,
      includeDeviceFrame = true;

  /// The global settings for the snaptest package.
  static SnaptestSettings global = const SnaptestSettings();

  /// Resets the global settings to their default values.
  static void resetGlobal() {
    global = const SnaptestSettings();
  }

  /// Whether to block text in the screenshot.
  final bool blockText;

  /// Whether to images should be precached before taking the screenshot.
  final bool renderImages;

  /// Whether to render shadows.
  final bool renderShadows;

  /// Whether to include the device frame in the screenshot.
  final bool includeDeviceFrame;

  /// The devices to use for the screenshot.
  final List<DeviceInfo> devices;

  @override
  List<Object?> get props => [
    blockText,
    renderImages,
    renderShadows,
    includeDeviceFrame,
    devices,
  ];
}
