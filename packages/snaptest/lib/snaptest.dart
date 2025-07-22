/// Snap photos in your widget tests.
library;

export 'package:device_frame/device_frame.dart' show DeviceInfo, Devices;

export 'src/fake_device.dart' show WidgetTesterDevice;
export 'src/screenshot_test_function.dart' show snapTest;
export 'src/snap.dart' show setTestViewToFakeDevice, snap;
export 'src/snapper_settings.dart' show SnapperSettings;
