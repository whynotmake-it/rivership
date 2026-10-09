/// Snap photos in your widget tests.
library;

export 'package:device_frame/device_frame.dart' show DeviceInfo, Devices;

export 'src/clean.dart' show cleanSnaps;
export 'src/font_loading.dart' show CupertinoFontConfig, loadFonts;
export 'src/screenshot_test_function.dart' show snapTest;
export 'src/snap.dart' show Snap, setTestViewForDevice, snap;
export 'src/snaptest_settings.dart' show SnaptestSettings;
export 'src/test_devices_variant.dart' show TestDevicesVariant;
export 'src/video/ffmpeg_encoder.dart' show SnapVideoException;
export 'src/video/snap_recording.dart' show SnapRecording;
export 'src/video/snaptest_binding.dart' show SnaptestWidgetsFlutterBinding;
export 'src/video/video_settings.dart'
    show
        SnapVideoSettings,
        VideoEncoding,
        VideoFailurePolicy,
        VideoTiming;
