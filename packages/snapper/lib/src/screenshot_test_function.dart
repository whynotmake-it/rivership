import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:snapper/snapper.dart';

/// A helper test function meant to be used for taking real screenshots using
/// the [snap] function and the [WidgetTester].
///
/// As opposed to [testWidgets], it includes the `screenshot` tag in the test to
/// allow for easy filtering.
@isTest
void screenshotTest(
  String description,
  WidgetTesterCallback callback, {
  SnapperSettings? settings,
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
      final previousSettings = SnapperSettings.global;

      SnapperSettings.global = settings ?? previousSettings;

      await callback(tester);

      SnapperSettings.global = previousSettings;
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: ['screenshot', ...?tags],
    retry: retry,
  );
}
