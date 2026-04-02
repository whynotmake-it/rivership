/// @docImport 'package:snaptest/snaptest.dart';
/// @docImport 'package:snaptest/src/snap.dart';
/// @docImport 'package:snaptest/src/test_devices_variant.dart';
library;

import 'package:equatable/equatable.dart';
import 'package:snaptest/src/constants.dart';

/// Controls how screenshots are rendered.
///
/// Use this to customize screenshot behavior - from simple debugging
/// screenshots to beautiful device-framed images for documentation.
///
/// ## Quick Start
///
/// ```dart
/// // Screenshots use SnaptestSettings.rendered() by default
/// await snap();
///
/// // Golden comparison uses SnaptestSettings.golden by default
/// await snap.golden();
///
/// // Both visual debugging + golden comparison
/// await snap.andGolden();
/// ```
///
/// ## Global Settings
///
/// Set defaults for all tests in your project:
/// ```dart
/// void main() {
///   setUpAll(() {
///     SnaptestSettings.global = SnaptestSettings.rendered();
///   });
///
///   tearDownAll(() {
///     SnaptestSettings.resetGlobal();
///   });
/// }
/// ```
///
/// ## Multi-Device Testing
///
/// Use [TestDevicesVariant] to test on multiple devices:
/// ```dart
/// testWidgets(
///   'my test',
///   variant: TestDevicesVariant({
///     Devices.ios.iPhone16Pro,
///     Devices.android.samsungGalaxyS20,
///   }),
///   (tester) async {
///     await tester.pumpWidget(MyApp());
///     await snap(settings: SnaptestSettings.rendered());
///   },
/// );
/// ```
class SnaptestSettings with EquatableMixin {
  /// Creates screenshot settings for debugging and testing.
  ///
  /// Default settings create simple, consistent screenshots:
  /// - Text is blocked (shows gray rectangles instead of actual text)
  /// - No images, shadows, or device frames
  /// - Uses default test environment sizing
  /// - Screenshots saved to `.snaptest/` directory
  ///
  /// Perfect for debugging and basic visual testing where you want consistency
  /// over visual fidelity.
  const SnaptestSettings({
    this.blockText = true,
    this.renderShadows = false,
    this.includeDeviceFrame = false,
    this.pathPrefix = kDefaultPathPrefix,
  });

  /// Creates settings for beautiful, realistic screenshots with full rendering.
  ///
  /// Rendered screenshots include:
  /// - Real text (no blocking)
  /// - Actual images and icons
  /// - Shadows and visual effects
  /// - Device frames around the content
  /// - Screenshots saved to `.snaptest/` directory (or custom [pathPrefix])
  ///
  /// Perfect for documentation, design reviews, and showing stakeholders
  /// what the app actually looks like:
  /// ```dart
  /// await snap(
  ///   device: Devices.ios.iPhone16Pro,
  ///   settings: SnaptestSettings.rendered(),
  /// );
  /// ```
  const SnaptestSettings.rendered({
    this.pathPrefix = kDefaultPathPrefix,
  }) : blockText = false,
       renderShadows = true,
       includeDeviceFrame = true;

  /// Global default settings used by all [snap] calls.
  ///
  /// Change this to set defaults for your entire test suite:
  /// ```dart
  /// SnaptestSettings.global = SnaptestSettings(
  ///   blockText: true,
  /// );
  /// ```
  static SnaptestSettings global = const SnaptestSettings.rendered();

  /// Default settings used by [Snap.golden] and [Snap.andGolden].
  ///
  /// Defaults to blocking text, no images, no shadows, no device frame.
  static SnaptestSettings goldens = const SnaptestSettings();

  /// Resets global settings back to defaults.
  ///
  /// Useful in test teardown to avoid side effects:
  /// ```dart
  /// tearDownAll(() {
  ///   SnaptestSettings.resetGlobal();
  /// });
  /// ```
  static void resetGlobal() {
    global = const SnaptestSettings.rendered();
  }

  /// Whether to replace text with gray rectangles for consistency.
  ///
  /// - `true` (default): Shows golden-friendly blocks instead of actual text
  /// - `false`: Shows real text as it appears in your app
  final bool blockText;

  /// Whether to include shadows and elevation effects.
  ///
  /// - `false` (default): No shadows (faster, more consistent)
  /// - `true`: Shows shadows and Material elevation effects
  final bool renderShadows;

  /// Whether to wrap screenshots with device frames.
  ///
  /// - `false` (default): Just the app content
  /// - `true`: Includes device bezels, notches, and home indicators
  ///
  /// Device frames make screenshots look more realistic and are great for
  /// documentation or showing stakeholders.
  ///
  /// Requires a device to be specified via [snap]'s `device` parameter or
  /// via [TestDevicesVariant].
  final bool includeDeviceFrame;

  /// Directory path prefix where screenshots are saved.
  ///
  /// Defaults to `.snaptest/` but can be customized:
  /// ```dart
  /// SnaptestSettings(
  ///   pathPrefix: 'screenshots/',
  ///   // ... other settings
  /// )
  /// ```
  ///
  /// The path should end with a forward slash.
  final String pathPrefix;

  @override
  List<Object?> get props => [
    blockText,
    renderShadows,
    includeDeviceFrame,
    pathPrefix,
  ];
}
