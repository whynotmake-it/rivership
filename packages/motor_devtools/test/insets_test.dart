import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

final _launcher = find.byKey(const ValueKey('motor-devtools-launcher'));
final _panel = find.byKey(const ValueKey('motor-devtools-panel'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(
  WidgetTester tester, {
  FakeViewPadding padding = FakeViewPadding.zero,
  FakeViewPadding viewInsets = FakeViewPadding.zero,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding
    ..viewInsets = viewInsets;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MotorDevTools(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleMotionBuilder(
          debugLabel: 'Card',
          from: 0,
          value: 1,
          motion: const Motion.linear(Duration(seconds: 30)),
          builder: (context, value, child) => const SizedBox(),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Where the tools may draw: the window less its insets.
Rect _clear(Size size, EdgeInsets insets) => Rect.fromLTRB(
  insets.left,
  insets.top,
  size.width - insets.right,
  size.height - insets.bottom,
);

void _expectInside(Rect rect, Rect clear, String what) {
  expect(rect.left, greaterThanOrEqualTo(clear.left), reason: what);
  expect(rect.top, greaterThanOrEqualTo(clear.top), reason: what);
  expect(rect.right, lessThanOrEqualTo(clear.right), reason: what);
  expect(rect.bottom, lessThanOrEqualTo(clear.bottom), reason: what);
}

void main() {
  testWidgets('the bubble and the open panel stay clear of the safe area', (
    tester,
  ) async {
    for (final (size, padding) in [
      (const Size(390, 844), const EdgeInsets.only(top: 47, bottom: 34)),
      (
        const Size(844, 390),
        const EdgeInsets.only(left: 47, right: 47, bottom: 21),
      ),
    ]) {
      await _pump(
        tester,
        size: size,
        padding: FakeViewPadding(
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
      );
      final clear = _clear(size, padding);
      _expectInside(tester.getRect(_launcher), clear, 'bubble in $size');

      await tester.tap(_launcher);
      await _settle(tester);
      _expectInside(tester.getRect(_panel), clear, 'panel in $size');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the bubble and the open panel stay above the keyboard', (
    tester,
  ) async {
    // With the keyboard up, the view's bottom padding goes to the keyboard.
    const keyboard = FakeViewPadding(bottom: 336);
    await _pump(
      tester,
      padding: const FakeViewPadding(top: 47),
      viewInsets: keyboard,
    );
    final clear = _clear(
      const Size(390, 844),
      const EdgeInsets.only(top: 47, bottom: 336),
    );
    _expectInside(tester.getRect(_launcher), clear, 'bubble');

    await tester.tap(_launcher);
    await _settle(tester);
    _expectInside(tester.getRect(_panel), clear, 'panel');
    await tester.pumpWidget(const SizedBox());
  });

  test('the tools are on by default only in debug builds', () {
    const tools = MotorDevTools(child: SizedBox());
    expect(tools.enabled, kDebugMode);
    expect(tools.visible, isTrue);
  });
}
