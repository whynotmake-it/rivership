import 'package:snapper/snapper.dart';

/// A device that represents the widget tester, will get special treatment in
/// [setTestViewToFakeDevice] and [snap].
///
/// Don't access its properties, as it represents the defaults for widget tests.
final class WidgetTesterDevice implements DeviceInfo {
  /// Creates a new [WidgetTesterDevice].
  const WidgetTesterDevice();

  @override
  String get name => 'WidgetTester';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      "WidgetTesterDevice is not a real device, don't access its properties.",
    );
  }
}
