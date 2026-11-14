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
      _app(CoilReveal(preset: CoilRevealPreset.subtle, children: _blocks(2))),
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
      _app(CoilReveal(preset: CoilRevealPreset.subtle, children: _blocks(3))),
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
            CoilRevealTrack.presence: const CupertinoMotion(
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

  testWidgets('landing rises into place, a longer step apart', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(CoilReveal(preset: CoilRevealPreset.landing, children: _blocks(2))),
    );
    await tester.pumpAndSettle();
    final rest = tester.getRect(find.text('0')).top;
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(
      _app(CoilReveal(preset: CoilRevealPreset.landing, children: _blocks(2))),
    );
    final at = await _arrivals(tester, 2);
    expect((at[1] - at[0]).inMilliseconds, closeTo(100, 8));
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(
      _app(CoilReveal(preset: CoilRevealPreset.landing, children: _blocks(2))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(find.text('0')).top, greaterThan(rest));
  });

  group('visible', () {
    Widget reveal({required bool visible, bool reducedMotion = false}) => _app(
      CoilReveal(visible: visible, children: _blocks(3)),
      reducedMotion: reducedMotion,
    );

    testWidgets('hides in the same order, then shows again', (tester) async {
      await tester.pumpWidget(reveal(visible: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(reveal(visible: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _opacity(tester, 0),
        lessThan(1),
        reason: 'the first leaves first',
      );
      expect(_opacity(tester, 2), 1, reason: 'the last waits its turn');
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(_opacity(tester, i), 0);
        expect(find.text('$i'), findsOneWidget, reason: 'still mounted');
      }

      await tester.pumpWidget(reveal(visible: true));
      final at = await _arrivals(tester, 3);
      expect(at[1], greaterThan(at[0]));
      await tester.pumpAndSettle();
      expect(_opacity(tester, 2), 1);
    });

    testWidgets('a flip halfway turns around from where it is', (
      tester,
    ) async {
      await tester.pumpWidget(reveal(visible: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _opacity(tester, 0);
      expect(mid, inExclusiveRange(0, 1));

      await tester.pumpWidget(reveal(visible: false));
      await tester.pump();
      final turned = _opacity(tester, 0);
      expect(turned, closeTo(mid, 0.25), reason: 'no jump, no restart');
      await tester.pumpAndSettle();
      expect(_opacity(tester, 0), 0);
    });

    testWidgets('hidden children keep their state and take no taps', (
      tester,
    ) async {
      final taps = <int>[];
      Widget host({required bool visible}) => _app(
        CoilReveal(
          visible: visible,
          children: [
            GestureDetector(
              onTap: () => taps.add(1),
              child: const SizedBox(height: 40, child: _Counter()),
            ),
          ],
        ),
      );
      await tester.pumpWidget(host(visible: true));
      await tester.pumpAndSettle();
      tester.state<_CounterState>(find.byType(_Counter)).count = 5;

      await tester.pumpWidget(host(visible: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(_Counter), warnIfMissed: false);
      expect(taps, isEmpty);

      await tester.pumpWidget(host(visible: true));
      await tester.pumpAndSettle();
      expect(tester.state<_CounterState>(find.byType(_Counter)).count, 5);
    });

    testWidgets('reduced motion: hides and shows all at once, fading', (
      tester,
    ) async {
      await tester.pumpWidget(reveal(visible: true, reducedMotion: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(reveal(visible: false, reducedMotion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final first = _opacity(tester, 0);
      expect(first, inExclusiveRange(0, 1));
      expect(_opacity(tester, 2), first);
    });
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

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Text('count $count');
}
