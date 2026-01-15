import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

/// A [TestVariant] that will use [setTestViewToFakeDevice] to set the test view
/// to each of the given [DeviceInfo] values.
class TestOnDevices extends TestVariant<(DeviceInfo, Orientation)> {
  /// Creates a new [TestOnDevices] variant.
  TestOnDevices(
    this.devices, {
    this.orientations = const {Orientation.portrait},
  });

  /// The list of devices to test on.
  final List<DeviceInfo> devices;

  /// The orientations to test each device with.
  ///
  /// By default, only [Orientation.portrait] is used.
  final Set<Orientation> orientations;

  @override
  List<(DeviceInfo, Orientation)> get values => [
    for (final device in devices)
      for (final orientation in orientations) (device, orientation),
  ];

  @override
  Future<VoidCallback> setUp((DeviceInfo, Orientation) value) async {
    return setTestViewToFakeDevice(value.$1, value.$2);
  }

  @override
  String describeValue((DeviceInfo, Orientation) value) {
    final (device, orientation) = value;
    return '${device.name} - ${orientation.name}';
  }

  @override
  Future<void> tearDown(
    (DeviceInfo, Orientation) value,
    VoidCallback memento,
  ) async {
    memento.call();
  }
}
