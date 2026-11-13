import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

import '../util.dart';

const _spring = CupertinoMotion.smooth();
const _exit = CupertinoMotion.snappy(duration: Duration(milliseconds: 300));

/// A child that counts how often its state is created.
class _Child extends StatefulWidget {
  const _Child(this.label, {super.key});

  final String label;

  static final created = <String, int>{};

  @override
  State<_Child> createState() => _ChildState();
}

class _ChildState extends State<_Child> {
  @override
  void initState() {
    super.initState();
    _Child.created.update(widget.label, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20);
}

Widget _child(String label) => _Child(label, key: ValueKey(label));

Widget _switcher(
  Widget? child, {
  Motion motion = _spring,
  Motion? exitMotion = _exit,
  AnimatedSwitcherLayoutBuilder layoutBuilder =
      AnimatedSwitcher.defaultLayoutBuilder,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MotionSwitcher(
    motion: motion,
    exitMotion: exitMotion,
    layoutBuilder: layoutBuilder,
    child: child,
  ),
);

/// The presence animation of the child labeled [label], read from the
/// default fade transition, or null when the child is gone.
Animation<double>? _animation(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.byKey(ValueKey(label)),
    matching: find.byType(FadeTransition),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<FadeTransition>(finder.first).opacity;
}

/// The raw presence of the child labeled [label], or null when it is gone.
double? _presence(WidgetTester tester, String label) =>
    _animation(tester, label)?.value;

void main() {
  setUp(_Child.created.clear);

  testWidgets('shows the first child without a transition', (tester) async {
    await tester.pumpWidget(_switcher(_child('a')));
    expect(_presence(tester, 'a'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('springs the new child in and the old one out', (tester) async {
    await tester.pumpWidget(_switcher(_child('a')));
    await tester.pumpWidget(_switcher(_child('b')));
    await tester.pump(frame);
    await tester.pump(frame * 4);
    expect(_presence(tester, 'a'), inExclusiveRange(0, 1));
    expect(_presence(tester, 'b'), inExclusiveRange(0, 1));

    await tester.pumpAndSettle(frame);
    expect(_presence(tester, 'a'), isNull);
    expect(_presence(tester, 'b'), 1);
  });

  testWidgets('leaving children follow exitMotion', (tester) async {
    await tester.pumpWidget(
      _switcher(_child('a'), exitMotion: const Motion.instant()),
    );
    await tester.pumpWidget(
      _switcher(_child('b'), exitMotion: const Motion.instant()),
    );
    await tester.pump();
    await tester.pump(frame);
    expect(_presence(tester, 'a'), isNull);
    expect(_presence(tester, 'b'), inExclusiveRange(0, 1));
  });

  testWidgets('exitMotion defaults to motion', (tester) async {
    await tester.pumpWidget(_switcher(_child('a'), exitMotion: null));
    await tester.pumpWidget(_switcher(_child('b'), exitMotion: null));
    for (var i = 0; i < 10; i++) {
      await tester.pump(frame);
      expect(
        _presence(tester, 'a')! + _presence(tester, 'b')!,
        closeTo(1, 1e-9),
      );
    }
  });

  testWidgets('a returning child reverses without a jump and keeps its state', (
    tester,
  ) async {
    await tester.pumpWidget(_switcher(_child('a')));
    await tester.pumpWidget(_switcher(_child('b')));
    final samples = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(fineFrame);
      samples.add(_presence(tester, 'a')!);
    }
    expect(samples.last, inExclusiveRange(0, 1));

    // 'a' comes back while it is still leaving.
    await tester.pumpWidget(_switcher(_child('a')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(fineFrame);
      samples.add(_presence(tester, 'a')!);
    }
    expectContinuousVelocity(samples, retargetAt: 8);

    await tester.pumpAndSettle(frame);
    expect(_presence(tester, 'a'), 1);
    expect(_presence(tester, 'b'), isNull);
    expect(_Child.created, {'a': 1, 'b': 1});
  });

  testWidgets('updates the current child in place when it can', (tester) async {
    await tester.pumpWidget(_switcher(const _Child('a', key: ValueKey(1))));
    await tester.pumpWidget(_switcher(const _Child('b', key: ValueKey(1))));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_Child.created, {'a': 1});
  });

  testWidgets('a null child leaves and shows nothing', (tester) async {
    await tester.pumpWidget(_switcher(_child('a')));
    await tester.pumpWidget(_switcher(null));
    await tester.pump(frame);
    expect(_presence(tester, 'a'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle(frame);
    expect(find.byType(_Child), findsNothing);
  });

  testWidgets('Motion.instant() switches at once', (tester) async {
    await tester.pumpWidget(
      _switcher(
        _child('a'),
        motion: const Motion.instant(),
        exitMotion: const Motion.instant(),
      ),
    );
    await tester.pumpWidget(
      _switcher(
        _child('b'),
        motion: const Motion.instant(),
        exitMotion: const Motion.instant(),
      ),
    );
    await tester.pump();
    await tester.pump(frame);
    expect(_presence(tester, 'a'), isNull);
    expect(_presence(tester, 'b'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('passes the children to layoutBuilder, oldest first', (
    tester,
  ) async {
    final calls = <(Key?, List<Key?>)>[];
    Key? keyOf(Widget child) => find
        .descendant(of: find.byWidget(child), matching: find.byType(_Child))
        .evaluate()
        .map((element) => element.widget.key)
        .firstOrNull;
    Widget layout(Widget? current, List<Widget> previous) {
      calls.add((
        current?.key,
        [for (final child in previous) child.key],
      ));
      return AnimatedSwitcher.defaultLayoutBuilder(current, previous);
    }

    await tester.pumpWidget(_switcher(_child('a'), layoutBuilder: layout));
    await tester.pumpWidget(_switcher(_child('b'), layoutBuilder: layout));
    await tester.pumpWidget(_switcher(_child('c'), layoutBuilder: layout));

    // Each child is wrapped in its own keyed subtree; resolve those keys to
    // the labels of the children inside.
    final labels = <Key?, Key?>{};
    for (final element in find.byType(KeyedSubtree).evaluate()) {
      labels[element.widget.key] = keyOf(element.widget);
    }
    final named = [
      for (final (current, previous) in calls)
        [labels[current], for (final key in previous) labels[key]],
    ];
    expect(named, [
      [const ValueKey('a')],
      [const ValueKey('b'), const ValueKey('a')],
      [const ValueKey('c'), const ValueKey('a'), const ValueKey('b')],
    ]);
  });

  testWidgets('a leaving child is removed even if exitMotion changes while '
      'it leaves', (tester) async {
    await tester.pumpWidget(_switcher(_child('a')));
    await tester.pumpWidget(_switcher(_child('b')));
    await tester.pump(frame * 2);
    await tester.pumpWidget(
      _switcher(_child('b'), exitMotion: const CupertinoMotion.smooth()),
    );
    await tester.pumpAndSettle(frame);

    expect(find.byKey(const ValueKey('a')), findsNothing);
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
  });

  testWidgets('a bouncy exit removes the child only once it has settled', (
    tester,
  ) async {
    const bouncy = Motion.bouncySpring(extraBounce: 0.2);
    await tester.pumpWidget(_switcher(_child('a'), exitMotion: bouncy));
    await tester.pumpWidget(_switcher(_child('b'), exitMotion: bouncy));
    var lowest = 1.0;
    for (
      var presence = _presence(tester, 'a');
      presence != null;
      presence = _presence(tester, 'a')
    ) {
      lowest = presence < lowest ? presence : lowest;
      await tester.pump(frame);
    }

    expect(lowest, lessThan(0), reason: 'it passed through 0 on the way');
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'hands transitionBuilder a real Animation with forward and reverse '
    'status',
    (tester) async {
      await tester.pumpWidget(_switcher(_child('a')));
      await tester.pumpWidget(_switcher(_child('b')));
      await tester.pump(frame);
      expect(_animation(tester, 'a')!.status, AnimationStatus.reverse);
      expect(_animation(tester, 'b')!.status, AnimationStatus.forward);
      await tester.pumpAndSettle(frame);
      expect(_animation(tester, 'b')!.status, AnimationStatus.completed);
    },
  );

  testWidgets('works with Flutter transitions such as ScaleTransition', (
    tester,
  ) async {
    Widget build(String label) => Directionality(
      textDirection: TextDirection.ltr,
      child: MotionSwitcher(
        motion: _spring,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: _child(label),
      ),
    );
    double scale(String label) => tester
        .widget<ScaleTransition>(
          find.ancestor(
            of: find.byKey(ValueKey(label)),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    await tester.pumpWidget(build('a'));
    await tester.pumpWidget(build('b'));
    await tester.pump(frame * 5);
    expect(scale('b'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle(frame);
    expect(scale('b'), 1);
  });

  testWidgets('presence overshoots with a bouncy spring, and the default fade '
      'handles it', (tester) async {
    const bouncy = Motion.bouncySpring(extraBounce: 0.2);
    await tester.pumpWidget(_switcher(_child('a'), motion: bouncy));
    await tester.pumpWidget(_switcher(_child('b'), motion: bouncy));
    var highest = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(frame);
      highest = [highest, _presence(tester, 'b')!].reduce(
        (a, b) => a > b ? a : b,
      );
    }
    expect(highest, greaterThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(frame);
    expect(_presence(tester, 'b'), 1);
  });

  testWidgets('unmounting mid-switch leaves no ticker running', (
    tester,
  ) async {
    await tester.pumpWidget(_switcher(_child('a')));
    await tester.pumpWidget(_switcher(_child('b')));
    await tester.pump(frame);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('MotionSizeSwitcher', () {
    Widget sizeSwitcher(Widget? child, {bool immediateResize = false}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: MotionSizeSwitcher(
              motion: _spring,
              immediateResize: immediateResize,
              child: child,
            ),
          ),
        );

    for (final immediateResize in [false, true]) {
      testWidgets('springs its size to the new child '
          '(immediateResize: $immediateResize)', (tester) async {
        await tester.pumpWidget(
          sizeSwitcher(
            const SizedBox(key: ValueKey(1), width: 100, height: 20),
            immediateResize: immediateResize,
          ),
        );
        expect(
          tester.getSize(find.byType(MotionSizeSwitcher)),
          const Size(100, 20),
        );
        await tester.pumpWidget(
          sizeSwitcher(
            const SizedBox(key: ValueKey(2), width: 200, height: 40),
            immediateResize: immediateResize,
          ),
        );
        await tester.pump(frame * 5);
        final size = tester.getSize(find.byType(MotionSizeSwitcher));
        expect(size.width, inExclusiveRange(100, 200));
        await tester.pumpAndSettle(frame);
        expect(
          tester.getSize(find.byType(MotionSizeSwitcher)),
          const Size(200, 40),
        );
      });
    }

    testWidgets('keeps the space of a leaving child until it is gone '
        '(immediateResize: false)', (tester) async {
      await tester.pumpWidget(
        sizeSwitcher(const SizedBox(key: ValueKey(1), width: 200, height: 40)),
      );
      await tester.pumpWidget(
        sizeSwitcher(const SizedBox(key: ValueKey(2), width: 100, height: 20)),
      );
      while (find.byKey(const ValueKey(1)).evaluate().isNotEmpty) {
        expect(
          tester.getSize(find.byType(MotionSizeSwitcher)),
          const Size(200, 40),
        );
        await tester.pump(frame);
      }
      await tester.pumpAndSettle(frame);
      expect(
        tester.getSize(find.byType(MotionSizeSwitcher)),
        const Size(100, 20),
      );
    });

    testWidgets('follows the new child at once (immediateResize: true)', (
      tester,
    ) async {
      await tester.pumpWidget(
        sizeSwitcher(
          const SizedBox(key: ValueKey(1), width: 200, height: 40),
          immediateResize: true,
        ),
      );
      await tester.pumpWidget(
        sizeSwitcher(
          const SizedBox(key: ValueKey(2), width: 100, height: 20),
          immediateResize: true,
        ),
      );
      await tester.pump(frame * 5);
      expect(find.byKey(const ValueKey(1)), findsOneWidget);
      expect(
        tester.getSize(find.byType(MotionSizeSwitcher)).width,
        inExclusiveRange(100, 200),
      );
    });

    testWidgets('unmounting mid-resize leaves no ticker running', (
      tester,
    ) async {
      await tester.pumpWidget(
        sizeSwitcher(const SizedBox(key: ValueKey(1), width: 100, height: 20)),
      );
      await tester.pumpWidget(
        sizeSwitcher(const SizedBox(key: ValueKey(2), width: 200, height: 40)),
      );
      await tester.pump(frame);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('shrinks to nothing for a null child', (tester) async {
      await tester.pumpWidget(
        sizeSwitcher(const SizedBox(width: 100, height: 20)),
      );
      await tester.pumpWidget(sizeSwitcher(null));
      await tester.pumpAndSettle(frame);
      expect(tester.getSize(find.byType(MotionSizeSwitcher)), Size.zero);
    });
  });
}
