import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_sheet.dart';

class _Host extends StatefulWidget {
  const _Host({
    this.divisions,
    this.variant = CoilSliderVariant.scrubber,
    this.size,
    this.tier = CoilTier.pointer,
    this.textDirection = TextDirection.ltr,
    this.disabled = false,
    this.states,
    this.motion,
    this.reduceMotion = false,
    this.onStart,
    this.onEnd,
  });

  final int? divisions;
  final CoilSliderVariant variant;
  final CoilSize? size;
  final CoilTier tier;
  final TextDirection textDirection;
  final bool disabled;
  final WidgetStatesController? states;
  final CoilMotion? motion;
  final bool reduceMotion;
  final ValueChanged<double>? onStart;
  final ValueChanged<double>? onEnd;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double value = 0.5;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: widget.reduceMotion),
      child: Directionality(
        textDirection: widget.textDirection,
        child: CoilTheme(
          data: CoilThemeData.light.copyWith(
            tier: widget.tier,
            motion: widget.motion,
          ),
          child: FocusScope(
            autofocus: true,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: SizedBox(
                  width: 300,
                  child: CoilSlider(
                    key: const ValueKey('slider'),
                    value: value,
                    divisions: widget.divisions,
                    variant: widget.variant,
                    size: widget.size,
                    label: const Text('Volume'),
                    statesController: widget.states,
                    semanticLabel: 'Volume',
                    onChangeStart: widget.onStart,
                    onChangeEnd: widget.onEnd,
                    onChanged: widget.disabled
                        ? null
                        : (v) => setState(() => value = v),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _valueOf(WidgetTester tester) =>
    (tester.state(find.byType(_Host)) as _HostState).value;

final _slider = find.byKey(const ValueKey('slider'));

void main() {
  testWidgets('a tap jumps to the position', (tester) async {
    await tester.pumpWidget(const _Host());
    final rect = tester.getRect(_slider);
    await tester.tapAt(Offset(rect.left + rect.width * .8, rect.center.dy));
    await tester.pump();
    expect(_valueOf(tester), closeTo(.8, 0.01));
  });

  testWidgets('dragging sets the value 1:1 and reports start and end', (
    tester,
  ) async {
    double? started;
    double? ended;
    await tester.pumpWidget(
      _Host(onStart: (v) => started = v, onEnd: (v) => ended = v),
    );
    final rect = tester.getRect(_slider);
    final g = await tester.startGesture(
      Offset(rect.left + rect.width * .5, rect.center.dy),
    );
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(Offset(rect.width * .25, 0));
    await tester.pump();
    expect(_valueOf(tester), closeTo(.5 + (40 + 75) / 300, .05));
    await g.up();
    await tester.pump();
    expect(started, isNotNull);
    expect(ended, closeTo(_valueOf(tester), 1e-9));
  });

  testWidgets('a drag past the end clamps; no coasting after release', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final rect = tester.getRect(_slider);
    final g = await tester.startGesture(rect.center);
    await g.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(_valueOf(tester), 1);
    await g.up();
    await settle(tester);
    expect(_valueOf(tester), 1);
  });

  testWidgets('steps snap the reported value', (tester) async {
    await tester.pumpWidget(const _Host(divisions: 4));
    final rect = tester.getRect(_slider);
    await tester.tapAt(Offset(rect.left + rect.width * .6, rect.center.dy));
    await tester.pump();
    expect(_valueOf(tester), .5);
    await tester.tapAt(Offset(rect.left + rect.width * .7, rect.center.dy));
    await tester.pump();
    expect(_valueOf(tester), .75);
  });

  testWidgets('keyboard: arrows, page, home and end', (tester) async {
    await tester.pumpWidget(const _Host(divisions: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.6, 1e-9));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(_valueOf(tester), closeTo(.5, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.4, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.5, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.3, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_valueOf(tester), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_valueOf(tester), 0);
  });

  testWidgets('keyboard: left and right follow the reading direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(divisions: 10, textDirection: TextDirection.rtl),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.6, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.5, 1e-9));
  });

  testWidgets('RTL: the min end is at the right', (tester) async {
    await tester.pumpWidget(const _Host(textDirection: TextDirection.rtl));
    final rect = tester.getRect(_slider);
    await tester.tapAt(Offset(rect.left + rect.width * .8, rect.center.dy));
    await tester.pump();
    expect(_valueOf(tester), closeTo(.2, 0.01));
  });

  testWidgets('semantics: slider value, increase and decrease', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(divisions: 10));
    final node = tester.getSemantics(_slider);
    final data = node.getSemanticsData();
    expect(data.value, '0.5');
    expect(data.increasedValue, '0.6');
    expect(data.decreasedValue, '0.4');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    tester.semantics.performAction(
      find.semantics.byAction(SemanticsAction.increase),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(_valueOf(tester), closeTo(.6, 1e-9));
    handle.dispose();
  });

  testWidgets('disabled: ignores input and has no actions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(disabled: true));
    final rect = tester.getRect(_slider);
    await tester.tapAt(Offset(rect.left + rect.width * .9, rect.center.dy));
    await tester.pump();
    expect(_valueOf(tester), .5);
    expect(
      tester
          .getSemantics(_slider)
          .getSemanticsData()
          .hasAction(
            SemanticsAction.increase,
          ),
      isFalse,
    );
    handle.dispose();
  });

  Finder bubbleText() => find.descendant(
    of: _slider,
    matching: find.byWidgetPredicate(
      (w) => w is Opacity && w.child is CustomSingleChildLayout,
    ),
  );

  testWidgets('touch: the bubble shows while pressed and leaves no hover', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(_Host(states: states, tier: CoilTier.touch));
    expect(bubbleText(), findsNothing);
    final rect = tester.getRect(_slider);
    final g = await tester.startGesture(
      Offset(rect.left + rect.width * .5, rect.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(states.value, contains(WidgetState.pressed));
    expect(bubbleText(), findsOneWidget);
    await g.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await settle(tester);
    expect(states.value, isNot(contains(WidgetState.hovered)));
    expect(states.value, isNot(contains(WidgetState.pressed)));
    expect(states.value, isNot(contains(WidgetState.focused)));
    expect(bubbleText(), findsNothing, reason: 'the bubble fades out');
  });

  testWidgets('mouse: hover shows the preview and bubble; leaving hides', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(_Host(states: states));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final rect = tester.getRect(_slider);
    await mouse.moveTo(Offset(rect.left + rect.width * .75, rect.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(states.value, contains(WidgetState.hovered));
    expect(bubbleText(), findsOneWidget);
    expect(find.text('0.75'), findsOneWidget);
    await mouse.moveTo(const Offset(5, 5));
    await settle(tester);
    expect(states.value, isNot(contains(WidgetState.hovered)));
    expect(bubbleText(), findsNothing);
  });

  testWidgets('a click shows no focus ring; the keyboard does', (tester) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(_Host(states: states));
    final rect = tester.getRect(_slider);
    await tester.tapAt(
      rect.center,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(states.value, isNot(contains(WidgetState.focused)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(states.value, contains(WidgetState.focused));
  });

  testWidgets('a vertical scroll over the slider does not move it', (
    tester,
  ) async {
    var value = .5;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => CoilTheme(
          data: CoilThemeData.light.copyWith(tier: CoilTier.touch),
          child: StatefulBuilder(
            builder: (context, setState) => ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 100),
                CoilSlider(
                  key: const ValueKey('slider'),
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    final g = await tester.startGesture(tester.getCenter(_slider));
    await g.moveBy(const Offset(0, -40));
    await tester.pump();
    await g.moveBy(const Offset(0, -40));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(value, .5);
    expect(scroll.offset, greaterThan(0));
  });

  group('motion', () {
    double knobX(WidgetTester tester) => tester
        .getRect(
          find.descendant(
            of: _slider,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is ShapeDecoration &&
                  (w.decoration as ShapeDecoration).color ==
                      const Color(0xFFFFFFFF),
            ),
          ),
        )
        .center
        .dx;

    // Progress of the knob from its rest (value .5) toward the end.
    late double rest;
    late double end;
    Future<void> measure(WidgetTester tester) async {
      rest = knobX(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
    }

    double progress(WidgetTester tester) =>
        (knobX(tester) - rest) / (end - rest);

    Widget host({CoilMotion? motion, bool reduce = false}) => _Host(
      size: CoilSize.compact,
      divisions: 10,
      motion: motion,
      reduceMotion: reduce,
    );

    testWidgets('a key step springs onto the value', (tester) async {
      await tester.pumpWidget(host());
      await measure(tester);
      await tester.pump(const Duration(milliseconds: 40));
      final mid = knobX(tester);
      await settle(tester);
      end = knobX(tester);
      expect(mid, inExclusiveRange(rest, end));
    });

    testWidgets('reduced motion makes travel instant', (tester) async {
      await tester.pumpWidget(host(reduce: true));
      await measure(tester);
      await tester.pump(const Duration(milliseconds: 20));
      final soon = knobX(tester);
      await settle(tester);
      end = knobX(tester);
      expect(soon, closeTo(end, .5));
    });

    testWidgets('a runtime theme motion change applies to the next step', (
      tester,
    ) async {
      final slow = const CoilMotion().copyWith(
        standard: const Motion.linear(Duration(seconds: 2)),
      );
      await tester.pumpWidget(host());
      await tester.pumpWidget(host(motion: slow));
      await measure(tester);
      await tester.pump(const Duration(milliseconds: 1000));
      final half = knobX(tester);
      await tester.pump(const Duration(seconds: 3));
      end = knobX(tester);
      expect(progress(tester), closeTo(1, 1e-6));
      expect((half - rest) / (end - rest), closeTo(.5, .1));
    });
  });

  testWidgets('compact size and pips build and drag', (tester) async {
    await tester.pumpWidget(const _Host(size: CoilSize.compact, divisions: 4));
    final rect = tester.getRect(_slider);
    await tester.tapAt(Offset(rect.center.dx + 60, rect.center.dy));
    await tester.pump();
    expect(_valueOf(tester), greaterThan(.5));
    await tester.pumpWidget(
      const _Host(variant: CoilSliderVariant.pips, divisions: 4),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
