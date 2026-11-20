import 'package:coil/primitives.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('corner_radius_plugin');

Map<String, double> _all(double radius) => {
  'topLeft': radius,
  'topRight': radius,
  'bottomLeft': radius,
  'bottomRight': radius,
};

/// Answers the plugin's channel with [screenRadius] (or throws it, when it
/// is an exception) and no device info, and counts the queries.
List<String> _mock(WidgetTester tester, Object? Function() screenRadius) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    calls.add(call.method);
    if (call.method != 'getScreenRadius') return null;
    final answer = screenRadius();
    if (answer is Exception) throw answer;
    return answer;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
  return calls;
}

void main() {
  setUp(CoilScreenRadius.debugReset);
  tearDown(CoilScreenRadius.debugReset);

  testWidgets('a reported radius is used', (tester) async {
    _mock(tester, () => _all(28.5));
    expect(await CoilScreenRadius.resolve(), BorderRadius.circular(28.5));
    expect(CoilScreenRadius.value, BorderRadius.circular(28.5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android reporting no rounded corners is a square screen', (
    tester,
  ) async {
    _mock(tester, () => _all(0));
    expect(await CoilScreenRadius.resolve(), BorderRadius.zero);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets("the plugin's default answer (-1) is unknown, not square", (
    tester,
  ) async {
    // No answer at all: the plugin falls back to its default radius.
    _mock(tester, () => null);
    expect(await CoilScreenRadius.resolve(), isNull);
    expect(CoilScreenRadius.value, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an iPhone missing from the table is unknown', (tester) async {
    // iOS 26's query finds nothing and there is no device info.
    final calls = _mock(tester, () => _all(0));
    expect(await CoilScreenRadius.resolve(), isNull);
    expect(calls, containsAll(['getScreenRadius', 'getDeviceInfo']));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('implausible radii are unknown', (tester) async {
    // Android before 12 reports physical pixels: 72 for a 24 corner at 3x.
    var radius = 72.0;
    _mock(tester, () => _all(radius));
    expect(await CoilScreenRadius.resolve(), isNull);
    CoilScreenRadius.debugReset();
    // Below the cap but more than a quarter of a 200-wide screen.
    tester.view
      ..physicalSize = const Size(200, 400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    radius = 60;
    expect(await CoilScreenRadius.resolve(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a failed query asks once more, then stops', (tester) async {
    var fail = true;
    final calls = _mock(
      tester,
      () => fail ? PlatformException(code: 'no-activity') : _all(30),
    );
    expect(await CoilScreenRadius.resolve(), isNull);
    expect(calls, hasLength(1));
    fail = false;
    expect(await CoilScreenRadius.resolve(), BorderRadius.circular(30));
    expect(calls, hasLength(2));
    expect(await CoilScreenRadius.resolve(), BorderRadius.circular(30));
    expect(calls, hasLength(2), reason: 'answered: asked once');

    CoilScreenRadius.debugReset();
    calls.clear();
    fail = true;
    for (var i = 0; i < 4; i++) {
      await CoilScreenRadius.resolve();
    }
    expect(calls, hasLength(2), reason: 'one retry only');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('desktop is unknown', (
    tester,
  ) async {
    expect(await CoilScreenRadius.resolve(), isNull);
  }, variant: TargetPlatformVariant.desktop());
}
