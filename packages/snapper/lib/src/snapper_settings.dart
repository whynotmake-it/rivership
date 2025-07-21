import 'package:device_frame/device_frame.dart';
import 'package:equatable/equatable.dart';
import 'package:snapper/src/fake_device.dart';

/// Global defaults for the snapper package.
///
/// You can set them anywhere in your tests. Beware of side effects 🤷
class SnapperSettings with EquatableMixin {
  /// Creates a new [SnapperSettings] instance.
  const SnapperSettings({
    this.blockText = true,
    this.renderShadows = false,
    this.renderImages = false,
    this.devices = const [
      WidgetTesterDevice(),
    ],
  });

  /// Creates a new [SnapperSettings] instance with full rendering.
  const SnapperSettings.full(
    this.devices,
  ) : blockText = false,
      renderImages = true,
      renderShadows = true;

  /// The global settings for the snapper package.
  static SnapperSettings global = const SnapperSettings();

  /// Resets the global settings to their default values.
  static void resetGlobal() {
    global = const SnapperSettings();
  }

  /// Whether to block text in the screenshot.
  final bool blockText;

  /// Whether to images should be precached before taking the screenshot.
  final bool renderImages;

  /// Whether to render shadows.
  final bool renderShadows;

  /// The devices to use for the screenshot.
  final List<DeviceInfo> devices;

  @override
  List<Object?> get props => [
    blockText,
    renderImages,
    renderShadows,
    devices,
  ];
}
