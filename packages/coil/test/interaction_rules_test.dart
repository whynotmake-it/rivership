import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/paint_probe.dart';

const _ring = Color(0xFF0000FF);

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) => CoilTheme(
    data: CoilThemeData.light.copyWith(
      tier: CoilTier.pointer,
      colors: CoilColors.light.copyWith(brand: _ring),
    ),
    child: navigator!,
  ),
  onGenerateRoute: (_) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => RepaintBoundary(
      key: const ValueKey('boundary'),
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: Center(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('a quick tap still shows the press for the minimum time', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      _app(
        CoilInteraction(
          onPressed: () {},
          statesController: states,
          builder: (context, _, _) => const SizedBox(width: 80, height: 40),
        ),
      ),
    );
    await tester.tap(find.byType(CoilInteraction));
    await tester.pump(const Duration(milliseconds: 40));
    expect(states.value, contains(WidgetState.pressed));
    await tester.pump(const Duration(milliseconds: 100));
    expect(states.value, isNot(contains(WidgetState.pressed)));
  });

  testWidgets('the focus ring fades in', (tester) async {
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: visible,
          builder: (context, visible, _) => CoilFocusRing(
            visible: visible,
            borderRadius: BorderRadius.zero,
            offset: 4,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(SizedBox).last);
    // The 1 px ring sits 4 px outside the box.
    final onRing = Offset(box.center.dx, box.top - 4.5);
    Future<Color> ring() =>
        colorAt(tester, find.byKey(const ValueKey('boundary')), onRing);
    expect(isNear(await ring(), const Color(0xFFFFFFFF)), isTrue);

    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final midway = await ring();
    expect(isNear(midway, const Color(0xFFFFFFFF)), isFalse);
    expect(isNear(midway, _ring, tolerance: 30), isFalse, reason: 'fading');
    await tester.pumpAndSettle();
    expect(isNear(await ring(), _ring, tolerance: 30), isTrue);
  });
}
