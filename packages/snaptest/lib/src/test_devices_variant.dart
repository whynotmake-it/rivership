import 'package:device_frame/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

/// Package-internal: the currently active device/orientation from a
/// [TestDevicesVariant], or `null` when no variant is running.
///
/// Used by [snap] to resolve the device without requiring explicit parameters.
(DeviceInfo, Orientation)? activeDeviceVariant;

/// A [TestVariant] that will use [setTestViewForDevice] to set the test view
/// to each of the given [DeviceInfo] values.
///
/// Landscape orientation is automatically skipped for devices that don't
/// support rotation.
class TestDevicesVariant extends ValueVariant<(DeviceInfo, Orientation)> {
  /// Creates a new [TestDevicesVariant] variant.
  TestDevicesVariant(
    this.devices, {
    this.orientations = const {Orientation.portrait},
  }) : super({
         for (final device in devices)
           for (final orientation in orientations)
             if (orientation != Orientation.landscape || device.canRotate)
               (device, orientation),
       });

  /// The list of devices to test on.
  final Set<DeviceInfo> devices;

  /// The orientations to test each device with.
  ///
  /// By default, only [Orientation.portrait] is used.
  ///
  /// Landscape orientation is automatically skipped for devices that don't
  /// support rotation.
  final Set<Orientation> orientations;

  VoidCallback? _restore;

  @override
  Future<(DeviceInfo, Orientation)> setUp(
    (DeviceInfo, Orientation) value,
  ) async {
    activeDeviceVariant = value;
    _restore = setTestViewForDevice(value.$1, value.$2);
    return super.setUp(value);
  }

  @override
  String describeValue((DeviceInfo, Orientation) value) {
    final (device, orientation) = value;
    return '${device.name} - ${orientation.name}';
  }

  @override
  Future<void> tearDown(
    (DeviceInfo, Orientation) value,
    (DeviceInfo, Orientation) memento,
  ) async {
    _restore?.call();
    activeDeviceVariant = null;
  }
}
