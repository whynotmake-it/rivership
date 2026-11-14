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
    this.steps,
    this.valueDisplay = CoilSliderValueDisplay.text,
    this.initial = 0.5,
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
  final List<double>? steps;
  final CoilSliderValueDisplay valueDisplay;
  final double initial;
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
  late double value = widget.initial;
  final log = <String>[];

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => Overlay.wrap(
      child: MediaQuery(
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
            child: Overlay.wrap(
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
                        steps: widget.steps,
                        valueDisplay: widget.valueDisplay,
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
      ),
    ),
  );
}

String _fmt(double v) => v.toStringAsFixed(2);

_HostState _host(WidgetTester tester) =>
    tester.state(find.byType(_Host)) as _HostState;

double _valueOf(WidgetTester tester) => _host(tester).value;

final _slider = find.byKey(const ValueKey('slider'));

/// The visible value text [text], not its width reserve.
Finder _shown(String text) => find.text(text).last;

/// The pill's knob [i].
Finder _knob([int i = 0]) => find.byKey(ValueKey((sliderKnobKey, i)));

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
    double knobX() => tester.getCenter(_knob()).dx;
    final before = knobX();
    final g = await tester.startGesture(_at(tester, .5));
    await g.moveBy(const Offset(90, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(knobX(), closeTo(before, 1));
    await g.up();
    await settle(tester);
    expect(knobX(), closeTo(before, 1));
    expect(
      _host(tester).log.last,
      startsWith('end 0.8'),
      reason: 'the end reports what the drag asked for, as Slider does',
    );
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
          builder: (context, _) => Overlay.wrap(
            child: CoilTheme(
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

    group('the hover bubble and the preview', () {
      // The preview bar's far end, from the track paint: the fill is drawn
      // first, then the preview.
      double previewEnd(WidgetTester tester) {
        final rects = <Rect>[];
        expect(
          tester.renderObject(
            find.descendant(
              of: _slider,
              matching: find.byType(CoilPainterLayer),
            ),
          ),
          paints..everything((method, args) {
            if (method == #drawRect) rects.add(args.first as Rect);
            return true;
          }),
        );
        expect(rects, hasLength(2), reason: 'the preview is showing');
        final origin = tester.getTopLeft(_slider).dx;
        return origin + rects[1].right;
      }

      double bubbleX(WidgetTester tester) => tester.getCenter(bubbleBox()).dx;

      Future<TestGesture> hoverAt(WidgetTester tester, double f) async {
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: const Offset(1, 1));
        await tester.pump();
        await mouse.moveTo(_at(tester, f));
        await tester.pump();
        return mouse;
      }

      testWidgets('it appears on the hover while the preview travels', (
        tester,
      ) async {
        await tester.pumpWidget(const _Host(divisions: 10));
        await hoverAt(tester, .9);
        // The first frame it shows: on the hover, no travel.
        await tester.pump(const Duration(milliseconds: 16));
        expect(bubbleX(tester), closeTo(_at(tester, .9).dx, .5));
        expect(
          previewEnd(tester),
          lessThan(_at(tester, .9).dx - 10),
          reason: 'the preview is still on its way from the thumb',
        );
      });

      testWidgets('until they meet, it follows the hover directly', (
        tester,
      ) async {
        await tester.pumpWidget(const _Host(divisions: 10));
        final mouse = await hoverAt(tester, .9);
        await tester.pump(const Duration(milliseconds: 16));
        await mouse.moveTo(_at(tester, .98));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(bubbleX(tester), closeTo(_at(tester, 1).dx, .5));
        expect(previewEnd(tester), lessThan(_at(tester, .9).dx));
      });

      testWidgets('once they meet, it rides the preview', (tester) async {
        await tester.pumpWidget(const _Host(divisions: 10));
        final mouse = await hoverAt(tester, .9);
        await settle(tester);
        await mouse.moveTo(_at(tester, .6));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final x = bubbleX(tester);
        expect(x, greaterThan(_at(tester, .6).dx + 5), reason: 'gliding');
        expect(x, closeTo(previewEnd(tester), .5));
        await settle(tester);
        expect(bubbleX(tester), closeTo(_at(tester, .6).dx, .5));
      });
    });

    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      testWidgets('${kind.name}: a held press jumps on the way down', (
        tester,
      ) async {
        await tester.pumpWidget(const _Host(divisions: 10));
        final g = await tester.createGesture(kind: kind);
        addTearDown(g.removePointer);
        if (kind == PointerDeviceKind.mouse) {
          // A mouse hovers on its way to the press.
          await g.addPointer(location: _at(tester, .1));
          await g.moveTo(_at(tester, .8));
          await tester.pump();
        }
        await g.down(_at(tester, .8));
        // Until a drag or a tap wins, the press shows after kPressTimeout,
        // as in Flutter's Slider; the value changes at that moment too.
        await tester.pump(kPressTimeout);
        await tester.pump();
        expect(_valueOf(tester), closeTo(.8, 1e-9));
        await settle(tester);
        expect(
          tester.getCenter(bubbleBox()).dx,
          closeTo(_at(tester, .8).dx, .5),
        );
        expect(_host(tester).log, ['start 0.50', 'changed 0.80']);
        await g.up();
        await settle(tester);
        expect(_valueOf(tester), closeTo(.8, 1e-9));
        expect(_host(tester).log, [
          'start 0.50',
          'changed 0.80',
          'end 0.80',
        ], reason: 'the release changes nothing more');
      });
    }

    testWidgets('a held press that becomes a drag is one change', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(divisions: 10));
      final g = await tester.startGesture(_at(tester, .2));
      await tester.pump(kPressTimeout);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await g.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      await g.up();
      await settle(tester);
      final log = _host(tester).log;
      expect(log.where((e) => e.startsWith('start')), hasLength(1));
      expect(log.where((e) => e.startsWith('end')), hasLength(1));
      expect(log.first, 'start 0.50');
      expect(log.last, 'end ${_fmt(_valueOf(tester))}');
      expect(_valueOf(tester), closeTo(.5, .05));
    });

    testWidgets("a press on the pill's label jumps nothing", (tester) async {
      await tester.pumpWidget(const _Host(variant: CoilSliderVariant.pill));
      await tester.tap(find.text('Volume'));
      await settle(tester);
      expect(_valueOf(tester), .5);
      expect(_host(tester).log, isEmpty);
    });

    testWidgets('a stepped drag springs to each step and lands on it', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(variant: CoilSliderVariant.pill, divisions: 4),
      );
      final knob = _knob();
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
        final knob = tester.getCenter(_knob());
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
    double knobX(WidgetTester tester) => tester.getCenter(_knob()).dx;

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

  group('step lists', () {
    const amps = <double>[0, .1, .25, .7, 1];

    testWidgets('a tap snaps to the nearest listed value', (tester) async {
      await tester.pumpWidget(const _Host(steps: amps));
      await tester.tapAt(_at(tester, .55));
      await tester.pump();
      expect(_valueOf(tester), .7);
      await tester.tapAt(_at(tester, .16));
      await tester.pump();
      expect(_valueOf(tester), .1);
    });

    testWidgets('arrows walk the list; Page moves at least one entry', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(steps: amps, initial: .1));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      Future<void> press(LogicalKeyboardKey key, double expected) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(_valueOf(tester), expected, reason: '$key');
      }

      await press(LogicalKeyboardKey.arrowRight, .25);
      await press(LogicalKeyboardKey.arrowRight, .7);
      await press(LogicalKeyboardKey.arrowLeft, .25);
      await press(LogicalKeyboardKey.pageUp, .7);
      await press(LogicalKeyboardKey.pageDown, .25);
      await press(LogicalKeyboardKey.end, 1);
      await press(LogicalKeyboardKey.arrowRight, 1);
      await press(LogicalKeyboardKey.home, 0);
    });

    testWidgets('semantics announce the neighbouring list values', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const _Host(steps: amps, initial: .25));
      final data = tester.getSemantics(_slider).getSemanticsData();
      expect(data.value, '0.25');
      expect(data.increasedValue, '0.7');
      expect(data.decreasedValue, '0.1');
      handle.dispose();
    });

    testWidgets('pips sit at the listed values', (tester) async {
      await tester.pumpWidget(
        const _Host(
          steps: amps,
          variant: CoilSliderVariant.pips,
          label: null,
          valueDisplay: CoilSliderValueDisplay.tooltip,
        ),
      );
      await settle(tester);
      final width = tester.getSize(_slider).width;
      final pips = <double>[];
      expect(
        tester.renderObject(
          find.descendant(
            of: _slider,
            matching: find.byType(CoilPainterLayer),
          ),
        ),
        paints..everything((method, args) {
          if (method == #drawRSuperellipse) {
            final r = (args.first as RSuperellipse).outerRect;
            if (r.width > 3) pips.add(r.center.dx / width);
          }
          return true;
        }),
      );
      // The last mark is the handle line; the end pips stay a few px in.
      expect(pips, hasLength(amps.length));
      for (final (i, f) in amps.sublist(1, amps.length - 1).indexed) {
        expect(pips[i + 1], closeTo(f, .001));
      }
    });
  });

  group('pill layout', () {
    Future<({Rect label, Rect track, Rect value})> lay(
      WidgetTester tester, {
      required double width,
      double textScale = 1,
      TextDirection direction = TextDirection.ltr,
      ValueChanged<CoilRangeValues>? onChanged,
    }) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Overlay.wrap(
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Directionality(
                textDirection: direction,
                child: CoilTheme(
                  data: CoilThemeData.light.copyWith(tier: CoilTier.touch),
                  child: Center(
                    child: SizedBox(
                      width: width,
                      child: CoilRangeSlider(
                        key: const ValueKey('slider'),
                        label: const Text('Price'),
                        max: 100,
                        values: const CoilRangeValues(20, 80),
                        onChanged: onChanged ?? (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return (
        label: tester.getRect(find.text('Price')),
        track: tester.getRect(
          find.descendant(of: _slider, matching: find.byType(CoilPainterLayer)),
        ),
        value: tester.getRect(find.text('80').last),
      );
    }

    testWidgets('wide: label, track and value share a line', (tester) async {
      final r = await lay(tester, width: 400);
      expect(r.label.center.dy, closeTo(r.track.center.dy, .5));
      expect(r.label.right, lessThan(r.track.left));
      expect(r.track.right, lessThan(r.value.left));
    });

    testWidgets('narrow: label and value move above a full-width track', (
      tester,
    ) async {
      final r = await lay(tester, width: 260, textScale: 2);
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final slider = tester.getRect(_slider);
      expect(r.label.bottom, lessThanOrEqualTo(r.track.top + .5));
      expect(r.value.bottom, lessThanOrEqualTo(r.track.top + .5));
      expect(r.track.width, slider.width);
      expect(r.label.left, slider.left);
      expect(r.value.right, closeTo(slider.right, .5));
    });

    testWidgets('narrow RTL: the label is at the right', (tester) async {
      final r = await lay(
        tester,
        width: 260,
        textScale: 2,
        direction: TextDirection.rtl,
      );
      final slider = tester.getRect(_slider);
      expect(r.label.right, closeTo(slider.right, .5));
      expect(r.label.bottom, lessThanOrEqualTo(r.track.top + .5));
    });

    testWidgets('narrow: the track under the text still takes taps', (
      tester,
    ) async {
      CoilRangeValues? got;
      final r = await lay(
        tester,
        width: 260,
        textScale: 2,
        onChanged: (v) => got = v,
      );
      await tester.tapAt(Offset(r.track.right - 23, r.track.center.dy));
      await tester.pump();
      expect(got?.end, closeTo(100, 1));
    });
  });

  group('pill step dots', () {
    /// The dots' centers (as fractions of the track) and diameters: the
    /// marks no wider than a grown dot, so not the outline or the knobs.
    List<({double at, double size})> dots(WidgetTester tester) {
      final layer = find.descendant(
        of: _slider,
        matching: find.byType(CoilPainterLayer),
      );
      final box = tester.getRect(layer);
      final marks = <Rect>[];
      expect(
        tester.renderObject(layer),
        paints..everything((method, args) {
          if (method == #drawRSuperellipse) {
            marks.add((args.first as RSuperellipse).outerRect);
          }
          return true;
        }),
      );
      // The knob box is 20 on the pointer tier; centers stop 10 in.
      return [
        for (final r in marks)
          if (r.width <= 6)
            (at: (r.center.dx - 10) / (box.width - 20), size: r.width),
      ];
    }

    testWidgets('dots sit at the steps past the fill', (tester) async {
      await tester.pumpWidget(
        const _Host(
          variant: CoilSliderVariant.pillPips,
          steps: [0, .1, .25, .7, 1],
          initial: .25,
        ),
      );
      await settle(tester);
      expect(
        [for (final d in dots(tester)) d.at],
        [closeTo(.7, .001), closeTo(1, .001)],
        reason: 'the dots under the fill are hidden',
      );
    });

    testWidgets('a range shows dots outside its thumbs only', (tester) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Overlay.wrap(
            child: CoilTheme(
              data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: CoilRangeSlider(
                    key: const ValueKey('slider'),
                    variant: CoilSliderVariant.pillPips,
                    divisions: 4,
                    values: const CoilRangeValues(.25, .75),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(
        [for (final d in dots(tester)) d.at],
        [closeTo(0, .001), closeTo(1, .001)],
      );
    });

    testWidgets('dots grow while a mouse hovers, not under a finger', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(variant: CoilSliderVariant.pillPips, divisions: 4),
      );
      await settle(tester);
      final rest = dots(tester).first.size;
      final g = await tester.startGesture(_at(tester, .1));
      await settle(tester);
      expect(dots(tester).first.size, rest, reason: 'touch: no hover');
      await g.up();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_at(tester, .1));
      await settle(tester);
      expect(dots(tester).first.size, closeTo(rest * 1.25, .01));
    });
  });

  group('click-to-edit', () {
    final field = find.byType(EditableText);

    Future<void> open(WidgetTester tester) async {
      await tester.tap(_shown('0.5'));
      await tester.pump();
      expect(field, findsOneWidget);
    }

    testWidgets('a tap on the value opens a field with it selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(valueDisplay: CoilSliderValueDisplay.editable),
      );
      await open(tester);
      final editable = tester.widget<EditableText>(field);
      expect(editable.controller.text, '0.5');
      expect(editable.controller.selection.isCollapsed, isFalse);
      expect(editable.focusNode.hasFocus, isTrue);
      expect(_valueOf(tester), .5, reason: 'the tap did not jump the value');
    });

    testWidgets('Done applies the typed value, clamped and snapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(
          valueDisplay: CoilSliderValueDisplay.editable,
          divisions: 4,
        ),
      );
      await open(tester);
      await tester.enterText(field, '0.6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(field, findsNothing);
      expect(_valueOf(tester), .5, reason: '0.6 snaps to the step at 0.5');
      expect(_host(tester).log, ['start 0.50', 'end 0.50']);

      await tester.tap(_shown('0.5'));
      await tester.pump();
      await tester.enterText(field, '7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_valueOf(tester), 1, reason: 'clamped to max');
    });

    testWidgets('Esc leaves the value and returns focus to the slider', (
      tester,
    ) async {
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      await tester.pumpWidget(
        _Host(valueDisplay: CoilSliderValueDisplay.editable, states: states),
      );
      await open(tester);
      await tester.enterText(field, '0.9');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(field, findsNothing);
      expect(_valueOf(tester), .5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_valueOf(tester), closeTo(.51, 1e-9));
    });

    testWidgets('text that is not a number changes nothing', (tester) async {
      await tester.pumpWidget(
        const _Host(valueDisplay: CoilSliderValueDisplay.editable),
      );
      await open(tester);
      await tester.enterText(field, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(field, findsNothing);
      expect(_valueOf(tester), .5);
      expect(_host(tester).log, isEmpty);
    });

    testWidgets('keyboard: Enter opens the field; arrows edit the text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(valueDisplay: CoilSliderValueDisplay.editable),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(field, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(_valueOf(tester), .5, reason: 'the keys went to the field');
      expect(
        tester.widget<EditableText>(field).controller.selection,
        const TextSelection.collapsed(offset: 0),
      );
    });

    testWidgets('leaving the field applies it', (tester) async {
      await tester.pumpWidget(
        const _Host(valueDisplay: CoilSliderValueDisplay.editable),
      );
      await open(tester);
      await tester.enterText(field, '0.25');
      tester.widget<EditableText>(field).focusNode.unfocus();
      await tester.pump();
      expect(field, findsNothing);
      expect(_valueOf(tester), .25);
    });

    testWidgets('a range edits each value, and keeps them in order', (
      tester,
    ) async {
      var values = const CoilRangeValues(.2, .6);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Overlay.wrap(
            child: CoilTheme(
              data: CoilThemeData.light,
              child: Overlay.wrap(
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: StatefulBuilder(
                      builder: (context, setState) => CoilRangeSlider(
                        values: values,
                        valueDisplay: CoilSliderValueDisplay.editable,
                        onChanged: (v) => setState(() => values = v),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(_shown('0.6'));
      await tester.pump();
      await tester.enterText(field, '0.4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(values, const CoilRangeValues(.2, .4));
      await tester.tap(_shown('0.2'));
      await tester.pump();
      await tester.enterText(field, '0.9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        values,
        const CoilRangeValues(.4, .4),
        reason: 'start stops at end',
      );
    });

    testWidgets('shows, announces and edits through separate callbacks', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var value = .5;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Overlay.wrap(
            child: CoilTheme(
              data: CoilThemeData.light,
              child: Overlay.wrap(
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: StatefulBuilder(
                      builder: (context, setState) => CoilSlider(
                        key: const ValueKey('slider'),
                        value: value,
                        valueDisplay: CoilSliderValueDisplay.editable,
                        valueBuilder: (_, v) => Text('${(v * 100).round()} %'),
                        semanticFormatter: (v) =>
                            '${(v * 100).round()} percent',
                        editFormatter: (v) => '${(v * 100).round()}',
                        editParser: (t) => switch (double.tryParse(t)) {
                          final n? => n / 100,
                          null => null,
                        },
                        onChanged: (v) => setState(() => value = v),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(_slider).getSemanticsData().value,
        '50 percent',
      );
      await tester.tap(_shown('50 %'));
      await tester.pump();
      expect(tester.widget<EditableText>(field).controller.text, '50');
      await tester.enterText(field, '25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(value, .25);
      expect(_shown('25 %'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mouse: the editable value previews no jump', (tester) async {
      await tester.pumpWidget(
        const _Host(valueDisplay: CoilSliderValueDisplay.editable),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_shown('0.5')));
      await settle(tester);
      expect(find.byKey(sliderBubbleKey), findsNothing);
      await mouse.moveTo(_at(tester, .2));
      await settle(tester);
      expect(find.byKey(sliderBubbleKey), findsOneWidget);
    });

    testWidgets('with plain text, a tap on the value is a tap on the track', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      await tester.tap(_shown('0.5'));
      await tester.pump();
      expect(field, findsNothing);
      expect(_valueOf(tester), greaterThan(.8));
    });
  });

  testWidgets('its height is its own under a loose, bounded parent', (
    tester,
  ) async {
    for (final display in CoilSliderValueDisplay.values) {
      for (final slider in [
        CoilSlider(
          value: .5,
          valueDisplay: display,
          variant: CoilSliderVariant.pill,
          onChanged: (_) {},
        ),
        CoilRangeSlider(
          values: const CoilRangeValues(.2, .8),
          valueDisplay: display,
          onChanged: (_) {},
        ),
      ]) {
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            builder: (context, _) => Overlay.wrap(
              child: CoilTheme(
                data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
                child: Center(child: SizedBox(width: 300, child: slider)),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byWidget(slider)).height,
          20,
          reason: '$display ${slider.runtimeType}',
        );
      }
    }
  });

  group('tooltip mode', () {
    Finder tip(String text) => find.descendant(
      of: find.byKey(sliderBubbleKey),
      matching: find.text(text),
    );

    testWidgets('mouse: the value rides the thumb while hovered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(valueDisplay: CoilSliderValueDisplay.tooltip),
      );
      expect(find.text('0.5'), findsNothing, reason: 'no value text');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_at(tester, .9));
      await settle(tester);
      expect(tip('0.5'), findsOneWidget, reason: 'the value, not the hover');
      expect(
        tester.getCenter(tip('0.5')).dx,
        closeTo(_at(tester, .5).dx, 1),
      );
      await mouse.moveTo(const Offset(5, 5));
      await settle(tester);
      expect(find.byKey(sliderBubbleKey), findsNothing);
    });

    testWidgets('touch: it shows while pressed and goes on release', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(
          valueDisplay: CoilSliderValueDisplay.tooltip,
          tier: CoilTier.touch,
        ),
      );
      final g = await tester.startGesture(_at(tester, .5));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tip('0.5'), findsOneWidget);
      await g.up();
      await settle(tester);
      expect(find.byKey(sliderBubbleKey), findsNothing);
    });

    testWidgets('keyboard focus shows it; each range thumb has one', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Overlay.wrap(
            child: CoilTheme(
              data: CoilThemeData.light,
              child: FocusScope(
                autofocus: true,
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: CoilRangeSlider(
                      values: const CoilRangeValues(.2, .8),
                      valueDisplay: CoilSliderValueDisplay.tooltip,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(sliderBubbleKey), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle(tester);
      expect(tip('0.2'), findsOneWidget);
      expect(tip('0.8'), findsOneWidget);
    });
  });
}
