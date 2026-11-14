import 'package:coil/coil.dart';
import 'package:coil/src/components/slider/slider_visuals.dart'
    show sliderBubbleKey, sliderKnobKey;
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
    this.variant = CoilSliderVariant.scrubber,
    this.tier = CoilTier.pointer,
    this.textDirection = TextDirection.ltr,
    this.motions,
  });

  final CoilRangeValues initial;
  final int? divisions;
  final CoilSliderVariant variant;
  final CoilTier tier;
  final TextDirection textDirection;
  final Map<CoilSliderTrack<Object>, Motion>? motions;

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
        data: CoilThemeData.light.copyWith(tier: widget.tier),
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
                  variant: widget.variant,
                  motions: widget.motions,
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
  );
}

final _slider = find.byKey(const ValueKey('slider'));

_HostState _host(WidgetTester tester) =>
    tester.state(find.byType(_Host)) as _HostState;

CoilRangeValues _values(WidgetTester tester) => _host(tester).values;

Offset _at(WidgetTester tester, double fraction) {
  final rect = tester.getRect(_slider);
  return Offset(rect.left + rect.width * fraction, rect.center.dy);
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

  testWidgets('RTL: the start thumb is on the right', (tester) async {
    await tester.pumpWidget(
      const _Host(divisions: 10, textDirection: TextDirection.rtl),
    );
    await tester.tapAt(_at(tester, .7));
    await tester.pump();
    _expectValues(tester, .3, .8);
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
    await tester.pumpWidget(const _Host(variant: CoilSliderVariant.pill));
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
    expect(find.text('0.2'), findsOneWidget);
    expect(find.text(' – '), findsOneWidget);
    expect(find.text('0.8'), findsOneWidget);
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
          matching: find.text('0.8'),
        ),
        findsOneWidget,
        reason: 'the end thumb is nearer, so it is the one pressed',
      );
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

  testWidgets('a thumb motion override moves both thumbs', (tester) async {
    await tester.pumpWidget(
      _Host(
        divisions: 10,
        variant: CoilSliderVariant.pill,
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
