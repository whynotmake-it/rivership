import 'package:flutter/src/painting/edge_insets.dart';
import 'package:snaptest/snaptest.dart';

/// Represents the default Flutter test environment (no specific device).
///
/// Use this when you want screenshots in the standard widget test environment
/// without any device-specific sizing or styling.
///
/// Example:
/// ```dart
/// await snap(
///   settings: SnaptestSettings(
///     devices: [
///       const WidgetTesterDevice(), // Default test environment
///       Devices.ios.iPhone16Pro,    // Plus iPhone 16 Pro
///     ],
///   ),
/// );
/// ```
///
/// Note: Don't access properties on this device - it's a placeholder that gets
/// special handling internally.
final class WidgetTesterDevice implements DeviceInfo {
  /// Creates a new [WidgetTesterDevice].
  const WidgetTesterDevice();

  @override
  String get name => 'WidgetTester';

  @override
  EdgeInsets? get rotatedSafeAreas => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      "WidgetTesterDevice is not a real device, don't access its properties.",
    );
  }
}
