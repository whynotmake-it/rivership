import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

Widget _app(Widget child, {bool reducedMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CoilTheme(data: CoilThemeData.light, child: child),
  ),
);

List<Widget> _blocks(int count) => [
  for (var i = 0; i < count; i++) SizedBox(height: 20, child: Text('$i')),
];

/// What the user sees of a child: the product of the opacities above it.
double _opacity(WidgetTester tester, int index) {
  var opacity = 1.0;
  for (final o in tester.widgetList<Opacity>(
    find.ancestor(of: find.text('$index'), matching: find.byType(Opacity)),
  )) {
    opacity *= o.opacity;
  }
  return opacity;
}

/// Pumps frame by frame and records when each child first shows.
Future<List<Duration>> _arrivals(WidgetTester tester, int count) async {
  final firstSeen = List<Duration?>.filled(count, null);
  var elapsed = Duration.zero;
  const frame = Duration(milliseconds: 4);
  while (firstSeen.contains(null) && elapsed < const Duration(seconds: 2)) {
    for (var i = 0; i < count; i++) {
      if (firstSeen[i] == null && _opacity(tester, i) > 0.05) {
        firstSeen[i] = elapsed;
      }
    }
    await tester.pump(frame);
    elapsed += frame;
  }
  return [for (final t in firstSeen) t!];
}

void main() {
  testWidgets('each child starts after the one before it', (tester) async {
    await tester.pumpWidget(_app(CoilReveal(children: _blocks(3))));
    final at = await _arrivals(tester, 3);
    expect(at[1], greaterThan(at[0]));
    expect(at[2], greaterThan(at[1]));
    // One `stagger` (60 ms) apart, within a frame.
    expect(
      (at[2] - at[1]).inMilliseconds,
      closeTo(60, 8),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(_opacity(tester, i), 1);
    }
  });

  testWidgets('the subtle pace is quicker', (tester) async {
    await tester.pumpWidget(
      _app(CoilReveal(pace: CoilRevealPace.subtle, children: _blocks(2))),
    );
    final at = await _arrivals(tester, 2);
    expect((at[1] - at[0]).inMilliseconds, closeTo(40, 8));
  });

  testWidgets('blocks past the third arrive together', (tester) async {
    await tester.pumpWidget(_app(CoilReveal(children: _blocks(6))));
    final at = await _arrivals(tester, 6);
    expect(at[3], greaterThan(at[2]));
    expect(at[4], at[3]);
    expect(at[5], at[3]);
  });

  testWidgets('items stagger up to the eighth', (tester) async {
    await tester.pumpWidget(
      _app(CoilReveal(steps: CoilRevealSteps.items, children: _blocks(9))),
    );
    final at = await _arrivals(tester, 9);
    for (var i = 1; i < 8; i++) {
      expect(at[i], greaterThan(at[i - 1]), reason: 'item $i');
    }
    expect(at[8], at[7]);
  });

  testWidgets('reduced motion shows everything at once, still fading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(CoilReveal(children: _blocks(5)), reducedMotion: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final first = _opacity(tester, 0);
    expect(first, inExclusiveRange(0, 1), reason: 'the fade stays');
    for (var i = 1; i < 5; i++) {
      expect(_opacity(tester, i), first);
    }
  });

  testWidgets('it plays once: a rebuild leaves the children shown', (
    tester,
  ) async {
    await tester.pumpWidget(_app(CoilReveal(children: _blocks(3))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(CoilReveal(pace: CoilRevealPace.subtle, children: _blocks(3))),
    );
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      expect(_opacity(tester, i), 1);
    }
  });

  testWidgets('the stagger token and track motions apply at runtime', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CoilReveal(
          motion: const CoilMotion(stagger: Duration(milliseconds: 200)),
          motions: {
            CoilRevealTrack.opacity: const CupertinoMotion(
              duration: Duration(milliseconds: 20),
            ),
          },
          children: _blocks(2),
        ),
      ),
    );
    final at = await _arrivals(tester, 2);
    expect((at[1] - at[0]).inMilliseconds, closeTo(200, 8));
  });

  testWidgets('a custom layout reveals its children', (tester) async {
    await tester.pumpWidget(
      _app(
        CoilReveal(
          builder: (context, children) => Row(children: children),
          children: _blocks(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('1')).dx,
      greaterThan(tester.getTopLeft(find.text('0')).dx),
    );
    expect(_opacity(tester, 1), 1);
  });
}
