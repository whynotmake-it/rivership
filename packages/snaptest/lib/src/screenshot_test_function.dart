import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:snaptest/snaptest.dart';

/// A test function specifically designed for taking snaptest screenshots.
///
/// Works exactly like [testWidgets], but automatically:
/// - Adds the `snaptest` tag for easy filtering
/// - Applies the provided [settings] for the duration of the test
///
/// Perfect for dedicated screenshot tests that you want to run separately:
///
/// ```dart
/// snapTest('Login screen looks correct', (tester) async {
///   await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
///   await snap();
/// });
/// ```
///
/// Filter snaptest tests when running:
/// ```sh
/// flutter test --tags snaptest
/// ```
///
/// Or exclude them:
/// ```sh
/// flutter test --exclude-tags snaptest
/// ```
///
/// You can also pass [devices] and [orientations] to test on multiple devices.
/// This internally creates a [TestDevicesVariant]:
/// ```dart
/// snapTest(
///   'Multi-device test',
///   devices: {Devices.ios.iPhone16Pro},
///   settings: SnaptestSettings.rendered(),
///   (tester) async {
///     await tester.pumpWidget(const MaterialApp(home: MyPage()));
///     await snap(); // Uses iPhone 16 Pro automatically
///   },
/// );
/// ```
@isTest
void snapTest(
  String description,
  WidgetTesterCallback callback, {
  SnaptestSettings? settings,
  Set<DeviceInfo>? devices,
  Set<Orientation>? orientations,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  List<String>? tags,
  int? retry,
}) {
  assert(
    devices == null || variant is DefaultTestVariant,
    'Cannot specify both devices and variant.',
  );

  final effectiveVariant = devices != null
      ? TestDevicesVariant(
          devices,
          orientations: orientations ?? const {Orientation.portrait},
        )
      : variant;

  testWidgets(
    description,
    (tester) async {
      final previousSettings = SnaptestSettings.global;

      SnaptestSettings.global = settings ?? previousSettings;

      try {
        await callback(tester);
      } finally {
        SnaptestSettings.global = previousSettings;
      }
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: effectiveVariant,
    tags: ['snaptest', ...?tags],
    retry: retry,
  );
}
