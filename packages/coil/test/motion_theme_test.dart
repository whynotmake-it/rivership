import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// A linear motion makes "where is it halfway through" easy to assert.
CoilMotion _linear(int ms) => const CoilMotion().copyWith(
  standard: Motion.linear(Duration(milliseconds: ms)),
);

/// Hosts one switch whose value and theme motion the test changes.
class _Host extends StatelessWidget {
  const _Host({
    required this.value,
    required this.motion,
    this.instanceMotion,
    this.reduceMotion = false,
  });

  final bool value;
  final CoilMotion motion;
  final CoilMotion? instanceMotion;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
      ),
      child: CoilTheme(
        data: CoilThemeData.light.copyWith(
          tier: CoilTier.pointer,
          motion: motion,
        ),
        child: Center(
          child: CoilSwitch(
            value: value,
            onChanged: (_) {},
            motion: instanceMotion,
          ),
        ),
      ),
    ),
  );
}

/// The thumb's left edge relative to the track (2 off, 16 on at desktop
/// size).
double _thumbX(WidgetTester tester) {
  final track = tester.getRect(find.byType(CoilSwitch));
  final thumb = tester.getRect(
    find
        .descendant(
          of: find.byType(CoilSwitch),
          matching: find.byType(DecoratedBox),
        )
        .last,
  );
  return thumb.left - track.left;
}

void main() {
  testWidgets('swapping the theme motion at runtime applies to the next '
      'animation, on the same controller', (tester) async {
    await tester.pumpWidget(_Host(value: false, motion: _linear(1000)));
    final state = tester.state(find.byType(CoilSwitch));
    expect(_thumbX(tester), 2);

    // A 1 s linear thumb: halfway after 500 ms.
    await tester.pumpWidget(_Host(value: true, motion: _linear(1000)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_thumbX(tester), moreOrLessEquals(9, epsilon: 0.5));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_thumbX(tester), 16);

    // Swap the theme to a 100 ms linear thumb and toggle back.
    await tester.pumpWidget(_Host(value: false, motion: _linear(100)));
    expect(
      tester.state(find.byType(CoilSwitch)),
      same(state),
      reason: 'no controller or state was recreated',
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(_thumbX(tester), moreOrLessEquals(9, epsilon: 0.5));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_thumbX(tester), 2);
  });

  testWidgets('a per-instance motion overrides the theme', (tester) async {
    await tester.pumpWidget(
      _Host(value: false, motion: _linear(1000), instanceMotion: _linear(200)),
    );
    await tester.pumpWidget(
      _Host(value: true, motion: _linear(1000), instanceMotion: _linear(200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_thumbX(tester), moreOrLessEquals(9, epsilon: 0.5));
  });

  testWidgets('reduced motion makes travel instant on top of any theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(value: false, motion: _linear(1000), reduceMotion: true),
    );
    await tester.pumpWidget(
      _Host(value: true, motion: _linear(1000), reduceMotion: true),
    );
    await tester.pump();
    expect(_thumbX(tester), 16);
  });

  test('CoilMotion has value semantics, copyWith and lerp', () {
    const a = CoilMotion();
    final b = a.copyWith(quick: const Motion.instant());
    expect(a, const CoilMotion());
    expect(b, isNot(a));
    expect(b.standard, a.standard);
    expect(CoilMotion.lerp(a, b, 0.2), a);
    expect(CoilMotion.lerp(a, b, 0.8), b);
    expect(a.reduced().standard, const Motion.instant());
    expect(a.reduced().fade, a.fade, reason: 'fades survive reduced motion');
    expect(
      CoilThemeData.light.copyWith(motion: b),
      isNot(CoilThemeData.light),
    );
  });
}
