import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

const _gap = CoilTooltipAnchor.gap;

/// A button at [alignment] with a tooltip on [side], opened with Tab.
Widget _button({
  required CoilTooltipSide side,
  Alignment alignment = Alignment.center,
  TextDirection direction = TextDirection.ltr,
}) => testApp(
  tier: CoilTier.pointer,
  home: Directionality(
    textDirection: direction,
    child: Align(
      alignment: alignment,
      child: CoilTooltip(
        message: const Text('Bold'),
        side: side,
        child: CoilButton.icon(
          onPressed: () {},
          semanticLabel: 'Bold button',
          icon: const SizedBox.square(dimension: 16),
        ),
      ),
    ),
  ),
);

Rect _trigger(WidgetTester tester) => tester.getRect(find.byType(CoilButton));
Rect _bubble(WidgetTester tester) =>
    tester.getRect(find.byType(CoilTooltipBubble));

Future<void> _open(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

/// How often the rail's bubble was built.
int _bubbleBuilds = 0;

/// A full-height strip at the start with a tooltip that follows the
/// pointer, past its end.
Widget _rail() => testApp(
  tier: CoilTier.pointer,
  home: Align(
    alignment: AlignmentDirectional.centerStart,
    child: CoilTooltipAnchor(
      content: const Text('Drag to resize'),
      semanticLabel: 'Drag to resize',
      side: CoilTooltipSide.end,
      follow: CoilTooltipFollow.pointer,
      bubble: (context, presence, content) {
        _bubbleBuilds++;
        return CoilTooltipBubble(child: content);
      },
      child: const SizedBox(key: ValueKey('rail'), width: 8, height: 400),
    ),
  ),
);

void main() {
  testWidgets('side: end puts the bubble past the trigger, centered on it', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_button(side: CoilTooltipSide.end));
    await _open(tester);
    final trigger = _trigger(tester);
    final bubble = _bubble(tester);
    expect(bubble.left - trigger.right, _gap);
    expect(bubble.center.dy, closeTo(trigger.center.dy, 0.01));
  });

  testWidgets('it slides toward the trigger from its side', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_button(side: CoilTooltipSide.end));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final sliding = _bubble(tester);
    await tester.pumpAndSettle();
    final rest = _bubble(tester);
    expect(sliding.left - rest.left, inExclusiveRange(0, 4));
    expect(sliding.top, rest.top);
  });

  testWidgets('without room on its side it flips to the other', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      _button(side: CoilTooltipSide.end, alignment: Alignment.centerRight),
    );
    await _open(tester);
    expect(_trigger(tester).left - _bubble(tester).right, _gap);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _button(side: CoilTooltipSide.top, alignment: Alignment.topCenter),
    );
    await _open(tester);
    expect(_bubble(tester).top - _trigger(tester).bottom, _gap);
  });

  testWidgets('start and end follow the text direction', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      _button(side: CoilTooltipSide.end, direction: TextDirection.rtl),
    );
    await _open(tester);
    expect(_trigger(tester).left - _bubble(tester).right, _gap);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _button(side: CoilTooltipSide.start, direction: TextDirection.rtl),
    );
    await _open(tester);
    expect(_bubble(tester).left - _trigger(tester).right, _gap);
  });

  group('follow: pointer', () {
    setUp(() => _bubbleBuilds = 0);

    testWidgets('lines the bubble up with the pointer along the strip', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(_rail());
      final rail = tester.getRect(find.byKey(const ValueKey('rail')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(rail.center.dx, rail.top + 100));
      await tester.pump(CoilTooltipAnchor.hoverDelay);
      await tester.pumpAndSettle();
      expect(_bubble(tester).left - rail.right, _gap);
      expect(_bubble(tester).center.dy, closeTo(rail.top + 100, 0.01));

      final builds = _bubbleBuilds;
      for (final y in [180.0, 181.5, 300.0]) {
        await mouse.moveTo(Offset(rail.center.dx, rail.top + y));
        await tester.pump();
        expect(_bubble(tester).center.dy, closeTo(rail.top + y, 0.01));
      }
      expect(_bubbleBuilds, builds, reason: 'following only re-places it');
    });

    testWidgets('keeps the bubble on screen near the end of the strip', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(_rail());
      final rail = tester.getRect(find.byKey(const ValueKey('rail')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(rail.center.dx, rail.bottom - 1));
      await tester.pump(CoilTooltipAnchor.hoverDelay);
      await tester.pumpAndSettle();
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(_bubble(tester).bottom, lessThanOrEqualTo(screen.height - 8));
    });

    testWidgets('opened by focus, it lines up with the center of the strip', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await tester.pumpWidget(
        testApp(
          tier: CoilTier.pointer,
          home: Center(
            child: CoilTooltip(
              message: const Text('Bold'),
              side: CoilTooltipSide.end,
              follow: CoilTooltipFollow.pointer,
              child: CoilButton.icon(
                onPressed: () {},
                semanticLabel: 'Bold button',
                icon: const SizedBox.square(dimension: 16),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      expect(
        _bubble(tester).center.dy,
        closeTo(_trigger(tester).center.dy, 0.01),
      );
    });
  });
}
