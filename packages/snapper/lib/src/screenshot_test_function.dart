import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'package:snapper/snapper.dart';

/// A helper test function meant to be used for taking real screenshots using
/// the [snap] function and the [WidgetTester].
///
/// As opposed to [testWidgets], it automatically enables real rendering if
/// [withRealRendering] is set to true, and includes the `screenshot` tag in the
/// test to allow for easy filtering.
@isTest
void screenshotTest(
  String description,
  WidgetTesterCallback callback, {
  List<FakeDevice>? devices,
  bool withRealRendering = true,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  List<String>? tags,
  int? retry,
}) {
  testWidgets(
    description,
    (tester) async {
      final previousDevices = SnapSettings.devices;
      final previousShadows = SnapSettings.renderShadows;

      SnapSettings.devices = devices ?? previousDevices;
      SnapSettings.renderShadows = true;

      if (withRealRendering) {
        await enableRealRenderingForTest();
      }

      await callback(tester);

      SnapSettings.devices = previousDevices;
      SnapSettings.renderShadows = previousShadows;
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: ['screenshot', ...?tags],
    retry: retry,
  );
}
