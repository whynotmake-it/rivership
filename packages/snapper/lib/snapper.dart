/// Snap photos in your widget tests.
library;

export 'package:device_frame/device_frame.dart' show DeviceInfo, Devices;

export 'src/fake_device.dart'
    show
        WidgetTesterDevice,
        enableRealRenderingForTest,
        loadAppFonts,
        precacheImages;
export 'src/screenshot_test_function.dart' show screenshotTest;
export 'src/snap.dart' show setTestViewToFakeDevice, snap;
export 'src/snap_settings.dart' show SnapSettings;
