/// @docImport 'package:snaptest/src/snap.dart';
library;

import 'package:device_frame/device_frame.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:snaptest/src/fake_device.dart';

/// Controls how screenshots are rendered and which devices to test on.
///
/// Use this to customize screenshot behavior - from simple debugging
/// screenshots to beautiful device-framed images for documentation.
///
/// ## Quick Start
///
/// ```dart
/// // Default: Simple screenshots for debugging
/// await snap(); // Uses SnaptestSettings()
///
/// // Beautiful screenshots with device frames
/// await snap(settings: SnaptestSettings.full([Devices.ios.iPhone16Pro]));
/// ```
///
/// ## Global Settings
///
/// Set defaults for all tests in your project:
/// ```dart
/// void main() {
///   setUpAll(() {
///     SnaptestSettings.global = SnaptestSettings.full([
///       Devices.ios.iPhone16Pro,
///       Devices.android.samsungGalaxyS20,
///     ]);
///   });
///
///   tearDownAll(() {
///     SnaptestSettings.resetGlobal();
///   });
/// }
/// ```
class SnaptestSettings with EquatableMixin {
  /// Creates screenshot settings for debugging and testing.
  ///
  /// Default settings create simple, consistent screenshots:
  /// - Text is blocked (shows gray rectangles instead of actual text)
  /// - No images, shadows, or device frames
  /// - Uses default test environment sizing
  ///
  /// Perfect for debugging and basic visual testing where you want consistency
  /// over visual fidelity.
  const SnaptestSettings({
    this.blockText = true,
    this.renderShadows = false,
    this.renderImages = false,
    this.includeDeviceFrame = false,
    this.devices = const [
      WidgetTesterDevice(),
    ],
    this.orientations = const {
      Orientation.portrait,
    },
  });

  /// Creates settings for beautiful, realistic screenshots.
  ///
  /// Full rendering includes:
  /// - Real text (no blocking)
  /// - Actual images and icons
  /// - Shadows and visual effects
  /// - Device frames around the content
  /// - Multiple orientations (if specified)
  ///
  /// Perfect for documentation, design reviews, and showing stakeholders
  /// what the app actually looks like:
  /// ```dart
  /// await snap(
  ///   settings: SnaptestSettings.full(
  ///     devices: [
  ///       Devices.ios.iPhone16Pro,
  ///       Devices.android.samsungGalaxyS20,
  ///     ],
  ///     orientations: {
  ///       Orientation.portrait,
  ///       Orientation.landscape,
  ///     },
  ///   ),
  /// );
  /// ```
  const SnaptestSettings.full({
    required this.devices,
    this.orientations = const {
      Orientation.portrait,
    },
  }) : blockText = false,
       renderImages = true,
       renderShadows = true,
       includeDeviceFrame = true;

  /// Global default settings used by all [snap] calls.
  ///
  /// Change this to set defaults for your entire test suite:
  /// ```dart
  /// SnaptestSettings.global = SnaptestSettings.full(
  ///   devices: [Devices.ios.iPhone16Pro],
  /// );
  /// ```
  static SnaptestSettings global = const SnaptestSettings();

  /// Resets global settings back to defaults.
  ///
  /// Useful in test teardown to avoid side effects:
  /// ```dart
  /// tearDownAll(() {
  ///   SnaptestSettings.resetGlobal();
  /// });
  /// ```
  static void resetGlobal() {
    global = const SnaptestSettings();
  }

  /// Whether to replace text with gray rectangles for consistency.
  ///
  /// - `true` (default): Shows golden-friendly blocks instead of actual text
  /// - `false`: Shows real text as it appears in your app
  final bool blockText;

  /// Whether to render actual images in screenshots.
  ///
  /// - `false` (default): Images appear as placeholders
  /// - `true`: Shows real images (slower but more realistic)
  final bool renderImages;

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
  final bool includeDeviceFrame;

  /// List of devices to generate screenshots for.
  ///
  /// Each device creates a separate screenshot file. Use multiple devices
  /// to test responsive design:
  /// ```dart
  /// devices: [
  ///   const WidgetTesterDevice(),     // Default test size
  ///   Devices.ios.iPhone16Pro,       // iPhone
  ///   Devices.android.samsungGalaxyS20, // Android
  /// ]
  /// ```
  final List<DeviceInfo> devices;

  /// Set of orientations to generate screenshots for.
  ///
  /// Each orientation creates a separate screenshot file with an orientation
  /// suffix (e.g., `_portrait`, `_landscape`). Use multiple orientations to
  /// test responsive design:
  /// ```dart
  /// orientations: {
  ///   Orientation.portrait,
  ///   Orientation.landscape,
  /// }
  /// ```
  ///
  /// Note: Landscape orientation is automatically skipped for devices that
  /// don't support rotation (like [WidgetTesterDevice]).
  final Set<Orientation> orientations;

  @override
  List<Object?> get props => [
    blockText,
    renderImages,
    renderShadows,
    includeDeviceFrame,
    devices,
    orientations,
  ];
}
