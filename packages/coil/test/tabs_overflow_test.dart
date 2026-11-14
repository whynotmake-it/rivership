import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_sheet.dart';

const _count = 12;

class _Host extends StatefulWidget {
  const _Host({
    this.initial = 0,
    this.textDirection = TextDirection.ltr,
    this.tier = CoilTier.pointer,
    this.motions,
    this.trackMotions = const {},
    this.solid = false,
  });

  final int initial;
  final TextDirection textDirection;
  final CoilTier tier;
  final Map<CoilTabsTrack<Object>, Motion>? motions;
  final Map<Track<Object>, Motion> trackMotions;

  /// Tabs are solid black blocks, to read the edge fades from pixels.
  final bool solid;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int tab = widget.initial;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFFFFFFFF),
    builder: (context, _) => Directionality(
      textDirection: widget.textDirection,
      child: CoilTheme(
        data: CoilThemeData.light.copyWith(
          tier: widget.tier,
          trackMotions: widget.trackMotions,
        ),
        child: FocusScope(
          autofocus: true,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const ValueKey('boundary'),
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(
                  width: 300,
                  child: CoilTabs(
                    key: const ValueKey('tabs'),
                    tabs: [
                      for (var i = 0; i < _count; i++)
                        CoilTab(
                          value: i,
                          label: widget.solid
                              ? const SizedBox(
                                  width: 100,
                                  height: 20,
                                  child: ColoredBox(color: Color(0xFF000000)),
                                )
                              : Text('Tab number $i'),
                          semanticLabel: widget.solid ? 'Tab number $i' : null,
                        ),
                    ],
                    value: tab,
                    motions: widget.motions,
                    onChanged: (v) => setState(() => tab = v),
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

int _selected(WidgetTester tester) =>
    (tester.state(find.byType(_Host)) as _HostState).tab;

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

Finder _tab(int i) => find.text('Tab number $i').first;

/// Whether tab [i] is fully inside the 300 px strip.
bool _inView(WidgetTester tester, int i) {
  final r = tester.getRect(_tab(i));
  return r.left >= 0 && r.right <= 300;
}

Future<void> _selectLast(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyEvent(LogicalKeyboardKey.end);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

void main() {
  testWidgets('tabs that fit hug their content and do not scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) => CoilTheme(
          data: CoilThemeData.light,
          child: Align(
            alignment: Alignment.topLeft,
            child: CoilTabs(
              key: const ValueKey('tabs'),
              tabs: const [
                CoilTab(value: 0, label: Text('One')),
                CoilTab(value: 1, label: Text('Two')),
              ],
              value: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('tabs'))).width,
      lessThan(300),
    );
    final position = Scrollable.of(
      tester.element(find.text('One').first),
    ).position;
    expect(position.maxScrollExtent, 0);
  });

  testWidgets('tabs that do not fit scroll horizontally', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('tabs'))).width, 300);
    await tester.drag(_tab(1), const Offset(-200, 0));
    await tester.pump();
    expect(_position(tester).pixels, greaterThan(100));
  });

  testWidgets('a far selected tab starts in view, also in RTL', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_Host(initial: 10, textDirection: direction));
      await tester.pump();
      await tester.pump();
      expect(_inView(tester, 10), isTrue, reason: direction.name);
    }
  });

  testWidgets('keyboard focus scrolls its tab into view', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    expect(_inView(tester, 11), isTrue);
  });

  testWidgets('selecting a tab scrolls it into view', (tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    await _selectLast(tester);
    await settle(tester);
    expect(_selected(tester), 11);
    expect(_inView(tester, 11), isTrue);
  });

  group('while the strip reveals a tab', () {
    // Reveals that run 2 s, so the test can act mid-way.
    final slow = {
      CoilTabsTrack.reveal: const Motion.linear(Duration(seconds: 2)),
    };

    testWidgets('it stays tappable', (tester) async {
      await tester.pumpWidget(_Host(motions: slow));
      await tester.pump();
      await _selectLast(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final visible = [
        for (var i = 0; i < _count; i++)
          if (_inView(tester, i)) i,
      ];
      final other = visible.firstWhere((i) => i != _selected(tester));
      await tester.tap(_tab(other), warnIfMissed: false);
      await tester.pump();
      expect(_selected(tester), other);
    });

    testWidgets('a motion longer than a second runs to its end', (
      tester,
    ) async {
      await tester.pumpWidget(_Host(motions: slow));
      await tester.pump();
      await _selectLast(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        _position(tester).pixels,
        lessThan(_position(tester).maxScrollExtent - 10),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        _position(tester).pixels,
        closeTo(_position(tester).maxScrollExtent, 1),
      );
    });

    testWidgets('a theme track motion reaches the scroll', (tester) async {
      await tester.pumpWidget(
        _Host(
          trackMotions: {CoilTabsTrack.reveal: slow[CoilTabsTrack.reveal]!},
        ),
      );
      await tester.pump();
      await _selectLast(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        _position(tester).pixels,
        lessThan(_position(tester).maxScrollExtent - 10),
      );
    });

    testWidgets('it settles and leaves nothing animating', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pump();
      await _selectLast(tester);
      await settle(tester);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('edge fades', () {
    // Tabs are 124 px apart with a 100 px black block each, so a column 14 px
    // from an edge is inside a block when the strip is parked at 0 or 146.
    Future<double> darknessAt(WidgetTester tester, double x) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('boundary')),
      );
      final image = (await tester.runAsync(boundary.toImage))!;
      final data = (await tester.runAsync(
        image.toByteData,
      ))!;
      final y = image.height ~/ 2;
      final value = 1 - data.getUint8((y * image.width + x.round()) * 4) / 255;
      image.dispose();
      return value;
    }

    testWidgets('only an edge with more behind it fades', (tester) async {
      await tester.pumpWidget(const _Host(solid: true));
      await settle(tester);
      expect(await darknessAt(tester, 14), greaterThan(.9));
      expect(await darknessAt(tester, 300 - 14), lessThan(.8));

      _position(tester).jumpTo(146);
      await settle(tester);
      for (final x in [14.0, 300 - 14.0]) {
        expect(await darknessAt(tester, x), inExclusiveRange(.35, .8));
      }

      _position(tester).jumpTo(_position(tester).maxScrollExtent);
      await settle(tester);
      expect(await darknessAt(tester, 300 - 14), greaterThan(.9));
      expect(await darknessAt(tester, 14), lessThan(.8));
    });

    testWidgets('in RTL the start is on the right', (tester) async {
      await tester.pumpWidget(
        const _Host(solid: true, textDirection: TextDirection.rtl),
      );
      await settle(tester);
      expect(await darknessAt(tester, 300 - 14), greaterThan(.9));
      expect(await darknessAt(tester, 14), lessThan(.8));
    });
  });

  testWidgets('touch: no hover pill after a tap on a scrolled strip', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(tier: CoilTier.touch));
    await tester.pump();
    await tester.tap(_tab(2));
    await settle(tester);
    final region = CoilHoverRegion.maybeOf(tester.element(_tab(3)));
    expect(region?.activeIndex, isNull);
  });

  testWidgets('a mouse lights the tab under it on a scrolled strip', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await tester.pump();
    await tester.drag(_tab(1), const Offset(-300, 0));
    await settle(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_tab(4)));
    await settle(tester);
    expect(CoilHoverRegion.maybeOf(tester.element(_tab(4)))?.activeIndex, 4);
  });
}
