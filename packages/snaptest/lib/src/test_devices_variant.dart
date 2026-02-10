import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

/// A [TestVariant] that will use [setTestViewToFakeDevice] to set the test view
/// to each of the given [DeviceInfo] values.
class TestDevicesVariant extends ValueVariant<(DeviceInfo, Orientation)> {
  /// Creates a new [TestDevicesVariant] variant.
  TestDevicesVariant(
    this.devices, {
    this.orientations = const {Orientation.portrait},
  }) : super({
         for (final device in devices)
           for (final orientation in orientations) (device, orientation),
       });

  /// The list of devices to test on.
  final Set<DeviceInfo> devices;

  /// The orientations to test each device with.
  ///
  /// By default, only [Orientation.portrait] is used.
  final Set<Orientation> orientations;

  VoidCallback? _restore;

  @override
  Future<(DeviceInfo, Orientation)> setUp(
    (DeviceInfo, Orientation) value,
  ) async {
    _restore = setTestViewToFakeDevice(value.$1, value.$2);
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
  }
}
