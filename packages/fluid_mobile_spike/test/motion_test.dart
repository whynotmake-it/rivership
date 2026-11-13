import 'dart:math' as math;

import 'package:fluid_mobile_spike/fluid_mobile_spike.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'harness.dart';

final _select = find.byKey(const ValueKey('select'));

/// The popover's outermost opacity: the phase builder's.
double _popoverOpacity(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.ancestor(
        of: find.byType(FluidOptionList<String>),
        matching: find.byType(Opacity),
      ),
    )
    .last
    .opacity;

/// Opens the popover with a mouse click; the mouse stays connected.
Future<TestGesture> _openPopover(
  WidgetTester tester, {
  FluidMotionThemeData motion = FluidMotionThemeData.standard,
}) async {
  useScreen(tester, TestScreen.desktop);
  await tester.pumpWidget(
    testApp(
      home: const SelectDemo(),
      motion: motion,
      inputMode: FluidInputMode.pointer,
    ),
  );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(_select));
  await mouse.down(tester.getCenter(_select));
  await mouse.up();
  await tester.pump(); // route pushed, popover mounted closed
  await tester.pump(); // phase flips to open
  return mouse;
}

void main() {
  group('motion tokens', () {
    // motion.dev's findSpring: the undamped frequency at which the envelope
    // has decayed to 0.001 after `duration`.
    double webOmega(double duration, double bounce) {
      final zeta = 1 - bounce;
      double envelope(double w) => zeta < 1
          ? 0.001 -
                (w * zeta / (w * math.sqrt(1 - zeta * zeta))) *
                    math.exp(-w * zeta * duration)
          : -0.001 + math.exp(-w * duration) * (w * duration + 1);
      var (lo, hi) = (1.0, 5000.0);
      final sign = envelope(lo) > 0;
      for (var i = 0; i < 200; i++) {
        final mid = (lo + hi) / 2;
        (envelope(mid) > 0) == sign ? lo = mid : hi = mid;
      }
      return (lo + hi) / 2;
    }

    for (final (name, motion, duration, bounce) in [
      ('fast', FluidMotionThemeData.standard.fast, 0.08, 0.0),
      ('moderate', FluidMotionThemeData.standard.moderate, 0.16, 0.0),
      ('slow', FluidMotionThemeData.standard.slow, 0.24, 0.12),
    ]) {
      test('$name is the same spring as the web token', () {
        final spring = (motion as CupertinoMotion).description;
        final omega = webOmega(duration, bounce);
        // Within 1%: Flutter reads the duration in whole milliseconds.
        expect(math.sqrt(spring.stiffness), closeTo(omega, omega * 0.01));
        final ratio = spring.damping / (2 * math.sqrt(spring.stiffness));
        expect(ratio, closeTo(1 - bounce, 0.001));
      });
    }

    test('reduced swaps every motion for instant', () {
      final reduced = FluidMotionThemeData.standard.reduced;
      expect(reduced.fast, const Motion.instant());
      expect(reduced.popoverExit, const Motion.instant());
      expect(reduced.selectionAck, FluidMotionThemeData.standard.selectionAck);
    });
  });

  group('popover open and close', () {
    testWidgets('springs in from the closed phase', (tester) async {
      await _openPopover(tester);
      await tester.pump(const Duration(milliseconds: 16));
      final early = _popoverOpacity(tester);
      expect(early, greaterThan(0));
      expect(early, lessThan(1));
      await tester.pumpAndSettle();
      expect(_popoverOpacity(tester), 1);
    });

    testWidgets('tweens out, then the route goes', (tester) async {
      await _openPopover(tester);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final mid = _popoverOpacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byType(FluidOptionList<String>), findsNothing);
    });

    testWidgets('motion tokens are theme data, retunable at runtime', (
      tester,
    ) async {
      await _openPopover(
        tester,
        motion: FluidMotionThemeData.standard.copyWith(
          fast: const Motion.instant(),
        ),
      );
      // The popover rides `fast`: instant means fully open on the first frame.
      await tester.pump(const Duration(milliseconds: 1));
      expect(_popoverOpacity(tester), 1);
    });

    testWidgets('reduced motion opens instantly', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openPopover(tester);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_popoverOpacity(tester), 1);
    });
  });

  testWidgets('the hover fill retargets mid-flight without jumping', (
    tester,
  ) async {
    final mouse = await _openPopover(tester);
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.text('Apple')));
    await tester.pumpAndSettle();
    double top() => tester
        .widget<Positioned>(
          find
              .ancestor(
                of: find.byWidgetPredicate(
                  (w) =>
                      w is DecoratedBox &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).color ==
                          FluidColors.light.hover,
                ),
                matching: find.byType(Positioned),
              )
              .first,
        )
        .top!;
    final start = top();
    await mouse.moveTo(tester.getCenter(find.text('Orange')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final midway = top();
    expect(midway, greaterThan(start));
    // Retarget back up while it's still moving down: the next frame starts
    // from where it is (no jump), and it carries on downward a little
    // before turning: the spring keeps its velocity.
    await mouse.moveTo(tester.getCenter(find.text('Blueberry')));
    await tester.pump(const Duration(milliseconds: 4));
    expect(top(), greaterThanOrEqualTo(midway));
    await tester.pumpAndSettle();
    expect(top(), lessThan(midway));
    await mouse.removePointer();
  });
}
