import 'package:coil/coil.dart';
import 'package:coil/src/components/slider/slider_visuals.dart'
    show sliderBubbleKey, sliderKnobKey;
import 'package:coil/src/primitives/motion_layer.dart' show CoilPainterLayer;
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_sheet.dart';

/// Hosts one slider whose parent applies (or refuses) every change and logs
/// the callbacks.
class _Host extends StatefulWidget {
  const _Host({
    this.divisions,
    this.variant = CoilSliderVariant.scrubber,
    this.tier = CoilTier.pointer,
    this.textDirection = TextDirection.ltr,
    this.disabled = false,
    this.rejects = false,
    this.states,
    this.motion,
    this.motions,
    this.trackMotions = const {},
    this.reduceMotion = false,
    this.label = const Text('Volume'),
  });

  final int? divisions;
  final CoilSliderVariant variant;
  final CoilTier tier;
  final TextDirection textDirection;
  final bool disabled;
  final bool rejects;
  final WidgetStatesController? states;
  final CoilMotion? motion;
  final Map<CoilSliderTrack<Object>, Motion>? motions;
  final Map<Track<Object>, Motion> trackMotions;
  final bool reduceMotion;
  final Widget? label;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double value = 0.5;
  final log = <String>[];

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
            trackMotions: widget.trackMotions,
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
                    label: widget.label,
                    statesController: widget.states,
                    motions: widget.motions,
                    onChangeStart: (v) => log.add('start ${_fmt(v)}'),
                    onChangeEnd: (v) => log.add('end ${_fmt(v)}'),
                    onChanged: widget.disabled
                        ? null
                        : (v) {
                            log.add('changed ${_fmt(v)}');
                            if (!widget.rejects) setState(() => value = v);
                          },
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

String _fmt(double v) => v.toStringAsFixed(2);

_HostState _host(WidgetTester tester) =>
    tester.state(find.byType(_Host)) as _HostState;

double _valueOf(WidgetTester tester) => _host(tester).value;

final _slider = find.byKey(const ValueKey('slider'));

Offset _at(WidgetTester tester, double fraction) {
  final rect = tester.getRect(_slider);
  return Offset(rect.left + rect.width * fraction, rect.center.dy);
}

void main() {
  testWidgets('a tap jumps to the position', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.tapAt(_at(tester, .8));
    await tester.pump();
    expect(_valueOf(tester), closeTo(.8, 0.01));
  });

  testWidgets('dragging follows the pointer, with a mouse too', (tester) async {
    await tester.pumpWidget(const _Host());
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      final g = await tester.startGesture(_at(tester, .5), kind: kind);
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(45, 0));
      await tester.pump();
      expect(_valueOf(tester), closeTo(.75, .05));
      await g.up();
      await tester.pump();
      await tester.tapAt(_at(tester, .5));
      await tester.pump();
    }
  });

  testWidgets('a released drag keeps its value: no coasting', (tester) async {
    await tester.pumpWidget(const _Host());
    final g = await tester.startGesture(_at(tester, .3));
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(25, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await g.up();
    await tester.pump();
    final released = _valueOf(tester);
    await settle(tester);
    expect(_valueOf(tester), released);
    expect(released, lessThan(.9));
  });

  testWidgets('steps snap the reported value', (tester) async {
    await tester.pumpWidget(const _Host(divisions: 4));
    await tester.tapAt(_at(tester, .6));
    await tester.pump();
    expect(_valueOf(tester), .5);
    await tester.tapAt(_at(tester, .7));
    await tester.pump();
    expect(_valueOf(tester), .75);
  });

  testWidgets('keys: arrows, Shift, page, Home and End', (tester) async {
    await tester.pumpWidget(const _Host(divisions: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    Future<void> press(LogicalKeyboardKey key, double expected) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(_valueOf(tester), closeTo(expected, 1e-9));
    }

    await press(LogicalKeyboardKey.arrowRight, .6);
    await press(LogicalKeyboardKey.arrowDown, .5);
    await press(LogicalKeyboardKey.arrowLeft, .4);
    await press(LogicalKeyboardKey.pageUp, .5);
    await press(LogicalKeyboardKey.pageDown, .4);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await press(LogicalKeyboardKey.arrowRight, .5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await press(LogicalKeyboardKey.end, 1);
    await press(LogicalKeyboardKey.home, 0);
  });

  testWidgets('RTL: min is at the right and arrows follow reading order', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(divisions: 10, textDirection: TextDirection.rtl),
    );
    await tester.tapAt(_at(tester, .8));
    await tester.pump();
    expect(_valueOf(tester), closeTo(.2, .01));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_valueOf(tester), closeTo(.3, 1e-9));
  });

  testWidgets('every kind of change reports a start and an end', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(divisions: 10));
    final semantics = tester.ensureSemantics();
    await tester.tapAt(_at(tester, .8));
    await tester.pump();
    expect(_host(tester).log, ['start 0.50', 'changed 0.80', 'end 0.80']);

    _host(tester).log.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_host(tester).log, ['start 0.80', 'changed 0.70', 'end 0.70']);

    _host(tester).log.clear();
    tester.semantics.performAction(
      find.semantics.byAction(SemanticsAction.increase),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(_host(tester).log, ['start 0.70', 'changed 0.80', 'end 0.80']);

    _host(tester).log.clear();
    final g = await tester.startGesture(_at(tester, .2));
    await g.moveBy(const Offset(60, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(_host(tester).log.first, 'start 0.80');
    expect(_host(tester).log.last, startsWith('end '));
    semantics.dispose();
  });

  testWidgets('the slider is controlled: a refused change moves nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(rejects: true, variant: CoilSliderVariant.pill),
    );
    double knobX() => tester.getCenter(find.byKey(sliderKnobKey)).dx;
    final before = knobX();
    final g = await tester.startGesture(_at(tester, .5));
    await g.moveBy(const Offset(90, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(knobX(), closeTo(before, 1));
    await g.up();
    await settle(tester);
    expect(knobX(), closeTo(before, 1));
    expect(_host(tester).log.last, 'end 0.50');
  });

  testWidgets('semantics: one slider node that reads its value once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(divisions: 10));
    final data = tester.getSemantics(_slider).getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.value, '0.5');
    expect(data.increasedValue, '0.6');
    expect(data.decreasedValue, '0.4');
    expect(data.label, 'Volume');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    handle.dispose();
  });

  testWidgets('the label is built once', (tester) async {
    await tester.pumpWidget(_Host(label: Text('Volume', key: GlobalKey())));
    expect(tester.takeException(), isNull);
    expect(find.text('Volume'), findsOneWidget);
  });

  testWidgets('disabled: ignores input and offers no actions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(disabled: true));
    await tester.tapAt(_at(tester, .9));
    await tester.pump();
    expect(_valueOf(tester), .5);
    final data = tester.getSemantics(_slider).getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    handle.dispose();
  });

  group('touch and mouse', () {
    testWidgets('touch: the value bubble shows while pressed, nothing sticks', (
      tester,
    ) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(_Host(states: states, tier: CoilTier.touch));
      expect(find.byKey(sliderBubbleKey), findsNothing);
      final g = await tester.startGesture(_at(tester, .5));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(states.value, contains(WidgetState.pressed));
      expect(find.byKey(sliderBubbleKey), findsOneWidget);
      await g.up();
      await settle(tester);
      expect(states.value, isEmpty);
      expect(find.byKey(sliderBubbleKey), findsNothing);
    });

    testWidgets('mouse: hover previews the value under the pointer', (
      tester,
    ) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(_Host(states: states));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_at(tester, .75));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(states.value, contains(WidgetState.hovered));
      expect(
        find.descendant(
          of: find.byKey(sliderBubbleKey),
          matching: find.text('0.75'),
        ),
        findsOneWidget,
      );
      await mouse.moveTo(const Offset(5, 5));
      await settle(tester);
      expect(states.value, isNot(contains(WidgetState.hovered)));
      expect(find.byKey(sliderBubbleKey), findsNothing);
    });

    testWidgets('a click shows no focus ring; the keyboard does', (
      tester,
    ) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(_Host(states: states));
      await tester.tapAt(_at(tester, .5), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(states.value, isNot(contains(WidgetState.focused)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(states.value, contains(WidgetState.focused));
    });

    testWidgets('a vertical swipe that starts on a slider only scrolls', (
      tester,
    ) async {
      var value = .5;
      final states = WidgetStatesController();
      final scroll = ScrollController();
      addTearDown(() {
        states.dispose();
        scroll.dispose();
      });
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
                    statesController: states,
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
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        states.value,
        isNot(contains(WidgetState.pressed)),
        reason: 'inside a scrollable the press waits for kPressTimeout',
      );
      expect(find.byKey(sliderBubbleKey), findsNothing);
      await g.moveBy(const Offset(0, -40));
      await tester.pump();
      await g.moveBy(const Offset(0, -40));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(value, .5);
      expect(scroll.offset, greaterThan(0));
    });
  });

  group('pointer and geometry', () {
    Finder bubbleBox() => find.descendant(
      of: find.byKey(sliderBubbleKey),
      matching: find.byType(DecoratedBox),
    );

    testWidgets('the hover follows the pointer through a mouse drag', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: _at(tester, .2));
      await mouse.moveTo(_at(tester, .2));
      await tester.pump();
      await mouse.down(_at(tester, .2));
      for (final f in [.4, .6, .8]) {
        await mouse.moveTo(_at(tester, f));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
      await settle(tester);
      expect(_valueOf(tester), closeTo(.8, .01));
      expect(
        find.descendant(
          of: find.byKey(sliderBubbleKey),
          matching: find.text('0.8'),
        ),
        findsOneWidget,
        reason: 'the hover is where the pointer let go, not where it began',
      );
      expect(tester.getCenter(bubbleBox()).dx, closeTo(_at(tester, .8).dx, 1));
    });

    testWidgets('a stepped drag springs to each step and lands on it', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(variant: CoilSliderVariant.pill, divisions: 4),
      );
      final knob = find.byKey(sliderKnobKey);
      final start = tester.getCenter(knob);
      final g = await tester.startGesture(start);
      await g.moveBy(const Offset(4, 0));
      await g.moveBy(const Offset(4, 0));
      await tester.pump();
      await g.moveTo(Offset(tester.getRect(_slider).right, start.dy));
      await tester.pump();
      expect(_valueOf(tester), 1);
      await tester.pump(const Duration(milliseconds: 16));
      final mid = tester.getCenter(knob).dx;
      await g.up();
      await settle(tester);
      final end = tester.getCenter(knob).dx;
      expect(mid, greaterThan(start.dx));
      expect(mid, lessThan(end), reason: 'springs, does not jump');
      expect(_valueOf(tester), 1);
    });

    testWidgets(
      'pips: the fill spans the whole row, end pips sit at the ends',
      (tester) async {
        await tester.pumpWidget(
          const _Host(
            variant: CoilSliderVariant.pips,
            divisions: 4,
            label: null,
          ),
        );
        final width = tester.getSize(_slider).width;
        final layer = find.descendant(
          of: _slider,
          matching: find.byType(CoilPainterLayer),
        );
        // Paint calls in order: pips, fill, handle line.
        Future<({List<Rect> rects, List<Rect> marks})> painted() async {
          await settle(tester);
          final rects = <Rect>[];
          final marks = <Rect>[];
          expect(
            tester.renderObject(layer),
            paints..everything((method, args) {
              if (method == #drawRect) rects.add(args.first as Rect);
              if (method == #drawRSuperellipse) {
                marks.add((args.first as RSuperellipse).outerRect);
              }
              return true;
            }),
          );
          return (rects: rects, marks: marks);
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        final atMax = await painted();
        expect(atMax.rects.first.left, 0);
        expect(atMax.rects.first.right, closeTo(width, .01));

        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        final atMin = await painted();
        expect(atMin.rects.first.width, 0);
        final firstPip = atMin.marks.first.center.dx;
        final handle = atMin.marks.last.center.dx;
        expect(firstPip, handle, reason: 'the min pip sits under the handle');
        expect(firstPip, lessThan(width / 4 / 2), reason: 'at the row start');
      },
    );

    for (final (name, key) in [
      ('min', LogicalKeyboardKey.home),
      ('max', LogicalKeyboardKey.end),
    ]) {
      testWidgets('pill: at $name the bubble sits over the knob', (
        tester,
      ) async {
        await tester.pumpWidget(
          const _Host(variant: CoilSliderVariant.pill, tier: CoilTier.touch),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(key);
        await settle(tester);
        final knob = tester.getCenter(find.byKey(sliderKnobKey));
        final g = await tester.startGesture(knob);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getCenter(bubbleBox()).dx, closeTo(knob.dx, .5));
        await g.up();
        await settle(tester);
      });
    }
  });

  group('motion', () {
    // The pill's knob moves with the thumb.
    double knobX(WidgetTester tester) =>
        tester.getCenter(find.byKey(sliderKnobKey)).dx;

    Widget host({
      CoilMotion? motion,
      Map<CoilSliderTrack<Object>, Motion>? motions,
      Map<Track<Object>, Motion> trackMotions = const {},
      bool reduce = false,
    }) => _Host(
      variant: CoilSliderVariant.pill,
      divisions: 10,
      motion: motion,
      motions: motions,
      trackMotions: trackMotions,
      reduceMotion: reduce,
    );

    /// How far (0..1) the knob has travelled toward End after [ms].
    Future<double> travelled(
      WidgetTester tester,
      Widget slider, {
      int ms = 60,
    }) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(slider);
      final rest = knobX(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
      final soon = knobX(tester);
      await settle(tester);
      return (soon - rest) / (knobX(tester) - rest);
    }

    testWidgets('a key step springs the thumb onto the value', (tester) async {
      final p = await travelled(tester, host());
      expect(p, inExclusiveRange(0, 1));
    });

    testWidgets('reduced motion makes the thumb travel instant', (
      tester,
    ) async {
      expect(await travelled(tester, host(reduce: true)), closeTo(1, .01));
    });

    testWidgets('a per-instance motion changes the thumb', (tester) async {
      final fast = await travelled(
        tester,
        host(
          motions: {
            CoilSliderTrack.thumb: const Motion.linear(
              Duration(milliseconds: 10),
            ),
          },
        ),
      );
      expect(fast, closeTo(1, .01));
    });

    testWidgets('a theme track motion reaches the thumb', (tester) async {
      final slow = await travelled(
        tester,
        host(
          trackMotions: {
            CoilSliderTrack.thumb: const Motion.linear(Duration(seconds: 2)),
          },
        ),
        ms: 1000,
      );
      expect(slow, closeTo(.5, .1));
    });

    testWidgets('a runtime theme motion change applies to the next step', (
      tester,
    ) async {
      final slow = const CoilMotion().copyWith(
        standard: const Motion.linear(Duration(seconds: 2)),
      );
      final p = await travelled(tester, host(motion: slow), ms: 1000);
      expect(p, closeTo(.5, .1));
    });
  });
}
