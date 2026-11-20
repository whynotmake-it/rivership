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

/// Hosts one range slider whose parent applies every change and logs the
/// callbacks.
class _Host extends StatefulWidget {
  const _Host({
    this.initial = const CoilRangeValues(.2, .8),
    this.divisions,
    this.tier = CoilTier.pointer,
    this.textDirection = TextDirection.ltr,
    this.motions,
    this.valueDisplay = CoilSliderValueDisplay.text,
  });

  final CoilRangeValues initial;
  final int? divisions;
  final CoilTier tier;
  final TextDirection textDirection;
  final Map<CoilSliderTrack<Object>, Motion>? motions;
  final CoilSliderValueDisplay valueDisplay;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CoilRangeValues values = widget.initial;
  final log = <String>[];

  String _fmt(CoilRangeValues v) =>
      '${v.start.toStringAsFixed(2)}-${v.end.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => Directionality(
      textDirection: widget.textDirection,
      child: CoilTheme(
        // Geometry is measured on a real font.
        data: CoilThemeData.light.copyWith(
          tier: widget.tier,
          typography: CoilTypography.allo(),
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
                  child: CoilRangeSlider(
                    key: const ValueKey('slider'),
                    values: values,
                    divisions: widget.divisions,
                    motions: widget.motions,
                    valueDisplay: widget.valueDisplay,
                    label: const Text('Price'),
                    onChangeStart: (v) => log.add('start ${_fmt(v)}'),
                    onChangeEnd: (v) => log.add('end ${_fmt(v)}'),
                    onChanged: (v) {
                      log.add('changed ${_fmt(v)}');
                      setState(() => values = v);
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

final _slider = find.byKey(const ValueKey('slider'));

_HostState _host(WidgetTester tester) =>
    tester.state(find.byType(_Host)) as _HostState;

CoilRangeValues _values(WidgetTester tester) => _host(tester).values;

/// The point at [fraction] of the range on the pill track: the knob centers
/// stop half a knob short of each end.
Offset _at(WidgetTester tester, double fraction) {
  final track = tester.getRect(
    find.descendant(of: _slider, matching: find.byType(CoilPainterLayer)),
  );
  final tier = CoilTheme.tierOf(tester.element(_slider));
  final inset = tier == CoilTier.touch ? 11.0 : 8.0;
  final x = track.left + inset + (track.width - inset * 2) * fraction;
  return Offset(
    Directionality.of(tester.element(_slider)) == TextDirection.rtl
        ? track.right - (x - track.left)
        : x,
    track.center.dy,
  );
}

void _expectValues(WidgetTester tester, double start, double end) {
  expect(_values(tester).start, closeTo(start, 1e-9), reason: 'start');
  expect(_values(tester).end, closeTo(end, 1e-9), reason: 'end');
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  testWidgets('a tap moves the nearest thumb, by touch and by mouse', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(divisions: 10));
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      await tester.tapAt(_at(tester, .4), kind: kind);
      await tester.pump();
      _expectValues(tester, .4, .8);
      await tester.tapAt(_at(tester, .7), kind: kind);
      await tester.pump();
      _expectValues(tester, .4, .7);
      await tester.tapAt(_at(tester, .2), kind: kind);
      await tester.tapAt(_at(tester, .8), kind: kind);
      await tester.pump();
    }
  });

  testWidgets('RTL: the start thumb is on the right, and moves left', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(textDirection: TextDirection.rtl));
    final start = tester.getCenter(
      find.byKey(const ValueKey((sliderKnobKey, 0))),
    );
    final end = tester.getCenter(
      find.byKey(const ValueKey((sliderKnobKey, 1))),
    );
    expect(start.dx, greaterThan(end.dx));
    final g = await tester.startGesture(start);
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-30, 0));
    await g.up();
    await settle(tester);
    expect(_values(tester).start, greaterThan(.3));
    expect(_values(tester).end, .8);
  });

  testWidgets('the thumbs never cross', (tester) async {
    await tester.pumpWidget(const _Host());
    final g = await tester.startGesture(_at(tester, .2));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
    }
    await g.up();
    await settle(tester);
    expect(_values(tester).start, closeTo(.8, 1e-9));
    expect(_values(tester).end, closeTo(.8, 1e-9));
  });

  testWidgets('on stacked thumbs, the drag direction picks the thumb', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: CoilRangeValues(.5, .5)));
    var g = await tester.startGesture(_at(tester, .5));
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    await settle(tester);
    expect(_values(tester).start, .5, reason: 'dragging right takes the end');
    expect(_values(tester).end, greaterThan(.6));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const _Host(initial: CoilRangeValues(.5, .5)));
    g = await tester.startGesture(_at(tester, .5));
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-30, 0));
    await g.up();
    await settle(tester);
    expect(_values(tester).start, lessThan(.4));
    expect(_values(tester).end, .5, reason: 'dragging left takes the start');
  });

  testWidgets('keyboard: Tab moves between thumbs, each keeps its side', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(divisions: 10));
    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_values(tester).start, closeTo(.3, 1e-9));
    await _key(tester, LogicalKeyboardKey.end);
    expect(
      _values(tester).start,
      closeTo(.8, 1e-9),
      reason: 'End takes the start thumb only as far as the end thumb',
    );

    await _key(tester, LogicalKeyboardKey.tab);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_values(tester).end, closeTo(.9, 1e-9));
    await _key(tester, LogicalKeyboardKey.home);
    expect(_values(tester).end, closeTo(.8, 1e-9));
    expect(_values(tester).start, closeTo(.8, 1e-9));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _key(tester, LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _key(tester, LogicalKeyboardKey.home);
    expect(_values(tester).start, 0, reason: 'Shift+Tab is back on the start');
  });

  testWidgets('keyboard focus rings the focused knob, a tap rings none', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    bool ringed(int i) => tester
        .widget<CoilFocusRing>(
          find.ancestor(
            of: find.byKey(ValueKey((sliderKnobKey, i))),
            matching: find.byType(CoilFocusRing),
          ),
        )
        .visible;
    await tester.tapAt(_at(tester, .5), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect([ringed(0), ringed(1)], [false, false]);
    await _key(tester, LogicalKeyboardKey.tab);
    expect([ringed(0), ringed(1)], [true, false]);
    await _key(tester, LogicalKeyboardKey.tab);
    expect([ringed(0), ringed(1)], [false, true]);
  });

  testWidgets('semantics: one slider node per thumb, minimum and maximum', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(divisions: 10));
    final start = find.semantics.byLabel('Minimum');
    final end = find.semantics.byLabel('Maximum');
    expect(start, findsOne);
    expect(end, findsOne);
    final s = start.evaluate().single.getSemanticsData();
    expect(s.flagsCollection.isSlider, isTrue);
    expect(s.value, '0.2');
    expect(s.increasedValue, '0.3');
    expect(end.evaluate().single.getSemanticsData().value, '0.8');

    tester.semantics.performAction(start, SemanticsAction.increase);
    await tester.pump();
    expect(_values(tester).start, closeTo(.3, 1e-9));
    tester.semantics.performAction(end, SemanticsAction.decrease);
    await tester.pump();
    expect(_values(tester).end, closeTo(.7, 1e-9));
    handle.dispose();
  });

  testWidgets('the value reads start – end', (tester) async {
    await tester.pumpWidget(const _Host());
    // The last of each is the visible one; the others reserve the width.
    double x(String text) => tester.getCenter(find.text(text).last).dx;
    expect(x('0.2'), lessThan(x(' – ')));
    expect(x(' – '), lessThan(x('0.8')));
  });

  testWidgets('every change reports a start and an end with both values', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(divisions: 10));
    await tester.tapAt(_at(tester, .7));
    await tester.pump();
    expect(_host(tester).log, [
      'start 0.20-0.80',
      'changed 0.20-0.70',
      'end 0.20-0.70',
    ]);
  });

  group('touch and mouse', () {
    testWidgets('touch: the bubble rides the pressed thumb, nothing sticks', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(tier: CoilTier.touch));
      final g = await tester.startGesture(_at(tester, .75));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(
          of: find.byKey(sliderBubbleKey),
          matching: find.text('0.75'),
        ),
        findsOneWidget,
        reason: 'the end thumb is nearer, so the press moved it there',
      );
      _expectValues(tester, .2, .75);
      await g.up();
      await settle(tester);
      expect(find.byKey(sliderBubbleKey), findsNothing);
    });

    testWidgets('mouse: the hover previews the value under the pointer', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(divisions: 10));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_at(tester, .5));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(sliderBubbleKey),
          matching: find.text('0.5'),
        ),
        findsOneWidget,
      );
      await mouse.moveTo(const Offset(5, 5));
      await settle(tester);
      expect(find.byKey(sliderBubbleKey), findsNothing);
    });
  });

  group('with steps, a bubble moves with the pointer', () {
    final bubbles = find.descendant(
      of: find.byKey(sliderBubbleKey),
      matching: find.byType(DecoratedBox),
    );
    List<double> bubbleXs(WidgetTester tester) => [
      for (var i = 0; i < bubbles.evaluate().length; i++)
        tester.getCenter(bubbles.at(i)).dx,
    ];
    double knobX(WidgetTester tester, int i) =>
        tester.getCenter(find.byKey(ValueKey((sliderKnobKey, i)))).dx;

    for (final display in [
      CoilSliderValueDisplay.text,
      CoilSliderValueDisplay.tooltip,
    ]) {
      for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        for (final thumb in [0, 1]) {
          testWidgets('${display.name}, ${kind.name}: dragging thumb $thumb', (
            tester,
          ) async {
            await tester.pumpWidget(
              _Host(divisions: 10, valueDisplay: display),
            );
            final other = 1 - thumb;
            final otherX = knobX(tester, other);
            final from = tester.getCenter(
              find.byKey(ValueKey((sliderKnobKey, thumb))),
            );
            // Toward the middle.
            final toward = thumb == 0 ? 1.0 : -1.0;
            final g = await tester.createGesture(kind: kind);
            addTearDown(g.removePointer);
            if (kind == PointerDeviceKind.mouse) {
              await g.addPointer(location: from);
              await g.moveTo(from);
              await tester.pump();
            }
            await g.down(from);
            await tester.pump();
            var x = from.dx + 20 * toward;
            await g.moveTo(Offset(x, from.dy));
            await settle(tester);
            final seen = <double>{};
            for (var i = 0; i < 10; i++) {
              x += 3 * toward;
              await g.moveTo(Offset(x, from.dy));
              await tester.pump(const Duration(milliseconds: 16));
              final values = _values(tester);
              final moved = thumb == 0 ? values.start : values.end;
              seen.add(moved);
              expect(moved * 10, closeTo((moved * 10).roundToDouble(), 1e-9));
              expect(
                thumb == 0 ? values.end : values.start,
                thumb == 0 ? .8 : .2,
                reason: 'the other thumb stays',
              );
              final xs = bubbleXs(tester);
              expect(
                xs.any((b) => (b - x).abs() < .5),
                isTrue,
                reason: 'frame $i: a bubble at the pointer $x, not $xs',
              );
              if (display == CoilSliderValueDisplay.tooltip) {
                expect(xs, hasLength(2));
                expect(
                  xs.any((b) => (b - otherX).abs() < .5),
                  isTrue,
                  reason: "frame $i: the other bubble on its thumb",
                );
              }
            }
            expect(seen.length, greaterThan(1), reason: 'crossed steps');
            await g.up();
            await settle(tester);
            if (display == CoilSliderValueDisplay.tooltip &&
                kind == PointerDeviceKind.mouse) {
              // Still hovered: both bubbles show, each on its thumb.
              final xs = bubbleXs(tester)..sort();
              final knobs = [knobX(tester, 0), knobX(tester, 1)]..sort();
              expect(xs[0], closeTo(knobs[0], .5));
              expect(xs[1], closeTo(knobs[1], .5));
            }
          });
        }
      }
    }
  });

  testWidgets('a thumb motion override moves both thumbs', (tester) async {
    await tester.pumpWidget(
      _Host(
        divisions: 10,
        motions: {
          CoilSliderTrack.thumb: const Motion.linear(Duration(seconds: 2)),
        },
      ),
    );
    double x(int i) =>
        tester.getCenter(find.byKey(ValueKey((sliderKnobKey, i)))).dx;
    for (final i in [0, 1]) {
      final before = x(i);
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(
        tester,
        i == 0 ? LogicalKeyboardKey.home : LogicalKeyboardKey.end,
      );
      await tester.pump(const Duration(milliseconds: 1000));
      final halfway = x(i);
      await settle(tester);
      final travel = (halfway - before) / (x(i) - before);
      expect(travel, closeTo(.5, .1), reason: 'thumb $i');
    }
  });
}
