import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:snaptest/snaptest.dart';

/// A helper test function meant to be used for taking real screenshots using
/// the [snap] function and the [WidgetTester].
///
/// As opposed to [testWidgets], it includes the `screenshot` tag in the test to
/// allow for easy filtering.
@isTest
void snapTest(
  String description,
  WidgetTesterCallback callback, {
  SnaptestSettings? settings,
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
      final previousSettings = SnaptestSettings.global;

      SnaptestSettings.global = settings ?? previousSettings;

      await callback(tester);

      SnaptestSettings.global = previousSettings;
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: ['screenshot', ...?tags],
    retry: retry,
  );
}
